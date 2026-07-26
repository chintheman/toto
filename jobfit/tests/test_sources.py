"""Source tests against recorded payloads.

This container's network policy blocks every job API (403 at the proxy), and CI should
not depend on third-party uptime regardless. Fixtures are trimmed real response shapes, so
these tests verify normalisation, filtering and failure handling — not that the vendors
are up.
"""

from __future__ import annotations

import httpx
import pytest
import respx

from jobfit.domain.models import Job, RemotePolicy, SourceName
from jobfit.domain.search import JobCategory, SearchProfile, Seniority
from jobfit.sources.ats import Ashby, Greenhouse, Lever, build_board, search_boards
from jobfit.sources.base import dedupe, make_client
from jobfit.sources.linkedin.base import (
    LinkedInRoute,
    UnsafeRouteError,
    resolve_provider,
)

GREENHOUSE_PAYLOAD = {
    "jobs": [
        {
            "id": 4001,
            "title": "Machine Learning Engineer, Inference",
            "absolute_url": "https://boards.greenhouse.io/globex/jobs/4001",
            "location": {"name": "Singapore"},
            "updated_at": "2026-07-20T10:00:00Z",
            "departments": [{"name": "Research"}],
            "content": (
                "&lt;h3&gt;About the role&lt;/h3&gt;&lt;p&gt;Serve models at scale.&lt;/p&gt;"
                "&lt;h3&gt;Requirements&lt;/h3&gt;&lt;ul&gt;&lt;li&gt;Five years of Python&lt;/li&gt;"
                "&lt;li&gt;Experience with GPU inference&lt;/li&gt;&lt;/ul&gt;"
            ),
        },
        {
            "id": 4002,
            "title": "Office Manager",
            "absolute_url": "https://boards.greenhouse.io/globex/jobs/4002",
            "location": {"name": "Singapore"},
            "content": "&lt;p&gt;Run the office.&lt;/p&gt;",
        },
    ]
}

LEVER_PAYLOAD = [
    {
        "id": "abc-123",
        "text": "Senior Backend Engineer",
        "hostedUrl": "https://jobs.lever.co/initech/abc-123",
        "categories": {"location": "Remote", "team": "Platform"},
        "descriptionPlain": "Build the API layer.",
        "createdAt": 1784505600000,
        "lists": [{"text": "Requirements", "content": "&lt;ul&gt;&lt;li&gt;Go&lt;/li&gt;&lt;/ul&gt;"}],
    }
]

ASHBY_PAYLOAD = {
    "jobs": [
        {
            "id": "ash-1",
            "title": "Data Scientist",
            "jobUrl": "https://jobs.ashbyhq.com/umbrella/ash-1",
            "location": "Singapore",
            "organizationName": "Umbrella",
            "descriptionPlain": "Analyse things.",
            "publishedAt": "2026-07-22T00:00:00Z",
            "isRemote": True,
            "department": "Data",
        }
    ]
}


@pytest.fixture
def profile() -> SearchProfile:
    return SearchProfile(
        name="ml roles",
        keywords=("machine learning engineer",),
        locations=("Singapore",),
        posted_within_hours=1440,
    )


# --------------------------------------------------------------------------------------
# Normalisation
# --------------------------------------------------------------------------------------


@respx.mock
async def test_greenhouse_normalises_and_filters(profile: SearchProfile) -> None:
    respx.get(url__startswith="https://boards-api.greenhouse.io").mock(
        return_value=httpx.Response(200, json=GREENHOUSE_PAYLOAD)
    )
    async with make_client() as client:
        result = await Greenhouse("globex", "Globex").search(profile, client)

    assert len(result.jobs) == 1, "the Office Manager posting should not match an ML query"
    job = result.jobs[0]
    assert job.title == "Machine Learning Engineer, Inference"
    assert job.company == "Globex"
    assert job.department == "Research"
    assert result.cost.records == 2, "cost counts everything fetched, not everything kept"


