"""Ledger tests.

Billing bugs are the expensive kind — they either lose money quietly or charge people for
nothing and lose their trust loudly. Each test here is one of those two failures.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest

from jobfit.billing.credits import (
    MICROS_PER_CREDIT,
    CreditAccount,
    EntryKind,
    InMemoryLedger,
    InsufficientCredit,
    Meter,
    PriceCard,
)


@pytest.fixture
def account() -> CreditAccount:
    return CreditAccount(uuid4(), InMemoryLedger())


# --------------------------------------------------------------------------------------
# Free tier
# --------------------------------------------------------------------------------------


def test_free_tier_is_granted_once(account: CreditAccount) -> None:
    """A double signup, a support retry and a client retry must all collect once."""
    first = account.grant_free_tier()
    for _ in range(5):
        assert account.grant_free_tier().id == first.id
    assert account.balance() == account.prices.free_grant_micro


def test_free_grant_covers_a_real_first_run(account: CreditAccount) -> None:
    """The free tier has to demonstrate the product, not tease it.

    One search plus three tailored applications is the smallest thing that shows what the
    tool actually does.
    """
    account.grant_free_tier()
    prices = account.prices
    search = prices.discovery_cost(vendor_micro_usd=25 * 750)  # 25 licensed records
    assert account.balance() >= search + 3 * prices.document_set_micro


def test_free_credits_expire(account: CreditAccount) -> None:
    account.grant_free_tier()
    later = datetime.now(UTC) + timedelta(days=account.prices.free_grant_valid_days + 1)
    assert account.balance(now=later) == 0


def test_purchased_credits_do_not_expire(account: CreditAccount) -> None:
    account.grant_purchase(50 * MICROS_PER_CREDIT, stripe_event_id="evt_1")
    far_future = datetime.now(UTC) + timedelta(days=3650)
    assert account.balance(now=far_future) == 50 * MICROS_PER_CREDIT


# --------------------------------------------------------------------------------------
# Stripe
# --------------------------------------------------------------------------------------


def test_webhook_replay_does_not_double_mint(account: CreditAccount) -> None:
    """Stripe redelivers webhooks by design. Replay must be free.

    Without this the same purchase credits the account on every redelivery, which is a
    silent revenue leak that nothing in the product surfaces.
    """
    for _ in range(4):
        account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="evt_abc")
    assert account.balance() == 100 * MICROS_PER_CREDIT


def test_distinct_purchases_both_land(account: CreditAccount) -> None:
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="evt_1")
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="evt_2")
    assert account.balance() == 200 * MICROS_PER_CREDIT


# --------------------------------------------------------------------------------------
# Reserve / settle / release
# --------------------------------------------------------------------------------------


def test_cannot_spend_what_is_not_there(account: CreditAccount) -> None:
    """The refusal must land before any expensive work starts."""
    with pytest.raises(InsufficientCredit) as exc:
        account.reserve(10 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1")
    assert exc.value.available == 0


def test_reservation_is_deducted_immediately(account: CreditAccount) -> None:
    """Otherwise concurrent runs each see the full balance and oversell it."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    account.reserve(30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1")
    assert account.balance() == 70 * MICROS_PER_CREDIT


