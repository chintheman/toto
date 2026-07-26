"""LinkedIn guest-endpoint route — SELF-HOST ONLY, off by default.

`/jobs-guest/jobs/api/seeMoreJobPostings/search` serves logged-out HTML with no key. It
is also the path that ended Proxycurl. Requests originate from *your* IP, which breaches
LinkedIn's user agreement as a contract matter regardless of the CFAA position, and a
single IP is throttled after roughly ten pages.

Available so a self-hoster running this for themselves can choose it knowingly.
`resolve_provider` refuses to construct it without an explicit opt-in, so it cannot be
reached by a configuration mistake. The hosted product must never enable it.
"""

from __future__ import annotations

import asyncio
import os
import re
from datetime import UTC, datetime

import httpx
from dateutil import parser as date_parser
from selectolax.parser import HTMLParser

from jobfit.domain.models import Job, SourceName
from jobfit.domain.search import SearchProfile
from jobfit.sources.base import SearchResult, SourceCost
from jobfit.sources.linkedin.base import LinkedInProvider, LinkedInRoute

_SEARCH_URL = "https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search"
_PAGE_SIZE = 25
# LinkedIn throttles a single IP at roughly ten pages. Stopping at eight leaves headroom
# so a run degrades into "partial results" rather than a 429 mid-way.
_MAX_PAGES = 8


class GuestLinkedIn(LinkedInProvider):
    route = LinkedInRoute.GUEST
    hosted_safe = False

    def __init__(self, delay_seconds: float | None = None, proxy: str | None = None) -> None:
        # Politeness delay. Below ~2s the endpoint starts 429ing within a page or two.
        self.delay = delay_seconds if delay_seconds is not None else float(
            os.getenv("JOBFIT_LINKEDIN_DELAY", "2.5")
        )
        self.proxy = proxy or os.getenv("JOBFIT_LINKEDIN_PROXY") or None

    @property
    def micro_usd_per_record(self) -> int:
        return 0  # No vendor cost. The cost is legal risk, which a meter cannot express.

    async def search(self, profile: SearchProfile, client: httpx.AsyncClient) -> SearchResult:
        jobs: list[Job] = []
        requests = 0
        notes: list[str] = []
        throttled = False

        for term in profile.query_terms:
            for location in profile.locations or ("",):
                for page in range(_MAX_PAGES):
                    if len(jobs) >= profile.results_per_source:
                        break
                    requests += 1
                    try:
                        response = await client.get(
                            _SEARCH_URL,
                            params={
                                "keywords": term,
                                "location": location,
                                "start": page * _PAGE_SIZE,
                                **_recency(profile.posted_within_hours),
                            },
                            headers={"Accept": "text/html", "X-Requested-With": "XMLHttpRequest"},
                        )
                    except httpx.HTTPError as exc:
                        notes.append(f"linkedin/guest '{term}' failed ({type(exc).__name__})")
                        break

                    if response.status_code == 429:
                        throttled = True
                        notes.append(
                            f"linkedin/guest throttled (429) at page {page + 1} for {term!r}. "
                            "A single IP is limited to roughly ten pages; results are partial."
                        )
                        break
                    if response.status_code >= 400 or not response.text.strip():
                        break

                    page_jobs = [
                        job
                        for job in _parse(response.text)
                        if not profile.excludes(company=job.company, title=job.title)
                    ]
                    if not page_jobs:
                        break
                    jobs.extend(page_jobs)
                    await asyncio.sleep(self.delay)

        return SearchResult(
            jobs=tuple(jobs[: profile.results_per_source]),
            cost=SourceCost(records=len(jobs), requests=requests),
            partial=throttled or bool(notes),
            notes=tuple(notes),
        )


def _recency(hours: int) -> dict[str, str]:
    return {"f_TPR": f"r{int(hours) * 3600}"} if hours else {}


def _parse(html_text: str) -> list[Job]:
    """Extract postings from the guest endpoint's HTML card list."""
    tree = HTMLParser(html_text)
    jobs: list[Job] = []

    for card in tree.css("li"):
        title_node = card.css_first(".base-search-card__title") or card.css_first("h3")
        company_node = card.css_first(".base-search-card__subtitle") or card.css_first("h4")
        link_node = card.css_first("a.base-card__full-link") or card.css_first("a")
        if not (title_node and link_node):
            continue

        url = (link_node.attributes.get("href") or "").split("?")[0]
        if not url:
            continue

        location_node = card.css_first(".job-search-card__location")
        time_node = card.css_first("time")

        jobs.append(
            Job(
                source=SourceName.LINKEDIN,
                source_id=_job_id(url),
                title=title_node.text(strip=True),
                company=company_node.text(strip=True) if company_node else "Unknown",
                location=location_node.text(strip=True) if location_node else None,
                url=url,
                # The card carries no body; enrichment fetches it from the posting page.
                description=None,
                posted_at=_datetime(time_node.attributes.get("datetime") if time_node else None),
            )
        )
    return jobs


_ID_RE = re.compile(r"-(\d+)(?:\?|$)")


def _job_id(url: str) -> str:
    match = _ID_RE.search(url)
    return match.group(1) if match else url


def _datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = date_parser.parse(value)
    except (ValueError, OverflowError):
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)
