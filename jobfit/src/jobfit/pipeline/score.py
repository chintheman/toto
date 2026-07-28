"""Requirements × facts → a coverage matrix.

This is the honest half of the product. Everything downstream writes *from* this table,
so a requirement marked DIRECT on evidence that does not support it becomes a sentence
the candidate has to defend in an interview.

Two mechanisms keep it grounded:

**Retrieval is deterministic and recall-oriented; judgement is the model's.** A lexical
shortlist decides which facts the judge may consider. Being generous there is cheap — the
judge discards what does not fit — while being stingy manufactures a gap the candidate
does not have.

**Citations are validated against the shortlist, not just against the fact base.** A
judge that cites a fact it was never shown has not retrieved evidence, it has recalled
something. Those citations are dropped and the verdict degrades, so an unsupported
requirement lands as a stated gap rather than as an invented match.
"""

from __future__ import annotations

import re

from pydantic import BaseModel, ConfigDict, Field

from jobfit.domain.models import (
    Coverage,
    Fact,
    FactBase,
    FitReport,
    Requirement,
    RequirementKind,
    Verdict,
)
from jobfit.llm import GROUNDING_RULES, WRITER_MODEL, Client, render_facts
from jobfit.pipeline.extract import RequirementSet

# --------------------------------------------------------------------------------------
# Retrieval
# --------------------------------------------------------------------------------------

#: Words that appear in every job posting and every resume, so their overlap says nothing.
_STOPWORDS = frozenset(
    """
    a an and are as at be been being but by for from has have in into is it its of on or
    that the their they this to was were will with you your our we us able across also
    experience experienced work working role team teams strong excellent proven ability
    years year plus preferred required requirements skills knowledge understanding
    """.split()
)

_WORD_RE = re.compile(r"[a-z0-9+#.]+")


def _terms(text: str) -> set[str]:
    """Content words, with a light plural fold so `renewals` matches `renewal`."""
    out: set[str] = set()
    for word in _WORD_RE.findall(text.lower()):
        token = word.strip(".")
        if len(token) < 2 or token in _STOPWORDS:
            continue
        out.add(token)
        if len(token) > 4 and token.endswith("s") and not token.endswith("ss"):
            out.add(token[:-1])
    return out


def _fact_terms(fact: Fact) -> set[str]:
    parts = [fact.claim, fact.evidence or "", fact.title or "", fact.employer or ""]
    return _terms(" ".join(parts)) | {t for tag in fact.tags for t in _terms(tag)}


def shortlist(
    requirement: Requirement, facts: tuple[Fact, ...], *, limit: int = 12
) -> tuple[Fact, ...]:
    """The facts a judge may consider for `requirement`, best first.

    Overlap is scored against the requirement's content words, with tag matches counted
    double — a tag is a deliberate authored signal, whereas an incidental word in a claim
    is not. Facts scoring zero are still included up to `limit`, because a bridge is often
    lexically unrelated to the requirement it bridges ("shipped a RAG prototype" against
    "familiarity with LLM tooling") and dropping them is exactly how a real transferable
    strength gets scored as a gap.
    """
    wanted = _terms(requirement.text)
    if not wanted:
        return facts[:limit]

    def score(fact: Fact) -> tuple[float, str]:
        overlap = len(wanted & _fact_terms(fact))
        tag_hits = len(wanted & {t for tag in fact.tags for t in _terms(tag)})
        # Fact id as the tiebreak keeps the shortlist stable across runs, so a rerun of
        # the same job produces the same matrix.
        return (overlap + tag_hits, fact.id)

    return tuple(sorted(facts, key=score, reverse=True)[:limit])


# --------------------------------------------------------------------------------------
# Judgement
# --------------------------------------------------------------------------------------


class _Judgement(BaseModel):
    model_config = ConfigDict(extra="forbid")

    verdict: Verdict
    fact_ids: list[str] = Field(
        default_factory=list,
        description="Ids of the facts that evidence this requirement. Empty for `none`.",
    )
    rationale: str = Field(
        default="",
        description="One sentence. For `bridge`, name the transfer explicitly. For "
        "`none`, say what is missing.",
    )