@respx.mock
async def test_html_bodies_are_flattened_without_running_words_together(
    profile: SearchProfile,
) -> None:
    """A naive tag strip yields "RequirementsFive years of Python".

    The requirement extractor then reads that as one token and the resume is written
    against a garbled spec, so block-level structure has to survive flattening.
    """
    respx.get(url__startswith="https://boards-api.greenhouse.io").mock(
        return_value=httpx.Response(200, json=GREENHOUSE_PAYLOAD)
    )
    async with make_client() as client:
        result = await Greenhouse("globex", "Globex").search(profile, client)

    description = result.jobs[0].description or ""
    assert "RequirementsFive" not in description
    assert "Five years of Python" in description
    assert "•" in description, "list items should survive as bullets"


@respx.mock
async def test_lever_merges_lists_into_the_description() -> None:
    respx.get(url__startswith="https://api.lever.co").mock(
        return_value=httpx.Response(200, json=LEVER_PAYLOAD)
    )
    async with make_client() as client:
        result = await Lever("initech", "Initech").search(
            SearchProfile(name="be", keywords=("backend engineer",), posted_within_hours=1440),
            client,
        )

    assert len(result.jobs) == 1
    assert "Build the API layer." in (result.jobs[0].description or "")
    assert "Go" in (result.jobs[0].description or "")
    assert result.jobs[0].remote is RemotePolicy.REMOTE


@respx.mock
async def test_ashby_marks_remote(profile: SearchProfile) -> None:
    respx.get(url__startswith="https://api.ashbyhq.com").mock(
        return_value=httpx.Response(200, json=ASHBY_PAYLOAD)
    )
    async with make_client() as client:
        result = await Ashby("umbrella").search(
            SearchProfile(name="ds", keywords=("data scientist",), posted_within_hours=1440),
            client,
        )
    assert result.jobs[0].remote is RemotePolicy.REMOTE
    assert result.jobs[0].company == "Umbrella"


# --------------------------------------------------------------------------------------
# Failure handling
# --------------------------------------------------------------------------------------


@respx.mock
async def test_a_dead_board_degrades_instead_of_raising(profile: SearchProfile) -> None:
    """A user charged for a ten-board run must not lose it to one board's outage."""
    respx.get(url__startswith="https://boards-api.greenhouse.io").mock(
        return_value=httpx.Response(500)
    )
    respx.get(url__startswith="https://api.ashbyhq.com").mock(
        return_value=httpx.Response(200, json=ASHBY_PAYLOAD)
    )
    async with make_client() as client:
        result = await search_boards(
            [Greenhouse("globex"), Ashby("umbrella")],
            SearchProfile(name="all", keywords=("engineer", "data scientist"), posted_within_hours=1440),
            client,
        )

    assert result.partial
    assert result.jobs, "the healthy board's results still come back"
    assert any("greenhouse" in note for note in result.notes)


@respx.mock
async def test_malformed_json_is_reported_not_raised(profile: SearchProfile) -> None:
    respx.get(url__startswith="https://boards-api.greenhouse.io").mock(
        return_value=httpx.Response(200, text="<html>maintenance</html>")
    )
    async with make_client() as client:
        result = await Greenhouse("globex").search(profile, client)
    assert result.partial and not result.jobs


# --------------------------------------------------------------------------------------
# Dedupe
# --------------------------------------------------------------------------------------


def _job(source: SourceName, url: str, description: str | None) -> Job:
    return Job(
        source=source,
        source_id=url,
        title="Machine Learning Engineer",
        company="Globex Inc.",
        location="Singapore",
        url=url,
        description=description,
    )


def test_dedupe_keeps_the_richest_copy() -> None:
    """One opening, three boards. The full description produces a better resume."""
    jobs = [
        _job(SourceName.LINKEDIN, "https://linkedin.com/jobs/1", "Short blurb."),
        _job(SourceName.GREENHOUSE, "https://boards.greenhouse.io/globex/jobs/1", "Full " * 100),
        _job(SourceName.JOBSPY, "https://indeed.com/1", None),
    ]
    deduped = dedupe(jobs)
    assert len(deduped) == 1
    assert deduped[0].source is SourceName.GREENHOUSE


