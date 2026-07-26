"""python-jobspy route — SELF-HOST ONLY, off by default.

[JobSpy](https://github.com/speedyapply/JobSpy) (MIT) is the best-maintained multi-board
scraper available and there is no reason to reimplement it. It scrapes from the caller's
IP, so the same terms-of-service position as the guest route applies and it is gated the
same way.

Installed separately (`pip install "jobfit[jobspy]"`) so the dependency is absent from a
hosted deployment entirely — the safest way to not run something is to not ship it.
"""

from __future__ import annotations

import asyncio
import os
from datetime import UTC, datetime
from typing import Any

import httpx

from jobfit.domain.models import Job, RemotePolicy, SourceName
from jobfit.domain.search import SearchProfile
from jobfit.sources.base import SearchResult, SourceCost
from jobfit.sources.linkedin.base import LinkedInProvider, LinkedInRoute


class JobSpyLinkedIn(LinkedInProvider):
    route = LinkedInRoute.JOBSPY
    hosted_safe = False

    def __init__(self, sites: tuple[str, ...] | None = None) -> None:
        configured = os.getenv("JOBFIT_JOBSPY_SITES", "linkedin")
        self.sites = sites or tuple(s.strip() for s in configured.split(",") if s.strip())

    @property
    def micro_usd_per_record(self) -> int:
        return 0

    async def search(self, profile: SearchProfile, client: httpx.AsyncClient) -> SearchResult:
        try:
            from jobspy import scrape_jobs
        except ImportError:
            return SearchResult(
                partial=True,
                notes=('jobspy is not installed. Install with: pip install "jobfit[jobspy]"',),
            )

        jobs: list[Job] = []
        notes: list[str] = []

        for term in profile.query_terms:
            try:
                # JobSpy is synchronous and network-bound; a thread keeps it from
                # blocking the event loop while other sources are in flight.
                frame = await asyncio.to_thread(
                    scrape_jobs,
                    site_name=list(self.sites),
                    search_term=term,
                    location=profile.locations[0] if profile.locations else None,
                    results_wanted=profile.results_per_source,
                    hours_old=profile.posted_within_hours,
                    is_remote=RemotePolicy.REMOTE in profile.remote or None,
                )
            except Exception as exc:  # noqa: BLE001 - third-party, raises broadly
                notes.append(f"jobspy '{term}' failed ({type(exc).__name__}: {exc})")
                continue

            for record in frame.to_dict("records") if hasattr(frame, "to_dict") else []:
                job = _to_job(record)
                if job and not profile.excludes(
                    company=job.company, title=job.title, description=job.description
                ):
                    jobs.append(job)

        return SearchResult(
            jobs=tuple(jobs),
            cost=SourceCost(records=len(jobs), requests=len(profile.query_terms)),
            partial=bool(notes),
            notes=tuple(notes),
        )


def _to_job(record: dict[str, Any]) -> Job | None:
    title, url = record.get("title"), record.get("job_url")
    if not title or not url:
        return None

    site = str(record.get("site") or "").lower()
    location = record.get("location")
    return Job(
        source=SourceName.LINKEDIN if "linkedin" in site else SourceName.JOBSPY,
        source_id=str(record.get("id") or url),
        title=str(title),
        company=str(record.get("company") or "Unknown"),
        location=str(location) if location and str(location) != "nan" else None,
        url=str(url),
        description=_clean(record.get("description")),
        posted_at=_date(record.get("date_posted")),
        remote=RemotePolicy.REMOTE if record.get("is_remote") else RemotePolicy.UNKNOWN,
        salary_min=_number(record.get("min_amount")),
        salary_max=_number(record.get("max_amount")),
        salary_currency=_clean(record.get("currency")),
    )


def _clean(value: object) -> str | None:
    """Drop pandas' float NaN, which stringifies to the literal "nan"."""
    if value is None:
        return None
    text = str(value).strip()
    return text if text and text.lower() != "nan" else None


def _number(value: object) -> float | None:
    try:
        number = float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None
    return None if number != number else number  # NaN != NaN


def _date(value: object) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=UTC)
    from dateutil import parser as date_parser

    try:
        parsed = date_parser.parse(str(value))
    except (ValueError, OverflowError):
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)
