"""Core domain types.

The type system encodes the product's central rule: **generated prose is never
free-floating text**. Every bullet and every paragraph carries the ids of the facts it
was derived from, so `verify.py` can check each claim against exactly the evidence the
writer was allowed to see. A `ResumeBullet` with an empty `derived_from` is invalid by
construction, not by convention.
"""

from __future__ import annotations

import hashlib
import re
from datetime import date, datetime
from enum import StrEnum
from typing import Annotated, Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

# --------------------------------------------------------------------------------------
# Shared
# --------------------------------------------------------------------------------------


class Frozen(BaseModel):
    """Immutable, extra-forbidding base.

    `extra="forbid"` matters more than it looks: model-generated JSON that invents a
    field (a favourite failure mode) fails loudly at parse time rather than being
    silently dropped and shipped.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")


FactId = Annotated[str, Field(pattern=r"^f\.[a-z0-9]+(?:[._-][a-z0-9]+)*$", min_length=3)]


# --------------------------------------------------------------------------------------
# Fact base — the only source of truth about the candidate
# --------------------------------------------------------------------------------------


class Period(Frozen):
    """A date range, month precision. `end is None` means current."""

    start: date
    end: date | None = None

    @classmethod
    def parse(cls, raw: str) -> Self:
        """Parse ``YYYY-MM/YYYY-MM``, ``YYYY-MM/present``, or a bare ``YYYY-MM``."""
        head, _, tail = raw.strip().partition("/")
        start = _parse_month(head)
        if not tail or tail.strip().lower() in {"present", "current", "now", ""}:
            return cls(start=start, end=None)
        return cls(start=start, end=_parse_month(tail))

    def render(self) -> str:
        end = self.end.strftime("%b %Y") if self.end else "Present"
        return f"{self.start.strftime('%b %Y')} – {end}"

    @model_validator(mode="after")
    def _ordered(self) -> Self:
        if self.end and self.end < self.start:
            raise ValueError(f"period ends ({self.end}) before it starts ({self.start})")
        return self


def _parse_month(raw: str) -> date:
    text = raw.strip()
    for fmt in ("%Y-%m-%d", "%Y-%m", "%Y"):
        try:
            return datetime.strptime(text, fmt).date().replace(day=1)
        except ValueError:
            continue
    raise ValueError(f"unparseable date {raw!r}; expected YYYY-MM, YYYY-MM-DD or YYYY")


class FactKind(StrEnum):
    EXPERIENCE = "experience"
    EDUCATION = "education"
    CERTIFICATION = "certification"
    PROJECT = "project"
    SKILL = "skill"
    AWARD = "award"


class Fact(Frozen):
    """One atomic, user-authored, verifiable thing that is true about the candidate.

    Facts are hand-written and version-controlled. Nothing in the pipeline ever creates,
    edits, or infers a `Fact` — that asymmetry is the whole safety property. The model's
    licence is to *select, order, compress and rephrase* facts, never to add one.
    """

    id: FactId
    kind: FactKind = FactKind.EXPERIENCE

    # --- Immutable fields. These may appear in output only exactly as written here. ---
    employer: str | None = None
    title: str | None = None
    period: Period | None = None
    institution: str | None = None
    credential: str | None = None

    # --- The claim itself ---
    claim: str = Field(min_length=10)
    evidence: str | None = Field(
        default=None,
        description="How this would be proven if challenged in an interview. "
        "Facts without evidence are usable but flagged by `jobfit facts audit`.",
    )
    tags: tuple[str, ...] = ()

    @field_validator("tags", mode="before")
    @classmethod
    def _normalise_tags(cls, value: object) -> object:
        if isinstance(value, list | tuple):
            return tuple(sorted({str(t).strip().lower() for t in value if str(t).strip()}))
        return value

    @property
    def numbers(self) -> frozenset[str]:
        """Every numeric token this fact licenses the writer to use.

        Check 2 of the verification gate (number provenance) is a set-difference against
        the union of these across all cited facts. Percentages, currency and plain
        integers all normalise to their digit string so `100%`, `$100k` and `100` compare
        equal — the check is about *whether the magnitude is licensed*, not formatting.
        """
        return extract_numbers(" ".join(filter(None, [self.claim, self.evidence])))

    @property
    def immutables(self) -> frozenset[str]:
        """Proper nouns and credentials that may not be altered or invented."""
        return frozenset(
            v.strip()
            for v in (self.employer, self.title, self.institution, self.credential)
            if v and v.strip()
        )


_NUMBER_RE = re.compile(r"\d[\d,]*(?:\.\d+)?")


def extract_numbers(text: str) -> frozenset[str]:
    """Normalise every numeric token in `text` to a comparable canonical form.

    Deliberately format-insensitive: ``1,200`` and ``1200`` are the same magnitude, and a
    resume that renders one as the other has not fabricated anything. Trailing zeros are
    stripped so ``100.0`` and ``100`` also agree.
    """
    out: set[str] = set()
    for match in _NUMBER_RE.finditer(text):
        raw = match.group().replace(",", "")
        if "." in raw:
            raw = raw.rstrip("0").rstrip(".")
        if raw:
            out.add(raw)
    return frozenset(out)


class FactBase(BaseModel):
    """A validated collection of facts, indexed for retrieval."""

    model_config = ConfigDict(extra="forbid")

    facts: tuple[Fact, ...]

    @model_validator(mode="after")
    def _unique_ids(self) -> Self:
        seen: set[str] = set()
        for fact in self.facts:
            if fact.id in seen:
                raise ValueError(f"duplicate fact id {fact.id!r}")
            seen.add(fact.id)
        return self

    def __getitem__(self, fact_id: str) -> Fact:
        try:
            return next(f for f in self.facts if f.id == fact_id)
        except StopIteration:
            raise KeyError(f"unknown fact id {fact_id!r}") from None

    def get(self, fact_id: str) -> Fact | None:
        return next((f for f in self.facts if f.id == fact_id), None)

    def subset(self, fact_ids: object) -> tuple[Fact, ...]:
        """The facts for `fact_ids`, raising on any id that does not exist.

        Used to build the *only* context a tailoring or entailment call may see.
        """
        return tuple(self[str(i)] for i in fact_ids)  # type: ignore[union-attr]

    @property
    def all_numbers(self) -> frozenset[str]:
        return frozenset().union(*(f.numbers for f in self.facts)) if self.facts else frozenset()

    @property
    def all_immutables(self) -> frozenset[str]:
        return (
            frozenset().union(*(f.immutables for f in self.facts)) if self.facts else frozenset()
        )


# --------------------------------------------------------------------------------------
# Jobs
# --------------------------------------------------------------------------------------


class SourceName(StrEnum):
    LINKEDIN = "linkedin"
    GREENHOUSE = "greenhouse"
    LEVER = "lever"
    ASHBY = "ashby"
    WORKABLE = "workable"
    SMARTRECRUITERS = "smartrecruiters"
    RECRUITEE = "recruitee"
    MYCAREERSFUTURE = "mycareersfuture"
    JOBSPY = "jobspy"


class RemotePolicy(StrEnum):
    ONSITE = "onsite"
    HYBRID = "hybrid"
    REMOTE = "remote"
    UNKNOWN = "unknown"


class Job(BaseModel):
    """A job posting, normalised across every source."""

    model_config = ConfigDict(extra="forbid")

    source: SourceName
    source_id: str
    title: str
    company: str
    location: str | None = None
    remote: RemotePolicy = RemotePolicy.UNKNOWN
    url: str
    description: str | None = None
    posted_at: datetime | None = None
    salary_min: float | None = None
    salary_max: float | None = None
    salary_currency: str | None = None
    department: str | None = None
    raw: dict[str, object] = Field(default_factory=dict, repr=False)

    @property
    def dedupe_key(self) -> str:
        """Identity across sources.

        The same role is routinely listed on LinkedIn, the company's Greenhouse board and
        an aggregator, with three different ids and three different URLs. Company+title+
        location is what actually identifies it to a human, so that is what we hash.
        """
        parts = [
            _normalise(self.company),
            _normalise(self.title),
            _normalise(self.location or ""),
        ]
        return hashlib.sha256("|".join(parts).encode()).hexdigest()[:32]

    @property
    def content_hash(self) -> str:
        """Hash of the description, to detect silent edits and reposts."""
        return hashlib.sha256((self.description or "").strip().encode()).hexdigest()[:32]


_PUNCT_RE = re.compile(r"[^a-z0-9 ]+")
_WS_RE = re.compile(r"\s+")
_COMPANY_SUFFIXES = re.compile(
    r"\b(inc|llc|ltd|limited|corp|corporation|gmbh|bv|plc|pte|pty|co|sa|ag|nv|srl)\b"
)


def _normalise(text: str) -> str:
    lowered = _PUNCT_RE.sub(" ", text.lower())
    stripped = _COMPANY_SUFFIXES.sub(" ", lowered)
    return _WS_RE.sub(" ", stripped).strip()


# --------------------------------------------------------------------------------------
# Requirements, coverage and scoring
# --------------------------------------------------------------------------------------


class RequirementKind(StrEnum):
    MUST = "must"
    NICE = "nice"
    SIGNAL = "signal"  # cultural/behavioural cues, not checklist items


class Requirement(Frozen):
    """One extracted expectation from a job description."""

    text: str = Field(min_length=3)
    kind: RequirementKind
    weight: float = Field(default=1.0, ge=0.0, le=3.0)


class Verdict(StrEnum):
    DIRECT = "direct"  # a fact evidences this outright
    BRIDGE = "bridge"  # transferable, and we say so explicitly
    NONE = "none"  # no evidence; stated as a gap, never papered over


class Coverage(Frozen):
    """How one requirement is (or is not) met. The unit the user actually reads."""

    requirement: Requirement
    verdict: Verdict
    fact_ids: tuple[str, ...] = ()
    rationale: str = ""

    @model_validator(mode="after")
    def _evidence_matches_verdict(self) -> Self:
        if self.verdict is Verdict.NONE and self.fact_ids:
            raise ValueError("verdict NONE cannot cite facts")
        if self.verdict is not Verdict.NONE and not self.fact_ids:
            raise ValueError(f"verdict {self.verdict} must cite at least one fact")
        return self

    @property
    def credit(self) -> float:
        return {Verdict.DIRECT: 1.0, Verdict.BRIDGE: 0.5, Verdict.NONE: 0.0}[self.verdict]


class FitReport(BaseModel):
    """The coverage matrix plus a score derived from it — never a bare number."""

    model_config = ConfigDict(extra="forbid")

    job: Job
    coverage: tuple[Coverage, ...]

    @property
    def score(self) -> float:
        """Weighted coverage, 0–100. Must-haves count double; signals are not scored.

        Derived rather than model-generated on purpose: a score a model invents cannot be
        audited, whereas this one decomposes back into the exact rows that produced it.
        """
        scored = [c for c in self.coverage if c.requirement.kind is not RequirementKind.SIGNAL]
        if not scored:
            return 0.0
        weight = lambda c: c.requirement.weight * (  # noqa: E731
            2.0 if c.requirement.kind is RequirementKind.MUST else 1.0
        )
        total = sum(weight(c) for c in scored)
        earned = sum(weight(c) * c.credit for c in scored)
        return round(100.0 * earned / total, 1) if total else 0.0

    @property
    def blocking_gaps(self) -> tuple[Coverage, ...]:
        """Unmet must-haves. Surfaced first, because this is the honest part."""
        return tuple(
            c
            for c in self.coverage
            if c.requirement.kind is RequirementKind.MUST and c.verdict is Verdict.NONE
        )


# --------------------------------------------------------------------------------------
# Generated documents
# --------------------------------------------------------------------------------------


class ResumeBullet(Frozen):
    """A generated bullet, permanently bound to the facts that licensed it."""

    text: str = Field(min_length=10)
    derived_from: tuple[FactId, ...] = Field(min_length=1)


class ResumeSection(Frozen):
    heading: str
    bullets: tuple[ResumeBullet, ...] = ()
    body: str | None = None


class TailoredResume(Frozen):
    angle: str = Field(description="The through-line chosen for this application.")
    summary: str
    sections: tuple[ResumeSection, ...]

    @property
    def cited_fact_ids(self) -> frozenset[str]:
        return frozenset(
            fid for s in self.sections for b in s.bullets for fid in b.derived_from
        )

    @property
    def prose(self) -> str:
        """All generated text, for the deterministic scans."""
        parts = [self.summary]
        for section in self.sections:
            if section.body:
                parts.append(section.body)
            parts.extend(b.text for b in section.bullets)
        return "\n".join(parts)


class CoverLetter(Frozen):
    angle: str
    paragraphs: tuple[str, ...] = Field(min_length=2)
    derived_from: tuple[FactId, ...] = Field(min_length=1)

    @property
    def prose(self) -> str:
        return "\n\n".join(self.paragraphs)