def test_concurrent_runs_cannot_oversell(account: CreditAccount) -> None:
    account.grant_purchase(50 * MICROS_PER_CREDIT, stripe_event_id="e")
    account.reserve(30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1")
    with pytest.raises(InsufficientCredit):
        account.reserve(30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-2")


def test_retrying_the_same_operation_does_not_charge_twice(account: CreditAccount) -> None:
    """A client retry after a timeout is the same run, not a second one."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    first = account.reserve(30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1")
    again = account.reserve(30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1")
    assert first.id == again.id
    assert account.balance() == 70 * MICROS_PER_CREDIT


def test_settling_below_the_estimate_refunds_the_difference(account: CreditAccount) -> None:
    """Discovery is reserved on an estimate; the vendor bill arrives afterwards."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    reservation = account.reserve(
        30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1"
    )
    account.settle(reservation, actual_micro=12 * MICROS_PER_CREDIT)
    assert account.balance() == 88 * MICROS_PER_CREDIT


def test_a_low_estimate_never_charges_more_than_reserved(account: CreditAccount) -> None:
    """The user agreed to the reservation, so that is the ceiling.

    Billing above it would mean a run could cost more than the balance it was checked
    against, pushing the account negative after the fact.
    """
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    reservation = account.reserve(
        10 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1"
    )
    account.settle(reservation, actual_micro=999 * MICROS_PER_CREDIT)
    assert account.balance() == 90 * MICROS_PER_CREDIT


def test_a_failed_run_costs_nothing(account: CreditAccount) -> None:
    """The fastest way to lose a metered user is to charge for a failure."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    reservation = account.reserve(
        30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1"
    )
    account.release(reservation, reason="every source was unreachable")
    assert account.balance() == 100 * MICROS_PER_CREDIT


def test_release_is_idempotent(account: CreditAccount) -> None:
    """Retryable error paths must not refund twice."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    reservation = account.reserve(
        30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1"
    )
    for _ in range(3):
        account.release(reservation, reason="failed")
    assert account.balance() == 100 * MICROS_PER_CREDIT


def test_settle_is_idempotent(account: CreditAccount) -> None:
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    reservation = account.reserve(
        30 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1"
    )
    for _ in range(3):
        account.settle(reservation, actual_micro=12 * MICROS_PER_CREDIT)
    assert account.balance() == 88 * MICROS_PER_CREDIT


# --------------------------------------------------------------------------------------
# Ledger integrity
# --------------------------------------------------------------------------------------


def test_balance_equals_the_sum_of_history(account: CreditAccount) -> None:
    """The balance *is* the history, so the two can never disagree."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    reservation = account.reserve(
        40 * MICROS_PER_CREDIT, meter=Meter.DOCUMENT_GENERATION, operation_key="doc-1"
    )
    account.settle(reservation, actual_micro=15 * MICROS_PER_CREDIT)

    rows = list(account.store.entries(account.account_id))
    assert account.balance() == sum(r.micro_credits for r in rows)
    assert {r.kind for r in rows} == {
        EntryKind.GRANT_PURCHASE,
        EntryKind.RESERVE,
        EntryKind.SETTLE,
        EntryKind.REFUND,
    }


def test_every_spend_names_its_meter(account: CreditAccount) -> None:
    """A reseller cannot see where margin goes if spend is not attributed."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    account.reserve(10 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="a")
    account.reserve(10 * MICROS_PER_CREDIT, meter=Meter.DOCUMENT_GENERATION, operation_key="b")

    spends = [r for r in account.store.entries(account.account_id) if r.micro_credits < 0]
    assert {r.meter for r in spends} == {Meter.JOB_DISCOVERY, Meter.DOCUMENT_GENERATION}


# --------------------------------------------------------------------------------------
# Pricing
# --------------------------------------------------------------------------------------


def test_discovery_price_tracks_vendor_spend() -> None:
    """Credits are only honest if they follow the money actually spent."""
    prices = PriceCard(version="test", discovery_markup=3.0)
    cheap = prices.discovery_cost(vendor_micro_usd=750)  # 1 record
    dear = prices.discovery_cost(vendor_micro_usd=750 * 100)  # 100 records
    assert dear == pytest.approx(cheap * 100, rel=0.01)


def test_free_sources_cost_the_user_nothing() -> None:
    """ATS boards have no vendor cost, so a run that only hits them should be free."""
    assert PriceCard(version="test").discovery_cost(vendor_micro_usd=0) == 0


def test_repricing_does_not_restate_history(account: CreditAccount) -> None:
    """An old charge must still be explicable under the card that produced it."""
    account.grant_purchase(100 * MICROS_PER_CREDIT, stripe_event_id="e")
    reservation = account.reserve(
        20 * MICROS_PER_CREDIT, meter=Meter.JOB_DISCOVERY, operation_key="run-1"
    )
    account.settle(reservation, actual_micro=20 * MICROS_PER_CREDIT)
    before = account.balance()

    account.prices = PriceCard(version="2027-01", discovery_markup=10.0)
    assert account.balance() == before
