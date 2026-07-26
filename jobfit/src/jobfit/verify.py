"""The verification gate.

Every competing tool enforces honesty with a prompt instruction — "do not fabricate",
"preserve resume facts". A prompt is a request, not a guarantee, and nothing downstream
checks whether it was honoured. This module is the check.

Six checks run against every draft. Four need no model at all, which is the point: they
are deterministic, unit-testable, and cannot themselves hallucinate. A gate that depends
on a model to catch a model's mistakes inherits the failure mode it is supposed to catch.

    1. immutables      deterministic   employers/titles/dates/credentials are verbatim
    2. numbers         deterministic   every numeral traces to a cited fact
    3. style           deterministic   banned phrases and AI tells
    4. ats             deterministic   the rendered PDF still parses (render/ats_check.py)
    5. entailment      model           claims are entailed by the facts that licensed them
    6. slop            model           the maxhire anti-slop rubric, target >= 40/50

Findings are `FATAL` or `WARN`. Any `FATAL` fails the gate and triggers regeneration;
after the retry budget is spent the caller must surface the failure rather than ship the
draft. `WARN` is advisory and shown to the user.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Sequence
from difflib import SequenceMatcher
from enum import StrEnum

from pydantic import BaseModel, ConfigDict

from jobfit.domain.models import (
    CoverLetter,
    Fact,
    FactBase,
    Job,
    TailoredResume,
    extract_numbers,
)

# --------------------------------------------------------------------------------------
# Findings
# --------------------------------------------------------------------------------------


class Severity(StrEnum):
    FATAL = "fatal"
    WARN = "warn"


class Finding(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    check: str
    severity: Severity
    message: str
    excerpt: str = ""

    def __str__(self) -> str:
        tail = f"  ({self.excerpt!r})" if self.excerpt else ""
        return f"[{self.severity.upper():5}] {self.check}: {self.message}{tail}"


class GateResult(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    findings: tuple[Finding, ...] = ()

    @property
    def fatal(self) -> tuple[Finding, ...]:
        return tuple(f for f in self.findings if f.severity is Severity.FATAL)

    @property
    def warnings(self) -> tuple[Finding, ...]:
        return tuple(f for f in self.findings if f.severity is Severity.WARN)

    @property
    def passed(self) -> bool:
        return not self.fatal

    def merge(self, other: GateResult) -> GateResult:
        return GateResult(findings=self.findings + other.findings)

    def report(self) -> str:
        if not self.findings:
            return "gate: clean"
        return "\n".join(str(f) for f in sorted(self.findings, key=lambda f: f.severity))


# --------------------------------------------------------------------------------------
# Check 1 — immutables
# --------------------------------------------------------------------------------------

# Words that start sentences or are ordinary English but capitalise; excluding them keeps
# the unknown-proper-noun warning signal-to-noise tolerable.
_STOPWORDS = frozenset(
    """
    a an and are as at be been building built but by for from had has have i if in into is it
    its led my of on or over per she so that the their them they this to was we were what when
    where which who will with within would you your he him her his our us also after before
    across during while than then there here about above below between under again further
    both each few more most other some such only own same too very can just don should now
    january february march april may june july august september october november december
    jan feb mar apr jun jul aug sep sept oct nov dec present current monday tuesday wednesday
    thursday friday saturday sunday
    """.split()
)

_TOKEN_RE = re.compile(r"[A-Za-z0-9&.'’-]+")
# Lowercase words that may sit *inside* a proper noun without ending it
# ("National University of Singapore", "Bank of the West").
_CONNECTORS = frozenset({"of", "de", "der", "van", "the", "and", "&", "for"})

# Above this similarity, an unmatched proper noun is a *mutation* of a real credential
# rather than an unrelated name. Mutations are the dangerous case: "Senior APAC Lead"
# where the fact says "APAC Lead" is a promotion the candidate never had, and it reads as
# entirely plausible. Tuned so ordinary company names sit far below it.
_MUTATION_THRESHOLD = 0.82


def check_immutables(
    text: str,
    facts: FactBase,
    job: Job | None = None,
    extra_allowed: Iterable[str] = (),
) -> GateResult:
    """Employers, titles, institutions and credentials must appear exactly as authored.

    Two distinct failures, weighted very differently:

    * **Mutation** (FATAL) — a phrase that closely resembles a real credential but is not
      it. This is how inflation actually happens in practice: a seniority prefix added, a
      team size nudged, a title "tidied up". It is plausible, unfalsifiable at a glance,
      and indefensible in an interview.
    * **Unknown** (WARN) — a proper noun found nowhere in the fact base or the job. Often
      innocent (a technology, a city), so it is surfaced for review rather than blocking.
    """
    allowed = {
        *facts.all_immutables,
        *(extra_allowed or ()),
    }
    if job is not None:
        allowed.update({job.company, job.title})
        if job.department:
            allowed.add(job.department)

    allowed_norm = {_norm(a) for a in allowed if a}
    # Individual words of allowed phrases are fine on their own: citing "Acme" when the
    # fact says "Acme Corporation" is a contraction, not an invention.
    allowed_words = {w for a in allowed_norm for w in a.split() if len(w) > 2}

    findings: list[Finding] = []
    for phrase in _candidate_proper_nouns(text):
        norm = _norm(phrase)
        if not norm or norm in allowed_norm:
            continue
        if all(word in allowed_words for word in norm.split()):
            continue

        near = _closest(norm, allowed_norm)
        if near and _similarity(norm, near) >= _MUTATION_THRESHOLD:
            findings.append(
                Finding(
                    check="immutables",
                    severity=Severity.FATAL,
                    message=(
                        f"{phrase!r} does not match any authored credential, but closely "
                        f"resembles {near!r}. Altered credentials are fabrication."
                    ),
                    excerpt=phrase,
                )
            )
        else:
            findings.append(
                Finding(
                    check="immutables",
                    severity=Severity.WARN,
                    message=f"{phrase!r} appears in no fact and in no job field. Confirm it is real.",
                    excerpt=phrase,
                )
            )
    return GateResult(findings=tuple(findings))


def _candidate_proper_nouns(text: str) -> list[str]:
    """Maximal runs of capitalised tokens, with sentence-opening artefacts removed.

    Token-based rather than regex-based because the naive version conflates the word that
    merely *opens* a sentence with the proper noun that follows it. "At Acme Systems…"
    yields the phrase "At Acme Systems", which matches no authored credential while
    closely resembling one — so an honest letter gets flagged as fabrication, and the
    genuine mutation in "As Senior APAC Enterprise Lead…" is masked by the same bug.
    Stripping leading and trailing stopwords fixes both directions at once.
    """
    out: list[str] = []
    for sentence in re.split(r"(?<=[.!?])\s+|\n", text):
        tokens = [(m.group(), m.start()) for m in _TOKEN_RE.finditer(sentence.strip())]
        run: list[str] = []
        for token, _ in tokens:
            bare = token.strip(".,'’-&")
            if bare[:1].isupper():
                run.append(bare)
            elif run and bare.lower() in _CONNECTORS:
                run.append(bare)  # keep going; trimmed later if it ends the run
            else:
                out.extend(_emit(run))
                run = []
        out.extend(_emit(run))
    return out


def _emit(run: list[str]) -> list[str]:
    """Trim a capitalised run down to the part that is actually a proper noun."""
    while run and run[0].lower() in _STOPWORDS | _CONNECTORS:
        run = run[1:]
    while run and run[-1].lower() in _STOPWORDS | _CONNECTORS:
        run = run[:-1]
    if not run:
        return []
    phrase = " ".join(run)
    return [phrase] if _norm(phrase) and _norm(phrase) not in _STOPWORDS else []


def _norm(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]+", " ", text.lower())).strip()


def _similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


def _closest(needle: str, haystack: Iterable[str]) -> str | None:
    best, best_score = None, 0.0
    for candidate in haystack:
        score = _similarity(needle, candidate)
        if score > best_score:
            best, best_score = candidate, score
    return best


# --------------------------------------------------------------------------------------
# Check 2 — number provenance
# --------------------------------------------------------------------------------------

# Numbers that carry no factual claim and would otherwise produce constant false
# positives: small ordinals and counts that appear in ordinary prose ("3 teams" is a claim,
# but "1" in "1:1" or a lone "2" in "top 2%" of a licensed phrase is noise). Kept
# deliberately tiny — the check is worthless if the exemption list does the work.
_TRIVIAL_NUMBERS = frozenset({"1", "2"})


def check_numbers(text: str, facts: FactBase, cited_ids: Iterable[str]) -> GateResult:
    """Every numeral in the output must be licensed by a fact the writer actually cited.

    This is the check that catches the classic failure — a model asked to make a bullet
    punchier quietly upgrades "grew the book" to "grew the book 40%". The 40 exists
    nowhere in the fact base, and no reviewer reading a polished PDF will notice.

    Licensing is per-draft, not global: citing an unrelated fact does not license its
    numbers, so a bullet cannot borrow a metric from a different job.
    """
    cited = tuple(cited_ids)
    licensed = _licensed_numbers(facts.subset(cited)) if cited else frozenset()

    findings = [
        Finding(
            check="numbers",
            severity=Severity.FATAL,
            message=(
                f"{number!r} is not licensed by any cited fact "
                f"({', '.join(cited) or 'none cited'}). Every number must trace to evidence."
            ),
            excerpt=_context(text, number),
        )
        for number in sorted(extract_numbers(text) - licensed - _TRIVIAL_NUMBERS)
    ]
    return GateResult(findings=tuple(findings))


def _licensed_numbers(facts: Sequence[Fact]) -> frozenset[str]:
    """Numbers a set of facts permits, including those implied by their date ranges.

    A rendered period ("Jan 2021 – Jun 2023") puts years into the text that never appear
    literally in the claim string, as does a derived duration ("over 2 years"). Both are
    arithmetic on authored data rather than invention, so both are licensed.
    """
    numbers: set[str] = set()
    for fact in facts:
        numbers |= fact.numbers
        if fact.period:
            numbers.add(str(fact.period.start.year))
            numbers.add(str(fact.period.start.month))
            end = fact.period.end
            if end:
                numbers.add(str(end.year))
                numbers.add(str(end.month))
                span = (end.year - fact.period.start.year) * 12 + (
                    end.month - fact.period.start.month
                )
                numbers.update({str(span // 12), str(span // 12 + 1), str(span)})
    return frozenset(numbers)


def _context(text: str, needle: str, width: int = 44) -> str:
    index = text.find(needle)
    if index < 0:
        return needle
    start, end = max(0, index - width), min(len(text), index + len(needle) + width)
    return ("…" if start else "") + text[start:end].strip() + ("…" if end < len(text) else "")


# --------------------------------------------------------------------------------------
# Check 3 — style: banned phrases and AI tells
# --------------------------------------------------------------------------------------

# From the maxhire rubric. These are not merely unfashionable: they are the phrases that
# occupy a bullet without making a claim, so a reader learns nothing from them.
BANNED_PHRASES: tuple[str, ...] = (
    "proven track record",
    "results-oriented",
    "results oriented",
    "detail-oriented",
    "passionate about",
    "spearheaded",
    "leveraging data-driven",
    "data-driven approach",
    "team player",
    "self-starter",
    "think outside the box",
    "synergy",
    "wide range of",
    "responsible for",
    "duties included",
    "hit the ground running",
    "go-getter",
    "dynamic environment",
    "wear many hats",
    "seeking opportunities",
    "i am excited to",
    "i am writing to express",
    "delve into",
    "tapestry",
    "testament to",
    "in today's fast-paced",
    "world-class",
    "best-in-class",
    "cutting-edge",
    "game-changer",
)

# An em-dash rate above this reads as machine-written. maxhire calls it the most
# detectable AI tell in career documents.
_EM_DASH_PER_100_WORDS = 1.5


def check_style(text: str, *, allow_sentence_initial_i: bool = False) -> GateResult:
    """Deterministic prose scan: banned phrases, AI tells, hedging."""
    findings: list[Finding] = []
    lowered = text.lower()

    findings.extend(
        Finding(
            check="style",
            severity=Severity.FATAL,
            message=f"banned phrase {phrase!r}: says nothing a reader can act on",
            excerpt=_context(lowered, phrase),
        )
        for phrase in BANNED_PHRASES
        if phrase in lowered
    )

    words = max(len(text.split()), 1)
    em_dashes = text.count("—") + text.count(" - ")
    if em_dashes * 100 / words > _EM_DASH_PER_100_WORDS:
        findings.append(
            Finding(
                check="style",
                severity=Severity.WARN,
                message=(
                    f"{em_dashes} em-dashes in {words} words. Overuse is the clearest "
                    "machine-written signature in career documents."
                ),
            )
        )

    if not allow_sentence_initial_i:
        findings.extend(
            Finding(
                check="style",
                severity=Severity.WARN,
                message="sentence opens with 'I'; lead with the action instead",
                excerpt=sentence.strip()[:70],
            )
            for sentence in re.split(r"(?<=[.!?])\s+|\n", text)
            if re.match(r"^I\b", sentence.strip())
        )

    return GateResult(findings=tuple(findings))


# --------------------------------------------------------------------------------------
# Composite entry points
# --------------------------------------------------------------------------------------


def verify_resume(resume: TailoredResume, facts: FactBase, job: Job) -> GateResult:
    """Run every deterministic check over a tailored resume.

    Bullets are checked individually for number provenance, because licensing is per
    citation: a bullet may only use numbers from the facts *it* cites, not from anything
    else in the document.
    """
    text = resume.prose
    result = check_immutables(text, facts, job).merge(check_style(text))

    for section in resume.sections:
        for bullet in section.bullets:
            result = result.merge(check_numbers(bullet.text, facts, bullet.derived_from))

    # Summary prose is licensed by the union of everything the document cites.
    result = result.merge(check_numbers(resume.summary, facts, resume.cited_fact_ids))
    return result


def verify_cover_letter(letter: CoverLetter, facts: FactBase, job: Job) -> GateResult:
    text = letter.prose
    return (
        check_immutables(text, facts, job)
        .merge(check_style(text, allow_sentence_initial_i=False))
        .merge(check_numbers(text, facts, letter.derived_from))
    )
