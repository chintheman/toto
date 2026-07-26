"""Licensed-dataset LinkedIn route — the hosted default.

The vendor maintains its own index and carries the compliance burden (GDPR/CCPA, SOC 2,
ISO 27001). Nothing in this path makes a request to LinkedIn from our infrastructure,
which is the entire point: it is the difference between buying data and taking it.

Bright Data's dataset API is implemented here as the reference vendor (~$0.75 per 1,000
records on subscription). Coresignal and similar vendors differ only in field names, so
they subclass and override `_endpoint` and `_to_job`.
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


class LicensedLinkedIn(LinkedInProvider):
    route = LinkedInRoute.LICENSED
    hosted_safe = True

    #: Bright Data list price, ~$0.75/1K records on subscription. Override per contract:
    #: this number sets what a search costs a user, so it must reflect the real rate.
    DEFAULT_MICRO_USD_PER_RECORD = 750

    def __init__(
        self,
        api_key: str | None = None,
        dataset_id: str | None = None,
        micro_usd_per_record: int | None = None,
    ) -> None:
        self.api_key = api_key or os.getenv("BRIGHTDATA_API_KEY", "")
        self.dataset_id = dataset_id or os.getenv("BRIGHTDATA_JOBS_DATASET", "gd_lpfll7v5hcqtkxl6l")
        self._rate = micro_usd_per_record or int(
            os.getenv("JOBFIT_LINKEDIN_MICRO_USD_PER_RECORD", self.DEFAULT_MICRO_USD_PER_RECORD)
        )

    @property
    def micro_usd_per_record(self) -> int:
        return self._rate

    @property
    def _endpoint(self) -> str:
        return "https://api.brightdata.com/datasets/v3/scrape"

    async def search(self, profile: SearchProfile, client: httpx.AsyncClient) -> SearchResult:
        if not self.api_key:
            return SearchResult(
                partial=True,
                notes=(
                    "LinkedIn (licensed) is not configured: set BRIGHTDATA_API_KEY. "
                    "Discovery continues without LinkedIn.",
                ),
            )

        jobs: list[Job] = []
        requests = 0
        notes: list[str] = []

        for term in profile.query_terms:
            for location in profile.locations or ("",):
                requests += 1
                try:
                    response = await client.post(
                        self._endpoint,
                        headers={"Authorization": f"Bearer {self.api_key}"},
                        json={
                            "dataset_id": self.dataset_id,
                            "filters": _filters(profile, term, location),
                            "limit": profile.results_per_source,
                        },
                    )
                    response.raise_for_status()
                    payload = response.json()
                except (httpx.HTTPError, ValueError) as exc:
                    notes.append(f"linkedin/licensed '{term}' failed ({type(exc).__name__})")
                    continue

                jobs.extend(
                    job
                    for raw in _records(payload)
                    if (job := self._to_job(raw)) is not None
                    and not profile.excludes(
                        company=job.company, title=job.title, description=job.description
                    )
                )

        return SearchResult(
            jobs=tuple(jobs[: profile.results_per_source * max(len(profile.query_terms), 1)]),
            cost=SourceCost(
                records=len(jobs),
                requests=requests,
                micro_usd=len(jobs) * self.micro_usd_per_record,
            ),
            partial=bool(notes),
            notes=tuple(notes),
        )

    def _to_job(self, raw: dict[str, Any]) -> Job | None:
        title = raw.get("job_title") or raw.get("title")
        url = raw.get("url") or raw.get("job_url") or raw.get("apply_link")
        if not title or not url:
            return None
        return Job(
            source=SourceName.LINKEDIN,
            source_id=str(raw.get("job_posting_id") or raw.get("id") or url),
            title=str(title),
            company=str(raw.get("company_name") or raw.get("company") or "Unknown"),
            location=raw.get("job_location") or raw.get("location"),
            url=str(url),
            description=raw.get("job_summary") or raw.get("job_description") or raw.get("description"),
            posted_at=_date(raw.get("job_posted_date") or raw.get("posted_at")),
            remote=_remote(raw.get("job_work_type") or raw.get("workplace_type")),
            salary_min=_number(raw.get("base_salary_min") or raw.get("salary_min")),
            salary_max=_number(raw.get("base_salary_max") or raw.get("salary_max")),
            salary_currency=raw.get("salary_currency"),
            raw=raw,
        )


def _filters(profile: SearchProfile, term: str, location: str) -> dict[str, Any]:
    filters: dict[str, Any] = {"keyword": term}
    if location:
        filters["location"] = location
    if profile.posted_within_hours:
        filters["time_range_hours"] = profile.posted_within_hours
    if profile.remote:
        filters["remote"] = [r.value for r in profile.remote]
    return filters


def _records(payload: object) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [r for r in payload if isinstance(r, dict)]
    if isinstance(payload, dict):
        for key in ("data", "results", "records", "items"):
            value = payload.get(key)
            if isinstance(value, list):
                return [r for r in value if isinstance(r, dict)]
    return []


def _date(value: object) -> datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = date_parser.parse(value)
    except (ValueError, OverflowError):
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)


def _number(value: object) -> float | None:
    try:
        return float(str(value).replace(",", "").replace("$", "")) if value else None
    except (TypeError, ValueError):
        return None


def _remote(value: object) -> RemotePolicy:
    text = str(value or "").strip().lower()
    if "remote" in text:
        return RemotePolicy.REMOTE
    if "hybrid" in text:
        return RemotePolicy.HYBRID
    if "on-site" in text or "onsite" in text:
        return RemotePolicy.ONSITE
    return RemotePolicy.UNKNOWN
