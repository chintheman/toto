"""Pipeline tests.

The model calls are stubbed. What is under test is everything wrapped *around* them:
boilerplate stripping, quote verification, retrieval, and the citation validation that
decides whether an unsupported requirement lands as a gap or as an invented match. Those
are the parts that have to hold when the model behaves badly, so the stubs are written to
behave badly on purpose.
"""

from __future__ import annotations

from typing import Any

import pytest
from pydantic import BaseModel

from jobfit.domain.models import (
    Fact,
    FactBase,
    FactKind,
    Job,
    Requirement,
    RequirementKind,
    SourceName,
    Verdict,
)
from jobfit.pipeline.extract import (
    RequirementSet,
    extract_requirements,
    strip_boilerplate,
)
from jobfit.pipeline.score import build_fit_report, render_matrix, shortlist


class StubClient:
    """A `Client` stand-in that returns whatever the test tells it to.

    Records the user prompts it was given so a test can assert on *what the model was
    allowed to see* — the property the grounding design actually rests on.
    """

    def __init__(self, *responses: BaseModel) -> None:
        self._responses = list(responses)
        self.prompts: list[str] = []

    def parse(self, *, schema: type[BaseModel], system: str, user: str, **_: Any) -> BaseModel:
        self.prompts.append(user)
        if not self._responses:
            raise AssertionError("StubClient ran out of responses")
        return self._responses.pop(0)


def make_job(description: str) -> Job:
    return Job(
        source=SourceName.GREENHOUSE,
        source_id="1",
        title="Enterprise Account Executive",
        company="Acme",
        url="https://example.test/1",
        description=description,
    )


# --------------------------------------------------------------------------------------
# Boilerplate stripping
# --------------------------------------------------------------------------------------

POSTING = """\
About us
We are a fast-growing company changing the world of widgets.

Requirements
- 5+ years of enterprise SaaS sales experience
- Experience selling into APAC markets

Benefits
- Private health insurance
- 25 days annual leave
- Equity in a company changing the world

Equal Opportunity
Acme is an equal opportunity employer.
"""


def test_boilerplate_sections_are_dropped() -> None:
    stripped = strip_boilerplate(POSTING)
    assert "annual leave" not in stripped
    assert "equal opportunity employer" not in stripped
    assert "About us" not in stripped


def test_requirements_survive_stripping() -> None:
    stripped = strip_boilerplate(POSTING)
    assert "5+ years of enterprise SaaS sales experience" in stripped
    assert "APAC markets" in stripped


def test_unlabelled_posting_is_left_alone() -> None:
    """Over-stripping loses a must-have, so a posting with no recognised headings passes
    through untouched rather than being cut down to nothing."""
    prose = "About us\nWe sell widgets and need someone with 5 years of sales experience."
    assert strip_boilerplate(prose) == prose.strip()


# --------------------------------------------------------------------------------------
# Quote verification — the extraction's own honesty check
# --------------------------------------------------------------------------------------


class _Req(BaseModel):
    text: str
    kind: RequirementKind
    weight: float
    quote: str


class _Extract(BaseModel):
    requirements: list[_Req]
    revealed_priorities: list[str] = []


def test_requirement_not_in_the_posting_is_discarded() -> None:
    """The failure this prevents: a plausible requirement the posting never made, which
    reaches the user as a confident gap they would act on."""
    client = StubClient(
        _Extract(
            requirements=[
                _Req(
                    text="5+ years enterprise SaaS sales",
                    kind=RequirementKind.MUST,
                    weight=1.0,
                    quote="5+ years of enterprise SaaS sales experience",
                ),
                _Req(
                    text="Bachelor's degree in Computer Science",
                    kind=RequirementKind.MUST,
                    weight=1.0,
                    quote="Bachelor's degree in Computer Science required",
                ),
            ]
        )
    )
    result = extract_requirements(make_job(POSTING), client=client)  # type: ignore[arg-type]

    assert [r.text for r in result.requirements] == ["5+ years enterprise SaaS sales"]
    assert result.unquoted == ("Bachelor's degree in Computer Science",)


