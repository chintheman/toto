"""Public ATS job boards.

Greenhouse, Lever, Ashby, Workable, SmartRecruiters and Recruitee all expose the JSON
that powers their customers' own careers pages. No key, no auth, no terms-of-service grey
area: the company published this endpoint so that its jobs would be read.

These boards are also where the jobs are *first*, and where the description is complete
rather than an aggregator's truncated blurb — which matters directly to output quality,
because a tailored resume is only as good as the requirements it was written against.

The cost is that you must know which boards to poll. `companies.yaml` carries that list.
"""

from __future__ import annotations

import asyncio
import html
import re
from collections.abc import Callable, Iterable
from datetime import UTC, datetime
from typing import Any

import httpx
from dateutil import parser as date_parser
from selectolax.parser import HTMLParser

from jobfit.domain.models import Job, RemotePolicy, SourceName
from jobfit.domain.search import SearchProfile
from jobfit.sources.base import SearchResult, Source, SourceCost

Json = dict[str, Any]


class AtsBoard(Source):
    """One company's board on one ATS."""

    def __init__(self, token: str, company: str | None = None) -> None:
        self.token = token
        self.company = company or token.replace("-", " ").title()

    async def search(self, profile: SearchProfile, client: httpx.AsyncClient) -> SearchResult:
        try:
            response = await client.get(self.url)
            response.raise_for_status()
            payload = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            # One unreachable board must not fail a run the user paid for.
            return SearchResult(
                cost=SourceCost(requests=1),
                partial=True,
                notes=(f"{self.name}:{self.token} unavailable ({type(exc).__name__})",),
            )

        jobs = [job for raw in self._entries(payload) if (job := self._to_job(raw)) is not None]
        matched = _filter(jobs, profile)
        return SearchResult(
            jobs=tuple(matched[: profile.results_per_source]),
            cost=SourceCost(records=len(jobs), requests=1),
        )

    @property
    def url(self) -> str:
        raise NotImplementedError

    def _entries(self, payload: Json | list[Json]) -> list[Json]:
        raise NotImplementedError

    def _to_job(self, raw: Json) -> Job | None:
        raise NotImplementedError


class Greenhouse(AtsBoard):
    name = SourceName.GREENHOUSE

    @property
    def url(self) -> str:
        return f"https://boards-api.greenhouse.io/v1/boards/{self.token}/jobs?content=true"

    def _entries(self, payload: Json | list[Json]) -> list[Json]:
        return list(payload.get("jobs", [])) if isinstance(payload, dict) else []

    def _to_job(self, raw: Json) -> Job | None:
        if not (title := raw.get("title")):
            return None
        departments = raw.get("departments") or []
        return _job(
            source=self.name,
            source_id=str(raw.get("id", "")),
            title=str(title),
            company=self.company,
            location=(raw.get("location") or {}).get("name"),
            url=str(raw.get("absolute_url", "")),
            description=_text(raw.get("content")),
            posted_at=_date(raw.get("first_published") or raw.get("updated_at")),
            department=departments[0].get("name") if departments else None,
            raw=raw,
        )


class Lever(AtsBoard):
    name = SourceName.LEVER

    @property
    def url(self) -> str:
        return f"https://api.lever.co/v0/postings/{self.token}?mode=json"

    def _entries(self, payload: Json | list[Json]) -> list[Json]:
        return list(payload) if isinstance(payload, list) else []

    def _to_job(self, raw: Json) -> Job | None:
        if not (title := raw.get("text")):
            return None
        categories = raw.get("categories") or {}
        # Lever gives plain text directly, so prefer it over re-flattening the HTML.
        body = raw.get("descriptionPlain") or _text(raw.get("description"))
        lists = "\n".join(
            f"{item.get('text', '')}\n{_text(item.get('content'))}" for item in raw.get("lists", [])
        )
        return _job(
            source=self.name,
            source_id=str(raw.get("id", "")),
            title=str(title),
            company=self.company,
            location=categories.get("location"),
            url=str(raw.get("hostedUrl", "")),
            description="\n\n".join(filter(None, [body, lists])),
            posted_at=_epoch_ms(raw.get("createdAt")),
            department=categories.get("team"),
            raw=raw,
        )


class Ashby(AtsBoard):
    name = SourceName.ASHBY

    @property
    def url(self) -> str:
        return (
            "https://api.ashbyhq.com/posting-api/job-board/"
            f"{self.token}?includeCompensation=true"
        )

    def _entries(self, payload: Json | list[Json]) -> list[Json]:
        return list(payload.get("jobs", [])) if isinstance(payload, dict) else []

    def _to_job(self, raw: Json) -> Job | None:
        if not (title := raw.get("title")):
            return None
        return _job(
            source=self.name,
            source_id=str(raw.get("id", "")),
            title=str(title),
            company=str(raw.get("organizationName") or self.company),
            location=raw.get("location"),
            url=str(raw.get("jobUrl") or raw.get("applyUrl") or ""),
            description=raw.get("descriptionPlain") or _text(raw.get("descriptionHtml")),
            posted_at=_date(raw.get("publishedAt")),
            department=raw.get("department") or raw.get("team"),
            remote=RemotePolicy.REMOTE if raw.get("isRemote") else RemotePolicy.UNKNOWN,
            raw=raw,
        )


