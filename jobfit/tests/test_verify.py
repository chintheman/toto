"""The tests that decide whether this product's central claim is true.

Everything else here is plumbing. If these pass, "honestly" is an enforced property; if
they fail, it is marketing copy. Each test is written as an attack: take a draft that a
competent model would plausibly produce, and check the gate stops it.
"""

from __future__ import annotations

import pytest

from jobfit.domain.models import (
    CoverLetter,
    Fact,
    FactBase,
    Job,
    Period,
    ResumeBullet,
    ResumeSection,
    SourceName,
    TailoredResume,
)
from jobfit.verify import (
    Severity,
    check_immutables,
    check_numbers,
    check_style,
    verify_cover_letter,
    verify_resume,
)


@pytest.fixture
def facts() -> FactBase:
    return FactBase(
        facts=(
            Fact(
                id="f.acme.renewals",
                employer="Acme Systems",
                title="APAC Enterprise Lead",
                period=Period.parse("2021-01/2023-06"),
                claim="Held 100% logo renewal across the APAC enterprise book, 14 accounts.",
                evidence="Salesforce renewal report Q2 2023.",
                tags=("retention",),
            ),
            Fact(
                id="f.northwind.queue",
                employer="Northwind",
                title="Customer Operations Manager",
                period=Period.parse("2018-03/2020-12"),
                claim="Took support first response from 3 days to same day.",
                evidence="Zendesk dashboards.",
                tags=("operations",),
            ),
        )
    )


@pytest.fixture
def job() -> Job:
    return Job(
        source=SourceName.GREENHOUSE,
        source_id="1",
        title="Enterprise Account Director",
        company="Globex",
        location="Singapore",
        url="https://boards.greenhouse.io/globex/jobs/1",
        description="Enterprise sales role.",
    )


# --------------------------------------------------------------------------------------
# Number provenance — the highest-value check
# --------------------------------------------------------------------------------------


def test_invented_metric_is_rejected(facts: FactBase) -> None:
    """The canonical failure: a model "improves" a bullet by adding a number.

    Nothing in the fact base says 40%. A human reviewing a polished PDF will not catch
    this, which is exactly why it must be caught mechanically.
    """
    result = check_numbers(
        "Grew the APAC book 40% while holding 100% logo renewal.",
        facts,
        ["f.acme.renewals"],
    )
    assert not result.passed
    assert any("'40'" in f.message for f in result.fatal)


def test_licensed_metric_passes(facts: FactBase) -> None:
    result = check_numbers(
        "Held 100% logo renewal across 14 enterprise accounts.", facts, ["f.acme.renewals"]
    )
    assert result.passed, result.report()


def test_numbers_cannot_be_borrowed_from_an_uncited_fact(facts: FactBase) -> None:
    """Licensing is per citation, not global.

    A bullet about Northwind may not reach across the document and borrow Acme's metrics.
    Without this, any number anywhere in the fact base would launder into any bullet.
    """
    result = check_numbers("Held 100% renewal at Northwind.", facts, ["f.northwind.queue"])
    assert not result.passed
    assert any("'100'" in f.message for f in result.fatal)


def test_dates_implied_by_a_period_are_licensed(facts: FactBase) -> None:
    """A rendered date range introduces years that appear in no claim string.

    Arithmetic on authored data is not invention, so "Jan 2021 - Jun 2023" and the "2"
    in "over 2 years" must both pass or the gate would reject every correct resume.
    """
    result = check_numbers(
        "Jan 2021 - Jun 2023: over 2 years leading the region.", facts, ["f.acme.renewals"]
    )
    assert result.passed, result.report()


def test_number_formatting_is_not_treated_as_fabrication(facts: FactBase) -> None:
    extra = FactBase(
        facts=(
            Fact(
                id="f.x.book",
                employer="Acme Systems",
                claim="Carried a book of 1200 seats.",
                evidence="CRM export.",
            ),
        )
    )
    assert check_numbers("Carried 1,200 seats.", extra, ["f.x.book"]).passed


def test_uncited_bullet_is_impossible_to_construct() -> None:
    """The type system, not the gate, forbids uncited prose.

    A bullet with no `derived_from` could never be number-checked, so it must not be
    representable at all.
    """
    with pytest.raises(ValueError):
        ResumeBullet(text="Did something impressive.", derived_from=())


# --------------------------------------------------------------------------------------
# Immutables — mutation is the dangerous case
# --------------------------------------------------------------------------------------


def test_inflated_title_is_fatal(facts: FactBase, job: Job) -> None:
    """"Senior APAC Enterprise Lead" is a promotion the candidate never had.

    It is one word from the truth, entirely plausible, and indefensible when a reference
    check reaches the employer.
    """
    result = check_immutables("Senior APAC Enterprise Lead at Acme Systems.", facts, job)
    assert not result.passed
    assert any(f.check == "immutables" for f in result.fatal)


def test_misspelled_employer_is_fatal(facts: FactBase, job: Job) -> None:
    result = check_immutables("Led the region at Acme Systemss.", facts, job)
    assert not result.passed