def test_quote_matching_ignores_whitespace_and_curly_quotes() -> None:
    job = make_job("Requirements\n- Must own the team's   quarterly number")
    client = StubClient(
        _Extract(
            requirements=[
                _Req(
                    text="Own a quarterly number",
                    kind=RequirementKind.MUST,
                    weight=1.0,
                    quote="own the team’s quarterly number",
                )
            ]
        )
    )
    result = extract_requirements(job, client=client)  # type: ignore[arg-type]
    assert len(result.requirements) == 1
    assert result.unquoted == ()


def test_quotes_from_stripped_sections_still_count() -> None:
    """Stripping is a token optimisation. A requirement quoting a dropped section is
    still quoting the posting, and discarding it would be a false negative."""
    client = StubClient(
        _Extract(
            requirements=[
                _Req(
                    text="Comfortable in a fast-growing company",
                    kind=RequirementKind.SIGNAL,
                    weight=1.0,
                    quote="fast-growing company changing the world of widgets",
                )
            ]
        )
    )
    result = extract_requirements(make_job(POSTING), client=client)  # type: ignore[arg-type]
    assert len(result.requirements) == 1


def test_empty_description_needs_no_model_call() -> None:
    client = StubClient()  # would raise if called
    assert extract_requirements(make_job("  "), client=client).requirements == ()  # type: ignore[arg-type]


# --------------------------------------------------------------------------------------
# Retrieval
# --------------------------------------------------------------------------------------

FACTS = FactBase(
    facts=(
        Fact(
            id="f.acme.renewals",
            employer="Acme",
            title="APAC Enterprise Lead",
            claim="Held 100% logo renewal across the APAC enterprise book",
            evidence="Salesforce renewal report Q2 2023",
            tags=["enterprise-sales", "apac", "retention"],
        ),
        Fact(
            id="f.side.ragbot",
            kind=FactKind.PROJECT,
            claim="Built a retrieval-augmented chatbot over internal documentation",
            evidence="github.com/example/ragbot",
            tags=["llm", "python"],
        ),
        Fact(
            id="f.uni.degree",
            kind=FactKind.EDUCATION,
            institution="National University of Singapore",
            credential="BSc Economics",
            claim="Graduated with a BSc in Economics",
            tags=["education"],
        ),
    )
)


def test_shortlist_ranks_the_relevant_fact_first() -> None:
    requirement = Requirement(
        text="Experience selling into APAC enterprise accounts", kind=RequirementKind.MUST
    )
    assert shortlist(requirement, FACTS.facts)[0].id == "f.acme.renewals"


def test_shortlist_keeps_unrelated_facts_so_bridges_stay_reachable() -> None:
    """A bridge is usually lexically unrelated to the requirement it bridges. Pruning
    zero-overlap facts is how a real transferable strength gets scored as a gap."""
    requirement = Requirement(text="Familiarity with LLM tooling", kind=RequirementKind.NICE)
    assert {f.id for f in shortlist(requirement, FACTS.facts)} == {f.id for f in FACTS.facts}


def test_shortlist_is_stable_across_runs() -> None:
    requirement = Requirement(text="Something unrelated entirely", kind=RequirementKind.NICE)
    assert [f.id for f in shortlist(requirement, FACTS.facts)] == [
        f.id for f in shortlist(requirement, FACTS.facts)
    ]


# --------------------------------------------------------------------------------------
# Judgement and citation validation
# --------------------------------------------------------------------------------------


class _Judged(BaseModel):
    verdict: Verdict
    fact_ids: list[str] = []
    rationale: str = ""


def one_requirement(text: str = "Sell into APAC enterprise accounts") -> RequirementSet:
    return RequirementSet(
        job=make_job(POSTING),
        requirements=(Requirement(text=text, kind=RequirementKind.MUST),),
    )


