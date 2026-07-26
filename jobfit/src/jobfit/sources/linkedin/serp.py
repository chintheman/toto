"""Google-for-Jobs LinkedIn route.

Google indexes LinkedIn postings through structured data that LinkedIn publishes for
exactly that purpose, so reading Google's index is neither scraping LinkedIn nor a terms
breach. Cheap (SerpApi and JSearch both start around $25/month flat) and a useful
coverage widener alongside the licensed route.

The honest limitation, surfaced in `notes` rather than buried: coverage is Google's, not
LinkedIn's. Not every posting reaches Google's index, and recency lags. This is a good
supplement and a poor sole source.
"""

from __future__ import annotations

import os
from datetime import UTC, datetime
from typing import Any

import httpx
from dateutil import parser as date_parser

from jobfit.domain.models import Job, RemotePolicy, SourceName
from jobfit.domain.search import SearchProfile
from jobfit.sources.base import SearchResult, SourceCost
from jobfit.sources.linkedin.base import LinkedInProvider, LinkedInRoute


class SerpLinkedIn(LinkedInProvider):
    route = LinkedInRoute.SERP
    hosted_safe = True

    #: Flat-rate plans amortise to roughly this per record at typical volume. Used for
    #: reporting only; the meter should bill flat-rate routes on requests, not records.
    DEFAULT_MICRO_USD_PER_RECORD = 40

    def __init__(self, api_key: str | None = None, engine: str | None = None) -> None:
        self.api_key = api_key or os.getenv("SERPAPI_KEY", "")
        self.engine = engine or os.getenv("JOBFIT_SERP_ENGINE", "serpapi")

    @property
    def micro_usd_per_record(self) -> int:
        return int(os.getenv("JOBFIT_SERP_MICRO_USD_PER_RECORD", self.DEFAULT_MICRO_USD_PER_RECORD))

    async def search(self, profile: SearchProfile, client: httpx.AsyncClient) -> SearchResult:
        if not self.api_key:
            return SearchResult(
                partial=True,
                notes=("LinkedIn (serp) is not configured: set SERPAPI_KEY.",),
            )

        jobs: list[Job] = []
        requests = 0
        notes = [
            "linkedin/serp reflects Google's index, which lags LinkedIn and does not "
            "contain every posting."
        ]

        for term in profile.query_terms:
            for location in profile.locations or ("",):
                requests += 1
                try:
                    response = await client.get(
                        "https://serpapi.com/search",
                        params={
                            "engine": "google_jobs",
                            "q": f"{term} {location}".strip(),
                            "api_key": self.api_key,
                            "hl": "en",
                        },
                    )
                    response.raise_for_status()
                    payload = response.json()
                except (httpx.HTTPError, ValueError) as exc:
                    notes.append(f"linkedin/serp '{term}' failed ({type(exc).__name__})")
                    continue

                for raw in payload.get("jobs_results", []):
                    job = _to_job(raw)
                    # Google aggregates every board; keep only what originates on LinkedIn,
                    # since the ATS sources cover the rest first-party and in full.
                    if job is None or "linkedin" not in job.url.lower():
                        continue
                    if profile.excludes(
                        company=job.company, title=job.title, description=job.description
                    ):
                        continue
                    jobs.append(job)

        return SearchResult(
            jobs=tuple(jobs),
            cost=SourceCost(
                records=len(jobs),
                requests=requests,
                micro_usd=len(jobs) * self.micro_usd_per_record,
            ),
            partial=len(notes) > 1,
            notes=tuple(notes),
        )


def _to_job(raw: dict[str, Any]) -> Job | None:
    title = raw.get("title")
    if not title:
        return None

    url = raw.get("share_link") or ""
    for option in raw.get("apply_options") or []:
        link = option.get("link", "")
        if "linkedin" in link.lower():
            url = link
            break
    if not url:
        return None

    extensions = raw.get("detected_extensions") or {}
    return Job(
        source=SourceName.LINKEDIN,
        source_id=str(raw.get("job_id") or url),
        title=str(title),
        company=str(raw.get("company_name") or "Unknown"),
        location=raw.get("location"),
        url=url,
        description=raw.get("description"),
        posted_at=_relative_date(extensions.get("posted_at")),
        remote=RemotePolicy.REMOTE if extensions.get("work_from_home") else RemotePolicy.UNKNOWN,
        raw=raw,
    )


def _relative_date(value: object) -> datetime | None:
    """Google reports recency as "3 days ago" rather than a timestamp.

    Parsed to an absolute time so the freshness filter works uniformly across sources.
    Approximate by construction — an absolute timestamp is not recoverable from a relative
    one — which is acceptable for a filter measured in hours.
    """
    if not isinstance(value, str):
        return None
    text = value.strip().lower()
    from datetime import timedelta

    units = {"minute": 1 / 60, "hour": 1, "day": 24, "week": 168, "month": 730}
    for unit, hours in units.items():
        if unit in text:
            digits = "".join(c for c in text if c.isdigit())
            count = int(digits) if digits else 1
            return datetime.now(UTC) - timedelta(hours=count * hours)
    try:
        parsed = date_parser.parse(text)
    except (ValueError, OverflowError):
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)
