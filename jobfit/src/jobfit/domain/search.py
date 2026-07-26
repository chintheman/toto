"""Search profiles — how a user says what they are looking for.

Deliberately not a free-text query string. A saved, structured profile is what makes the
product re-runnable (scrape weekly, only show what is new), shareable (a reseller can
operate one on a client's behalf), and meterable (a search's cost is a function of its
breadth, which we can compute *before* charging for it).
"""

from __future__ import annotations

import re
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, model_validator

from jobfit.domain.models import RemotePolicy


class Seniority(StrEnum):
    INTERN = "intern"
    ENTRY = "entry"
    MID = "mid"
    SENIOR = "senior"
    STAFF = "staff"
    LEAD = "lead"
    DIRECTOR = "director"
    EXECUTIVE = "executive"


class JobCategory(StrEnum):
    """A small curated taxonomy.

    Categories exist so a user who does not know the right keywords can still describe
    what they want. Kept short on purpose: a 900-term ESCO taxonomy is more accurate and
    unusable in a dropdown, and every source has to map onto whatever we choose. Keyword
    search remains available for anyone who wants precision.
    """

    SOFTWARE_ENGINEERING = "software_engineering"
    DATA_AND_ML = "data_and_ml"
    INFRASTRUCTURE = "infrastructure"
    SECURITY = "security"
    PRODUCT = "product"
    DESIGN = "design"
    SALES = "sales"
    MARKETING = "marketing"
    CUSTOMER_SUCCESS = "customer_success"
    OPERATIONS = "operations"
    FINANCE = "finance"
    PEOPLE = "people"
    LEGAL = "legal"
    RESEARCH = "research"

    @property
    def keywords(self) -> tuple[str, ...]:
        """Query terms this category expands to, per source."""
        return _CATEGORY_KEYWORDS[self]


_CATEGORY_KEYWORDS: dict[JobCategory, tuple[str, ...]] = {
    JobCategory.SOFTWARE_ENGINEERING: ("software engineer", "backend engineer", "full stack"),
    JobCategory.DATA_AND_ML: ("machine learning engineer", "data scientist", "ml engineer"),
    JobCategory.INFRASTRUCTURE: ("platform engineer", "site reliability", "devops"),
    JobCategory.SECURITY: ("security engineer", "application security", "security analyst"),
    JobCategory.PRODUCT: ("product manager", "technical product manager"),
    JobCategory.DESIGN: ("product designer", "ux designer", "design lead"),
    JobCategory.SALES: ("account executive", "enterprise sales", "account director"),
    JobCategory.MARKETING: ("product marketing", "growth marketing", "demand generation"),
    JobCategory.CUSTOMER_SUCCESS: ("customer success manager", "solutions architect"),
    JobCategory.OPERATIONS: ("business operations", "revenue operations", "chief of staff"),
    JobCategory.FINANCE: ("financial analyst", "finance manager", "controller"),
    JobCategory.PEOPLE: ("recruiter", "people operations", "talent partner"),
    JobCategory.LEGAL: ("counsel", "legal counsel", "compliance manager"),
    JobCategory.RESEARCH: ("research scientist", "research engineer"),
}


class SearchProfile(BaseModel):
    """One saved set of criteria. The unit a scrape run operates on."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=80)

    keywords: tuple[str, ...] = ()
    categories: tuple[JobCategory, ...] = ()

    locations: tuple[str, ...] = ()
    remote: tuple[RemotePolicy, ...] = ()

    seniority: tuple[Seniority, ...] = ()
    min_salary: float | None = Field(default=None, ge=0)
    salary_currency: str | None = None
    posted_within_hours: int = Field(default=168, ge=1, le=24 * 60)

    exclude_companies: tuple[str, ...] = ()
    exclude_keywords: tuple[str, ...] = ()

    results_per_source: int = Field(default=25, ge=1, le=200)

    @model_validator(mode="after")
    def _needs_something_to_search_for(self) -> SearchProfile:
        if not self.keywords and not self.categories:
            raise ValueError("a search profile needs at least one keyword or category")
        return self

    @property
    def query_terms(self) -> tuple[str, ...]:
        """Every term to issue, keywords first, de-duplicated, order preserved.

        Order matters because sources are paged and budgeted: when a run is capped, the
        user's own words should be spent before the taxonomy's expansions.
        """
        seen: dict[str, None] = {}
        for term in (*self.keywords, *(k for c in self.categories for k in c.keywords)):
            cleaned = " ".join(term.lower().split())
            if cleaned:
                seen.setdefault(cleaned, None)
        return tuple(seen)

    def excludes(self, *, company: str, title: str, description: str | None = None) -> bool:
        """Whether a result should be dropped before it ever costs the user anything.

        Applied client-side after fetch, because no source supports negative filtering
        consistently. Company matching is substring-based on a normalised form so
        "Acme Corp" is excluded by "acme".
        """
        company_norm = _normalise(company)
        if any(_normalise(x) in company_norm for x in self.exclude_companies if x.strip()):
            return True

        haystack = f"{title}\n{description or ''}".lower()
        return any(
            re.search(rf"\b{re.escape(term.lower().strip())}\b", haystack)
            for term in self.exclude_keywords
            if term.strip()
        )


def _normalise(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]+", " ", text.lower())).strip()