class Workable(AtsBoard):
    name = SourceName.WORKABLE

    @property
    def url(self) -> str:
        return f"https://apply.workable.com/api/v1/widget/accounts/{self.token}"

    def _entries(self, payload: Json | list[Json]) -> list[Json]:
        return list(payload.get("jobs", [])) if isinstance(payload, dict) else []

    def _to_job(self, raw: Json) -> Job | None:
        if not (title := raw.get("title")):
            return None
        location = raw.get("location") or {}
        parts = [location.get("city"), location.get("region"), location.get("country")]
        return _job(
            source=self.name,
            source_id=str(raw.get("shortcode") or raw.get("id", "")),
            title=str(title),
            company=str(raw.get("company") or self.company),
            location=", ".join(p for p in parts if p) or None,
            url=str(raw.get("url") or raw.get("application_url") or ""),
            description=_text(raw.get("description")),
            posted_at=_date(raw.get("published_on") or raw.get("created_at")),
            department=raw.get("department"),
            remote=RemotePolicy.REMOTE if location.get("workplace") == "remote" else RemotePolicy.UNKNOWN,
            raw=raw,
        )


class SmartRecruiters(AtsBoard):
    name = SourceName.SMARTRECRUITERS

    @property
    def url(self) -> str:
        return f"https://api.smartrecruiters.com/v1/companies/{self.token}/postings?limit=100"

    def _entries(self, payload: Json | list[Json]) -> list[Json]:
        return list(payload.get("content", [])) if isinstance(payload, dict) else []

    def _to_job(self, raw: Json) -> Job | None:
        if not (title := raw.get("name")):
            return None
        location = raw.get("location") or {}
        parts = [location.get("city"), location.get("region"), location.get("country")]
        return _job(
            source=self.name,
            source_id=str(raw.get("id", "")),
            title=str(title),
            company=str((raw.get("company") or {}).get("name") or self.company),
            location=", ".join(p for p in parts if p) or None,
            url=f"https://jobs.smartrecruiters.com/{self.token}/{raw.get('id', '')}",
            # SmartRecruiters keeps the body on a per-posting endpoint; enrichment fills it.
            description=None,
            posted_at=_date(raw.get("releasedDate")),
            department=(raw.get("department") or {}).get("label"),
            remote=RemotePolicy.REMOTE if location.get("remote") else RemotePolicy.UNKNOWN,
            raw=raw,
        )

    async def fetch_description(self, job: Job, client: httpx.AsyncClient) -> str | None:
        try:
            response = await client.get(
                f"https://api.smartrecruiters.com/v1/companies/{self.token}"
                f"/postings/{job.source_id}"
            )
            response.raise_for_status()
            sections = (response.json().get("jobAd") or {}).get("sections") or {}
        except (httpx.HTTPError, ValueError):
            return None
        return "\n\n".join(
            _text(section.get("text"))
            for key in ("companyDescription", "jobDescription", "qualifications", "additionalInformation")
            if (section := sections.get(key))
        ).strip() or None


class Recruitee(AtsBoard):
    name = SourceName.RECRUITEE

    @property
    def url(self) -> str:
        return f"https://{self.token}.recruitee.com/api/offers/"

    def _entries(self, payload: Json | list[Json]) -> list[Json]:
        return list(payload.get("offers", [])) if isinstance(payload, dict) else []

    def _to_job(self, raw: Json) -> Job | None:
        if not (title := raw.get("title")):
            return None
        return _job(
            source=self.name,
            source_id=str(raw.get("id", "")),
            title=str(title),
            company=self.company,
            location=raw.get("location") or raw.get("city"),
            url=str(raw.get("careers_url") or raw.get("careers_apply_url") or ""),
            description=_text(raw.get("description")),
            posted_at=_date(raw.get("published_at")),
            department=raw.get("department"),
            remote=RemotePolicy.REMOTE if raw.get("remote") else RemotePolicy.UNKNOWN,
            raw=raw,
        )


ATS_REGISTRY: dict[str, Callable[[str, str | None], AtsBoard]] = {
    "greenhouse": Greenhouse,
    "lever": Lever,
    "ashby": Ashby,
    "workable": Workable,
    "smartrecruiters": SmartRecruiters,
    "recruitee": Recruitee,
}


def build_board(ats: str, token: str, company: str | None = None) -> AtsBoard:
    try:
        return ATS_REGISTRY[ats.lower()](token, company)
    except KeyError:
        raise ValueError(
            f"unknown ATS {ats!r}; expected one of {', '.join(sorted(ATS_REGISTRY))}"
        ) from None