_SYSTEM = f"""\
You decide whether a candidate's evidence meets one requirement from a job posting.

{GROUNDING_RULES}
Return exactly one verdict:

- direct — a fact evidences this requirement outright. The candidate has done this thing.
- bridge — no fact evidences it directly, but something genuinely transfers. Say what
  transfers and what does not. A bridge is an honest "adjacent, not the same".
- none   — nothing in the evidence supports it.

`none` is a correct and useful answer. A stated gap tells the candidate what to work on
or skip; a generous verdict tells them nothing and fails at the interview. When a fact is
merely topically related — same industry, same tools, different work — that is `bridge`
at best and often `none`.

Cite only fact ids from the evidence below. Do not cite a fact you were not shown.
"""


def _judge(
    requirement: Requirement,
    candidates: tuple[Fact, ...],
    *,
    client: Client,
    model: str,
) -> Coverage:
    if not candidates:
        return Coverage(
            requirement=requirement,
            verdict=Verdict.NONE,
            rationale="No facts in the profile relate to this requirement.",
        )

    judgement = client.parse(
        schema=_Judgement,
        system=_SYSTEM,
        user=(
            f"Requirement ({requirement.kind.value}): {requirement.text}\n\n"
            f"Evidence available:\n\n{render_facts(candidates)}"
        ),
        model=model,
        effort="medium",
    )

    allowed = {f.id for f in candidates}
    cited = tuple(dict.fromkeys(fid for fid in judgement.fact_ids if fid in allowed))
    dropped = [fid for fid in judgement.fact_ids if fid not in allowed]

    verdict = judgement.verdict
    rationale = judgement.rationale.strip()

    # A verdict is only as good as its surviving citations. Downgrading rather than
    # retrying keeps the matrix honest without burning a retry on every borderline row;
    # `Coverage` would reject the inconsistent combination anyway.
    if verdict is not Verdict.NONE and not cited:
        verdict = Verdict.NONE
        note = (
            "cited facts that were not in evidence" if dropped else "cited no evidence"
        )
        rationale = f"No usable evidence — the assessment {note}."
    elif verdict is Verdict.NONE:
        cited = ()

    return Coverage(
        requirement=requirement,
        verdict=verdict,
        fact_ids=cited,
        rationale=rationale,
    )


def build_fit_report(
    requirements: RequirementSet,
    fact_base: FactBase,
    *,
    client: Client,
    model: str = WRITER_MODEL,
    shortlist_size: int = 12,
) -> FitReport:
    """Score every requirement against the fact base, one judgement per requirement.

    Judged one at a time on purpose. Scoring the whole list in a single call lets the
    model spread one fact across several requirements to make the table look complete —
    the anchoring failure this design exists to prevent. Per-requirement calls cost more
    and are the reason a gap stays a gap.
    """
    coverage = tuple(
        _judge(
            requirement,
            shortlist(requirement, fact_base.facts, limit=shortlist_size),
            client=client,
            model=model,
        )
        for requirement in requirements.requirements
    )
    return FitReport(job=requirements.job, coverage=coverage)


def render_matrix(report: FitReport) -> str:
    """The coverage matrix as the user reads it — gaps first, because that is the point."""
    symbol = {Verdict.DIRECT: "OK  ", Verdict.BRIDGE: "~   ", Verdict.NONE: "GAP "}
    order = {RequirementKind.MUST: 0, RequirementKind.NICE: 1, RequirementKind.SIGNAL: 2}

    rows = sorted(
        report.coverage,
        key=lambda c: (order[c.requirement.kind], c.credit, c.requirement.text),
    )
    lines = [
        f"{report.job.title} at {report.job.company} — fit {report.score}/100",
        "",
    ]
    for row in rows:
        lines.append(f"{symbol[row.verdict]}[{row.requirement.kind.value:6}] {row.requirement.text}")
        if row.fact_ids:
            lines.append(f"           evidence: {', '.join(row.fact_ids)}")
        if row.rationale:
            lines.append(f"           {row.rationale}")

    if report.blocking_gaps:
        lines += ["", f"{len(report.blocking_gaps)} unmet must-have(s). Apply knowing this."]
    return "\n".join(lines)
