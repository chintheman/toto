"""Job description → typed requirements.

A job description is mostly not requirements. It is company boilerplate, benefits, an
EEO statement, and a paragraph about being passionate. Feeding all of that to a scorer
produces a coverage matrix about the wrong things, so the noise is stripped
deterministically before the model ever sees the text.

The extraction is held to the same standard as the generation: **every requirement must
quote the job description verbatim**. An extracted requirement that does not appear in
the posting is dropped, not trusted. Without that check a hallucinated requirement shows
up downstream as a confident, well-formatted gap the candidate does not actually have —
which is worse than missing it, because they would act on it.
"""

from __future__ import annotations

import re

from pydantic import BaseModel, ConfigDict, Field

from jobfit.domain.models import Job, Requirement, RequirementKind
from jobfit.llm import EXTRACTOR_MODEL, Client

# --------------------------------------------------------------------------------------
# Deterministic pre-pass
# --------------------------------------------------------------------------------------

#: Headings whose sections carry no requirements. Matched against a line that looks like
#: a heading, so a passing mention of "benefits" inside a bullet is left alone.
_NOISE_HEADINGS = re.compile(
    r"^\s*(?:[#*\-•\s]*)("
    r"benefits?|perks?|what we offer|our offer|compensation (?:and|&) benefits"
    r"|equal (?:employment )?opportunit\w*|eeo\b|diversity(?: and inclusion)?"
    r"|about (?:us|the company|our company)|who we are|our (?:story|mission|values)"
    r"|privacy|data protection|legal|disclaimer"
    r"|how to apply|application process|next steps"
    r")\b[:\s]*$",
    re.IGNORECASE,
)

#: A heading that reintroduces substance, ending a noise run.
_SIGNAL_HEADINGS = re.compile(
    r"^\s*(?:[#*\-•\s]*)("
    r"requirements?|qualifications?|what you.{0,3}ll (?:do|bring|need)"
    r"|responsibilit\w+|the role|about the role|your (?:role|impact)"
    r"|skills?|experience|must[- ]haves?|nice[- ]to[- ]haves?|preferred"
    r"|who you are|we.{0,3}re looking for"
    r")\b[:\s]*$",
    re.IGNORECASE,
)


def strip_boilerplate(description: str) -> str:
    """Drop sections that cannot contain requirements.

    Heading-run based rather than sentence-classification based: boilerplate travels in
    labelled blocks, and dropping a block is far safer than dropping individual lines
    that happen to mention equity or insurance. When no heading is recognised the text
    passes through untouched — under-stripping costs tokens, over-stripping loses a
    must-have.
    """
    kept: list[str] = []
    skipping = False
    for line in description.splitlines():
        if _NOISE_HEADINGS.match(line):
            skipping = True
            continue
        if _SIGNAL_HEADINGS.match(line):
            skipping = False
        if not skipping:
            kept.append(line)

    result = "\n".join(kept).strip()
    # A posting written as one unlabelled prose block can match a noise heading early and
    # lose almost everything. Keeping the original is the safer failure.
    return result if len(result) >= len(description) * 0.25 else description.strip()


_WS = re.compile(r"\s+")

#: Postings routinely arrive with typographic quotes while a model copying a span emits
#: straight ones. Folding both ways stops a correctly-copied quote failing the check on
#: punctuation alone.
_SMART_QUOTES = str.maketrans("‘’“”", "''\"\"")


def _flatten(text: str) -> str:
    """Lowercase with whitespace and quote marks normalised, for substring comparison."""
    swapped = text.translate(_SMART_QUOTES)
    return _WS.sub(" ", swapped.lower()).strip()


# --------------------------------------------------------------------------------------
# Model output
# --------------------------------------------------------------------------------------