async def search_boards(
    boards: Iterable[AtsBoard], profile: SearchProfile, client: httpx.AsyncClient
) -> SearchResult:
    """Poll many boards concurrently, tolerating individual failures."""
    board_list = list(boards)
    results = await asyncio.gather(
        *(board.search(profile, client) for board in board_list), return_exceptions=True
    )

    jobs: list[Job] = []
    cost = SourceCost()
    notes: list[str] = []
    partial = False

    for board, result in zip(board_list, results, strict=True):
        if isinstance(result, BaseException):
            partial = True
            notes.append(f"{board.name}:{board.token} raised {type(result).__name__}")
            continue
        jobs.extend(result.jobs)
        cost += result.cost
        notes.extend(result.notes)
        partial = partial or result.partial

    return SearchResult(jobs=tuple(jobs), cost=cost, partial=partial, notes=tuple(notes))


# --------------------------------------------------------------------------------------
# Normalisation helpers
# --------------------------------------------------------------------------------------

_REMOTE_RE = re.compile(r"\bremote\b", re.I)
_HYBRID_RE = re.compile(r"\bhybrid\b", re.I)


def _job(**kwargs: Any) -> Job | None:
    """Build a Job, dropping anything without a usable URL.

    A posting we cannot link to is worthless downstream — the user cannot apply to it, so
    charging them to discover it would be dishonest.
    """
    if not kwargs.get("url"):
        return None
    if kwargs.get("remote", RemotePolicy.UNKNOWN) is RemotePolicy.UNKNOWN:
        kwargs["remote"] = _infer_remote(kwargs.get("location"), kwargs.get("description"))
    return Job(**kwargs)


def _infer_remote(location: str | None, description: str | None) -> RemotePolicy:
    haystack = f"{location or ''} {(description or '')[:600]}"
    if _HYBRID_RE.search(haystack):
        return RemotePolicy.HYBRID
    if _REMOTE_RE.search(haystack):
        return RemotePolicy.REMOTE
    return RemotePolicy.UNKNOWN


def _text(value: object) -> str | None:
    """Flatten an ATS HTML body to readable plain text.

    Block-level tags become newlines and list items become bullets before the tags are
    stripped, because the naive strip runs headings and list items into one another and
    the requirement extractor then reads "RequirementsFive years of experience" as a
    single token.
    """
    if not value or not isinstance(value, str):
        return None
    unescaped = html.unescape(value)
    if "<" not in unescaped:
        return " ".join(unescaped.split()) or None

    tree = HTMLParser(unescaped)
    for node in tree.css("li"):
        node.insert_before("\n• ")
    for tag in ("p", "div", "br", "h1", "h2", "h3", "h4", "ul", "ol", "tr"):
        for node in tree.css(tag):
            node.insert_before("\n")
    text = tree.text(separator=" ")
    collapsed = re.sub(r"[ \t]+", " ", text)
    return re.sub(r"\n{3,}", "\n\n", collapsed).strip() or None


def _date(value: object) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        parsed = date_parser.parse(value)
    except (ValueError, OverflowError):
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)


def _epoch_ms(value: object) -> datetime | None:
    if not isinstance(value, int | float):
        return None
    try:
        return datetime.fromtimestamp(value / 1000, tz=UTC)
    except (ValueError, OSError, OverflowError):
        return None


def _filter(jobs: list[Job], profile: SearchProfile) -> list[Job]:
    """Apply the profile client-side.

    ATS boards return a company's entire posting list with no query support, so all
    filtering happens here. Matching is substring-based over title and description: an
    "ml engineer" query must still find "Machine Learning Engineer, Inference", and
    requiring exact phrase matches would miss most of what the user wants.
    """
    terms = profile.query_terms
    cutoff = _cutoff(profile.posted_within_hours)

    out: list[Job] = []
    for job in jobs:
        haystack = f"{job.title}\n{job.department or ''}\n{job.description or ''}".lower()
        if terms and not any(_matches(term, job.title.lower(), haystack) for term in terms):
            continue
        if profile.locations and not _location_matches(job, profile.locations):
            continue
        if profile.remote and job.remote not in profile.remote:
            continue
        if job.posted_at and cutoff and job.posted_at < cutoff:
            continue
        if profile.excludes(company=job.company, title=job.title, description=job.description):
            continue
        out.append(job)
    return out


def _matches(term: str, title: str, haystack: str) -> bool:
    """A term matches on a whole-phrase hit, or on all its words appearing in the title.

    The second clause is what makes "ml engineer" find "Machine Learning Engineer,
    Inference" — the words are present and separated, which a phrase match would miss.
    Restricted to the title so a job merely *mentioning* the words in its body does not
    match, which would otherwise return most of a company's board for any query.
    """
    if term in haystack:
        return True
    words = term.split()
    return len(words) > 1 and all(word in title for word in words)


def _location_matches(job: Job, locations: tuple[str, ...]) -> bool:
    if job.remote is RemotePolicy.REMOTE:
        return True
    haystack = (job.location or "").lower()
    return any(loc.lower().strip() in haystack for loc in locations if loc.strip())


def _cutoff(hours: int) -> datetime | None:
    from datetime import timedelta

    return datetime.now(UTC) - timedelta(hours=hours)