def test_dedupe_ignores_company_suffix_and_case() -> None:
    a = _job(SourceName.LINKEDIN, "https://a", "x")
    b = a.model_copy(update={"company": "globex", "url": "https://b"})
    assert len(dedupe([a, b])) == 1


def test_different_roles_are_not_merged() -> None:
    a = _job(SourceName.GREENHOUSE, "https://a", "x")
    b = a.model_copy(update={"title": "Data Scientist", "url": "https://b"})
    assert len(dedupe([a, b])) == 2


# --------------------------------------------------------------------------------------
# Search profiles
# --------------------------------------------------------------------------------------


def test_categories_expand_to_query_terms() -> None:
    profile = SearchProfile(
        name="ml", categories=(JobCategory.DATA_AND_ML,), seniority=(Seniority.SENIOR,)
    )
    assert "machine learning engineer" in profile.query_terms


def test_user_keywords_come_before_category_expansions() -> None:
    """When a capped run cannot issue every term, the user's own words go first."""
    profile = SearchProfile(
        name="mixed", keywords=("inference engineer",), categories=(JobCategory.DATA_AND_ML,)
    )
    assert profile.query_terms[0] == "inference engineer"


def test_a_profile_must_say_what_it_wants() -> None:
    with pytest.raises(ValueError, match="keyword or category"):
        SearchProfile(name="empty")


def test_exclusions_match_substrings_of_company_names() -> None:
    profile = SearchProfile(name="x", keywords=("engineer",), exclude_companies=("acme",))
    assert profile.excludes(company="Acme Systems Pte Ltd", title="Engineer")
    assert not profile.excludes(company="Globex", title="Engineer")


def test_keyword_exclusions_match_whole_words_only() -> None:
    """"crypto" must not exclude "cryptography"."""
    profile = SearchProfile(name="x", keywords=("engineer",), exclude_keywords=("crypto",))
    assert profile.excludes(company="A", title="Crypto Engineer")
    assert not profile.excludes(company="A", title="Cryptography Engineer")


# --------------------------------------------------------------------------------------
# The LinkedIn safety gate
# --------------------------------------------------------------------------------------


def test_hosted_default_is_the_licensed_route() -> None:
    assert resolve_provider().route is LinkedInRoute.LICENSED


@pytest.mark.parametrize("route", [LinkedInRoute.GUEST, LinkedInRoute.JOBSPY])
def test_scraping_routes_refuse_to_build_without_explicit_opt_in(route: LinkedInRoute) -> None:
    """The route that ended Proxycurl must not be reachable by a config typo."""
    with pytest.raises(UnsafeRouteError, match="self-hosting only"):
        resolve_provider(route)


@pytest.mark.parametrize("route", [LinkedInRoute.GUEST, LinkedInRoute.JOBSPY])
def test_self_hosters_can_opt_in(route: LinkedInRoute) -> None:
    provider = resolve_provider(route, allow_unsafe=True)
    assert provider.hosted_safe is False


def test_safe_routes_report_a_per_record_cost() -> None:
    """Credits are only honest if they track real vendor spend."""
    assert resolve_provider(LinkedInRoute.LICENSED).micro_usd_per_record > 0


async def test_unconfigured_licensed_route_degrades_with_a_clear_note(
    profile: SearchProfile,
) -> None:
    """A missing key must not look like "there are no LinkedIn jobs"."""
    from jobfit.sources.linkedin.licensed import LicensedLinkedIn

    async with make_client() as client:
        result = await LicensedLinkedIn(api_key="").search(profile, client)
    assert result.partial and not result.jobs
    assert any("BRIGHTDATA_API_KEY" in note for note in result.notes)


def test_build_board_rejects_unknown_ats() -> None:
    with pytest.raises(ValueError, match="unknown ATS"):
        build_board("taleo", "acme")
