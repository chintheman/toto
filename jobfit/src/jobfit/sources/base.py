"""The source interface, and the cost accounting that sits underneath billing.

Every source reports what a search *cost* alongside what it returned. That coupling is
deliberate: credits are only honest if the price a user pays tracks the money actually
spent on their behalf, and the only place that is knowable is at the fetch boundary.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Sequence

import httpx
from pydantic import BaseModel, ConfigDict, Field

from jobfit.domain.models import Job, SourceName
from jobfit.domain.search import SearchProfile

DEFAULT_TIMEOUT = httpx.Timeout(20.0, connect=10.0)
USER_AGENT = "jobfit/0.1 (+https://github.com/chintheman/jobfit)"


class SourceCost(BaseModel):
    """What one search actually consumed."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    records: int = 0
    requests: int = 0
    micro_usd: int = Field(
        default=0,
        description="Vendor spend in millionths of a USD. Integer to keep the credit "
        "ledger exact — floating-point money accumulates error across a ledger that is "
        "summed rather than stored.",
    )

    def __add__(self, other: SourceCost) -> SourceCost:
        return SourceCost(
            records=self.records + other.records,
            requests=self.requests + other.requests,
            micro_usd=self.micro_usd + other.micro_usd,
        )


class SearchResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    jobs: tuple[Job, ...] = ()
    cost: SourceCost = SourceCost()
    partial: bool = Field(
        default=False,
        description="True when the source was throttled or capped and returned less than "
        "asked for. Surfaced to the user rather than hidden: silent truncation reads as "
        "'there are no more jobs', which is a different and much worse statement.",
    )
    notes: tuple[str, ...] = ()


class Source(ABC):
    """A place jobs come from."""

    name: SourceName

    #: False for anything that requests from a job board using the operator's own IP.
    #: The hosted product refuses to enable these; self-hosters may opt in. See README.
    hosted_safe: bool = True

    @abstractmethod
    async def search(self, profile: SearchProfile, client: httpx.AsyncClient) -> SearchResult:
        """Find jobs matching `profile`. Must not raise for ordinary remote failures.

        Sources return `partial=True` with notes instead of raising, because one flaky
        board must never fail an entire multi-source run the user has been charged for.
        """

    async def fetch_description(self, job: Job, client: httpx.AsyncClient) -> str | None:
        """Full description, when the search endpoint returns only a summary."""
        return job.description


def make_client(
    *, proxy: str | None = None, headers: dict[str, str] | None = None
) -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=DEFAULT_TIMEOUT,
        follow_redirects=True,
        headers={"User-Agent": USER_AGENT, **(headers or {})},
        proxy=proxy,
    )


def dedupe(jobs: Sequence[Job]) -> tuple[Job, ...]:
    """Collapse the same role listed on several boards.

    A single opening routinely appears on LinkedIn, the company's own Greenhouse board and
    an aggregator, with three ids and three URLs. Keeping the richest copy matters for
    quality — the aggregator's truncated blurb produces a visibly worse tailored resume
    than the full description from the company's own board.
    """
    best: dict[str, Job] = {}
    for job in jobs:
        current = best.get(job.dedupe_key)
        if current is None or _richness(job) > _richness(current):
            best[job.dedupe_key] = job
    return tuple(best.values())


def _richness(job: Job) -> tuple[int, int, int]:
    """Prefer a real description, then structured salary, then a first-party source."""
    return (
        len(job.description or ""),
        int(job.salary_min is not None),
        int(job.source is not SourceName.JOBSPY),
    )