class _ExtractedRequirement(BaseModel):
    """One requirement, with the span of the posting that licensed it."""

    model_config = ConfigDict(extra="forbid")

    text: str = Field(
        min_length=3,
        description="The requirement in plain words, as a hiring manager would state it.",
    )
    kind: RequirementKind
    weight: float = Field(
        ge=0.0,
        le=3.0,
        description="How much this matters *within its kind*: 1.0 is ordinary, above 1.0 "
        "for something the posting emphasises or repeats, below for an aside.",
    )
    quote: str = Field(
        min_length=8,
        description="A verbatim span copied from the job description that states this "
        "requirement. Copy it exactly; do not paraphrase, correct or shorten to fewer "
        "than a few words.",
    )


class _Extraction(BaseModel):
    model_config = ConfigDict(extra="forbid")

    requirements: list[_ExtractedRequirement]
    revealed_priorities: list[str] = Field(
        default_factory=list,
        description="What this posting actually cares about, inferred from emphasis, "
        "ordering and repetition rather than from the checklist. Used to choose which "
        "through-line to lead with.",
    )


class RequirementSet(BaseModel):
    """Extracted requirements plus what had to be thrown away to get them."""

    model_config = ConfigDict(extra="forbid")

    job: Job
    requirements: tuple[Requirement, ...]
    revealed_priorities: tuple[str, ...] = ()
    #: Requirements the model produced that do not appear in the posting. Non-empty here
    #: is a signal about the extraction, so it is surfaced rather than silently swallowed.
    unquoted: tuple[str, ...] = ()

    @property
    def must_haves(self) -> tuple[Requirement, ...]:
        return tuple(r for r in self.requirements if r.kind is RequirementKind.MUST)


# --------------------------------------------------------------------------------------
# Extraction
# --------------------------------------------------------------------------------------

_SYSTEM = """\
You read job postings and extract what the employer is actually asking for.

Classify each requirement:
- must    — stated as required, or plainly non-negotiable for the role
- nice    — preferred, bonus, "a plus"
- signal  — a cultural or behavioural cue rather than a checklist item ("comfortable with
            ambiguity", "low ego"). These matter for tone, not for scoring.

Rules:
- Split compound requirements. "5+ years in enterprise SaaS sales, ideally in APAC" is a
  must (the experience) and a nice (the region), not one item.
- Do not invent an industry-standard requirement the posting does not state. If seniority
  is never given, there is no seniority requirement.
- Copy the `quote` verbatim from the posting. It is checked against the source text and
  the requirement is discarded if it does not match, so paraphrasing loses the item.
- Skip generic filler that applies to every job ("team player", "strong communication")
  unless the posting gives it real weight.

For revealed_priorities, say what the posting is really optimising for — read the
ordering, what gets a whole paragraph versus one clause, and what is repeated. This is
usually narrower than the requirement list, and often differs from it.
"""


def extract_requirements(
    job: Job,
    *,
    client: Client,
    model: str = EXTRACTOR_MODEL,
) -> RequirementSet:
    """Extract typed requirements from `job`, discarding any that misquote the posting."""
    if not job.description or not job.description.strip():
        return RequirementSet(job=job, requirements=())

    body = strip_boilerplate(job.description)
    extraction = client.parse(
        schema=_Extraction,
        system=_SYSTEM,
        user=f"Job title: {job.title}\nCompany: {job.company}\n\n---\n\n{body}",
        model=model,
        effort="medium",
    )

    # Quotes are checked against the *original* description: stripping boilerplate is a
    # token optimisation, and a requirement quoting a stripped section is still honest.
    haystack = _flatten(job.description)
    kept: list[Requirement] = []
    unquoted: list[str] = []
    seen: set[str] = set()

    for item in extraction.requirements:
        if _flatten(item.quote) not in haystack:
            unquoted.append(item.text)
            continue
        key = _flatten(item.text)
        if key in seen:
            continue
        seen.add(key)
        kept.append(Requirement(text=item.text.strip(), kind=item.kind, weight=item.weight))

    return RequirementSet(
        job=job,
        requirements=tuple(kept),
        revealed_priorities=tuple(p.strip() for p in extraction.revealed_priorities if p.strip()),
        unquoted=tuple(unquoted),
    )