def test_exact_credentials_pass(facts: FactBase, job: Job) -> None:
    result = check_immutables(
        "APAC Enterprise Lead at Acme Systems, then Customer Operations Manager at Northwind.",
        facts,
        job,
    )
    assert result.passed, result.report()


def test_contracting_an_employer_name_is_allowed(facts: FactBase, job: Job) -> None:
    """Writing "Acme" for "Acme Systems" is a contraction, not an invention."""
    assert check_immutables("Joined Acme to run the region.", facts, job).passed


def test_the_target_company_is_allowed(facts: FactBase, job: Job) -> None:
    """Cover letters must be able to name the company being applied to."""
    assert check_immutables("Globex is solving the problem I care about.", facts, job).passed


def test_sentence_opening_word_is_not_absorbed_into_a_credential(
    facts: FactBase, job: Job
) -> None:
    """Regression: "At Acme Systems…" must not be read as the credential "At Acme Systems".

    That phrase matches nothing authored while closely resembling "Acme Systems", so a
    naive extractor reports an honest sentence as fabrication. A gate that cries wolf on
    true statements gets switched off, which costs more than the errors it catches.
    """
    assert check_immutables("At Acme Systems the book held.", facts, job).passed


def test_sentence_opening_does_not_mask_a_real_mutation(facts: FactBase, job: Job) -> None:
    """The same bug in the other direction: the inflated title must still be caught."""
    result = check_immutables("As Senior APAC Enterprise Lead, closed the year.", facts, job)
    assert not result.passed
    assert any("Senior APAC Enterprise Lead" in f.excerpt for f in result.fatal)


def test_sentence_initial_fabricated_employer_is_still_checked(
    facts: FactBase, job: Job
) -> None:
    """A one-word employer opening a sentence must not get a free pass."""
    result = check_immutables("Initech taught me the enterprise motion.", facts, job)
    assert any(f.excerpt == "Initech" for f in result.findings)


def test_unrelated_proper_noun_warns_but_does_not_block(facts: FactBase, job: Job) -> None:
    result = check_immutables("Rolled the process out across Jakarta.", facts, job)
    assert result.passed
    assert any(f.severity is Severity.WARN for f in result.findings)


# --------------------------------------------------------------------------------------
# Style
# --------------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "phrase",
    ["proven track record", "spearheaded", "passionate about", "responsible for"],
)
def test_banned_phrases_are_fatal(phrase: str) -> None:
    result = check_style(f"A {phrase} of delivery in enterprise software.")
    assert not result.passed


def test_clean_prose_passes() -> None:
    assert check_style("Rebuilt regional pricing after finding the model lost money.").passed


def test_em_dash_flood_is_flagged() -> None:
    text = "Ran the region — held renewals — rebuilt pricing — and left it working."
    result = check_style(text)
    assert any(f.check == "style" and "em-dash" in f.message for f in result.warnings)


# --------------------------------------------------------------------------------------
# End to end
# --------------------------------------------------------------------------------------


def _resume(bullet: str, cites: tuple[str, ...]) -> TailoredResume:
    return TailoredResume(
        angle="Operator who fixes the commercial model, not just the pipeline.",
        summary="Enterprise operator across APAC.",
        sections=(
            ResumeSection(
                heading="Experience",
                bullets=(ResumeBullet(text=bullet, derived_from=cites),),
            ),
        ),
    )


def test_honest_resume_passes_the_full_gate(facts: FactBase, job: Job) -> None:
    resume = _resume(
        "Held 100% logo renewal across 14 enterprise accounts through two budget freezes.",
        ("f.acme.renewals",),
    )
    assert verify_resume(resume, facts, job).passed, verify_resume(resume, facts, job).report()


def test_embellished_resume_fails_the_full_gate(facts: FactBase, job: Job) -> None:
    """One draft, three independent lies. Each must be caught by a different check."""
    resume = _resume(
        "As Senior APAC Enterprise Lead, spearheaded 40% growth across 14 accounts.",
        ("f.acme.renewals",),
    )
    result = verify_resume(resume, facts, job)
    caught = {f.check for f in result.fatal}
    assert {"immutables", "numbers", "style"} <= caught, result.report()


def test_cover_letter_gate(facts: FactBase, job: Job) -> None:
    letter = CoverLetter(
        angle="Fixes the commercial model.",
        paragraphs=(
            "Globex is hiring for the enterprise motion I spent two years rebuilding.",
            "At Acme Systems the renewal book held at 100% through two budget freezes.",
        ),
        derived_from=("f.acme.renewals",),
    )
    assert verify_cover_letter(letter, facts, job).passed


def test_cover_letter_with_invented_scale_fails(facts: FactBase, job: Job) -> None:
    letter = CoverLetter(
        angle="Fixes the commercial model.",
        paragraphs=(
            "Globex is hiring for the motion I know.",
            "At Acme Systems I carried a $30M book across 14 accounts.",
        ),
        derived_from=("f.acme.renewals",),
    )
    result = verify_cover_letter(letter, facts, job)
    assert not result.passed
    assert any("'30'" in f.message for f in result.fatal)