def test_a_grounded_direct_verdict_is_kept() -> None:
    client = StubClient(
        _Judged(verdict=Verdict.DIRECT, fact_ids=["f.acme.renewals"], rationale="Ran that book.")
    )
    report = build_fit_report(one_requirement(), FACTS, client=client)  # type: ignore[arg-type]
    row = report.coverage[0]
    assert row.verdict is Verdict.DIRECT
    assert row.fact_ids == ("f.acme.renewals",)


def test_citing_a_fact_that_was_never_shown_downgrades_to_a_gap() -> None:
    """The dangerous case: the judge recalls a fact instead of retrieving one. An
    unverifiable citation must not be able to turn a gap into a match."""
    client = StubClient(
        _Judged(verdict=Verdict.DIRECT, fact_ids=["f.invented.role"], rationale="Led a team.")
    )
    report = build_fit_report(one_requirement(), FACTS, client=client, shortlist_size=1)  # type: ignore[arg-type]
    row = report.coverage[0]
    assert row.verdict is Verdict.NONE
    assert row.fact_ids == ()
    assert "not in evidence" in row.rationale


def test_partially_invalid_citations_keep_only_the_real_ones() -> None:
    client = StubClient(
        _Judged(
            verdict=Verdict.DIRECT,
            fact_ids=["f.acme.renewals", "f.invented.role"],
            rationale="Ran the APAC book.",
        )
    )
    report = build_fit_report(one_requirement(), FACTS, client=client)  # type: ignore[arg-type]
    assert report.coverage[0].fact_ids == ("f.acme.renewals",)
    assert report.coverage[0].verdict is Verdict.DIRECT


def test_a_none_verdict_with_citations_is_normalised() -> None:
    """`Coverage` rejects the combination outright, so it has to be resolved before
    construction or the whole report raises on one inconsistent row."""
    client = StubClient(_Judged(verdict=Verdict.NONE, fact_ids=["f.acme.renewals"]))
    report = build_fit_report(one_requirement(), FACTS, client=client)  # type: ignore[arg-type]
    assert report.coverage[0].fact_ids == ()


def test_the_judge_only_sees_its_shortlist() -> None:
    """The property the grounding rests on: a judge cannot cite what it was never given,
    so what it is given has to be bounded."""
    client = StubClient(_Judged(verdict=Verdict.NONE))
    build_fit_report(one_requirement(), FACTS, client=client, shortlist_size=1)  # type: ignore[arg-type]
    prompt = client.prompts[0]
    assert "f.acme.renewals" in prompt
    assert "f.uni.degree" not in prompt


def test_an_empty_fact_base_produces_gaps_not_a_crash() -> None:
    client = StubClient()  # would raise if called
    report = build_fit_report(one_requirement(), FactBase(facts=()), client=client)  # type: ignore[arg-type]
    assert report.coverage[0].verdict is Verdict.NONE
    assert report.score == 0.0


# --------------------------------------------------------------------------------------
# The report the user reads
# --------------------------------------------------------------------------------------


def test_unmet_must_haves_are_called_out() -> None:
    client = StubClient(_Judged(verdict=Verdict.NONE, rationale="No leadership evidence."))
    report = build_fit_report(one_requirement("Manage a quota-carrying team"), FACTS, client=client)  # type: ignore[arg-type]
    assert len(report.blocking_gaps) == 1
    assert "unmet must-have" in render_matrix(report)


@pytest.mark.parametrize(
    ("verdict", "expected"),
    [(Verdict.DIRECT, 100.0), (Verdict.BRIDGE, 50.0), (Verdict.NONE, 0.0)],
)
def test_score_follows_the_matrix(verdict: Verdict, expected: float) -> None:
    """The score is derived from the rows, so it can always be decomposed back into
    them. A model-generated number could not be audited this way."""
    fact_ids = [] if verdict is Verdict.NONE else ["f.acme.renewals"]
    client = StubClient(_Judged(verdict=verdict, fact_ids=fact_ids))
    report = build_fit_report(one_requirement(), FACTS, client=client)  # type: ignore[arg-type]
    assert report.score == expected
