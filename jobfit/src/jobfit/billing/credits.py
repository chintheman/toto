"""The credit ledger.

Design rules, each chosen because the obvious alternative fails in a way that costs real
money or real trust:

**Append-only.** There is no mutable balance column. A balance is the sum of the ledger,
so a bug can never leave a user's balance and their history disagreeing — the number
*is* the history. Balances are cached, but only ever as a derived value written in the
same transaction as the row that changed it.

**Integer micro-credits.** Money in floats accumulates error across a sum, and a ledger is
nothing but a sum. All arithmetic is in integers.

**Reserve, then settle.** Work is paid for before it runs and settled after. A crash
between the two leaves a reservation that expires and refunds, so a failed run never
charges the user and a successful one can never be taken for free. Charging afterwards
loses money on every crash; charging upfront without refunds steals on every failure.

**Idempotency keys on every write.** Stripe retries webhooks, clients retry requests, and
users double-click. Every mutation carries a key, and replaying it returns the original
entry instead of creating a second one.
"""

from __future__ import annotations

import hashlib
from collections.abc import Iterable
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Protocol
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field

# One credit is 10,000 micro-credits. Fine enough that a single document generation is a
# whole number of micros at any plausible price, coarse enough to display as a decimal.
MICROS_PER_CREDIT = 10_000


class EntryKind(StrEnum):
    GRANT_FREE = "grant_free"  # the free tier
    GRANT_PURCHASE = "grant_purchase"  # Stripe
    GRANT_PROMO = "grant_promo"
    RESERVE = "reserve"  # negative, provisional
    SETTLE = "settle"  # closes a reservation at its final cost
    REFUND = "refund"  # positive, releases an unused reservation
    EXPIRY = "expiry"
    ADJUSTMENT = "adjustment"  # support action; always carries a reason


class Meter(StrEnum):
    """What is being charged for.

    Two meters because the two costs are unrelated: discovery is vendor spend per record,
    generation is model tokens. Keeping them separate means repricing one never disturbs
    the other, and a reseller can see where their margin actually goes.
    """

    JOB_DISCOVERY = "job_discovery"
    DOCUMENT_GENERATION = "document_generation"


class LedgerEntry(BaseModel):
    """One immutable row. Never updated after write."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    id: UUID = Field(default_factory=uuid4)
    account_id: UUID
    kind: EntryKind
    micro_credits: int = Field(description="Signed. Positive credits the account.")
    meter: Meter | None = None
    idempotency_key: str
    reservation_id: UUID | None = None
    reason: str = ""
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    expires_at: datetime | None = None


class Reservation(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    id: UUID
    account_id: UUID
    meter: Meter
    reserved_micro: int
    expires_at: datetime


class InsufficientCredit(RuntimeError):
    def __init__(self, *, needed: int, available: int) -> None:
        self.needed, self.available = needed, available
        super().__init__(
            f"needs {needed / MICROS_PER_CREDIT:.2f} credits, "
            f"{available / MICROS_PER_CREDIT:.2f} available"
        )


# --------------------------------------------------------------------------------------
# Pricing
# --------------------------------------------------------------------------------------


class PriceCard(BaseModel):
    """What things cost, versioned.

    Versioned rather than edited so that repricing never rewrites history: a ledger entry
    records the card that produced it, and an old invoice still explains itself. Changing
    a price in place would silently restate every past charge.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    version: str

    #: Margin over vendor cost. 3.0 means a search that costs $1 of vendor spend is
    #: billed at $3 — headroom for model spend, infrastructure, and a reseller's markup.
    discovery_markup: float = Field(default=3.0, ge=1.0)

    #: Micro-credits per USD of vendor spend, before markup.
    micro_credits_per_usd: int = Field(default=100 * MICROS_PER_CREDIT)

    #: Flat price for one tailored resume plus cover letter, including the gate's
    #: regeneration retries. Charged per document set, not per model call, so a draft that
    #: needs three attempts to pass verification costs the user exactly the same as one
    #: that passes first time. The user is buying a document that survives the gate.
    document_set_micro: int = Field(default=5 * MICROS_PER_CREDIT)

    #: Granted once per verified account. Sized so the free run is the *whole* product —
    #: one licensed search plus three tailored application sets — with headroom, rather
    #: than a demo that stops before the documents that are the point. Calibrated against
    #: `test_free_grant_covers_a_real_first_run`, which fails if a price change quietly
    #: makes the free tier stop covering its promise.
    free_grant_micro: int = Field(default=25 * MICROS_PER_CREDIT)
    free_grant_valid_days: int = 30

    def discovery_cost(self, vendor_micro_usd: int) -> int:
        """Credits for a search that cost `vendor_micro_usd` of vendor spend."""
        usd = vendor_micro_usd / 1_000_000
        return max(0, round(usd * self.micro_credits_per_usd * self.discovery_markup))


CURRENT_PRICES = PriceCard(version="2026-07")


# --------------------------------------------------------------------------------------
# Storage
# --------------------------------------------------------------------------------------


class LedgerStore(Protocol):
    """Persistence. Implemented over Postgres in production, in memory in tests.

    `append` must be atomic and must enforce uniqueness on
    `(account_id, idempotency_key)`, returning the existing row on conflict rather than
    raising. That single constraint is what makes every operation here safe to retry.
    """

    def append(self, entry: LedgerEntry) -> LedgerEntry: ...

    def entries(self, account_id: UUID) -> Iterable[LedgerEntry]: ...

    def find_by_key(self, account_id: UUID, idempotency_key: str) -> LedgerEntry | None: ...


class InMemoryLedger:
    """Reference implementation. Also the executable specification of `append`."""

    def __init__(self) -> None:
        self._rows: list[LedgerEntry] = []

    def append(self, entry: LedgerEntry) -> LedgerEntry:
        existing = self.find_by_key(entry.account_id, entry.idempotency_key)
        if existing is not None:
            return existing
        self._rows.append(entry)
        return entry

    def entries(self, account_id: UUID) -> list[LedgerEntry]:
        return [r for r in self._rows if r.account_id == account_id]

    def find_by_key(self, account_id: UUID, idempotency_key: str) -> LedgerEntry | None:
        return next(
            (
                r
                for r in self._rows
                if r.account_id == account_id and r.idempotency_key == idempotency_key
            ),
            None,
        )


# --------------------------------------------------------------------------------------
# Operations
# --------------------------------------------------------------------------------------


class CreditAccount:
    """Every credit operation for one account."""

    def __init__(
        self,
        account_id: UUID,
        store: LedgerStore,
        prices: PriceCard = CURRENT_PRICES,
    ) -> None:
        self.account_id = account_id
        self.store = store
        self.prices = prices

    # -- reading ------------------------------------------------------------------

    def balance(self, *, now: datetime | None = None) -> int:
        """Spendable micro-credits: the ledger sum, minus anything expired.

        Expiry is applied at read time rather than by a sweeper job so a balance is
        correct the instant it is read, even if the sweeper is down or lagging.
        """
        moment = now or datetime.now(UTC)
        return sum(
            entry.micro_credits
            for entry in self.store.entries(self.account_id)
            if not (entry.expires_at and entry.expires_at <= moment and entry.micro_credits > 0)
        )

    @property
    def credits(self) -> float:
        return self.balance() / MICROS_PER_CREDIT

    # -- granting -----------------------------------------------------------------

    def grant(
        self,
        micro_credits: int,
        *,
        kind: EntryKind,
        idempotency_key: str,
        reason: str = "",
        valid_days: int | None = None,
    ) -> LedgerEntry:
        if micro_credits <= 0:
            raise ValueError("a grant must be positive")
        expires = (
            datetime.now(UTC) + timedelta(days=valid_days) if valid_days is not None else None
        )
        return self.store.append(
            LedgerEntry(
                account_id=self.account_id,
                kind=kind,
                micro_credits=micro_credits,
                idempotency_key=idempotency_key,
                reason=reason,
                expires_at=expires,
            )
        )

    def grant_free_tier(self) -> LedgerEntry:
        """The one free run. Idempotent by construction.

        The key is derived from the account alone, so calling this twice — through a
        double signup, a support action, or a retry — returns the original grant instead
        of minting a second one. The anti-abuse layer above this (verified email,
        disposable-domain blocklist, device fingerprint) decides *whether* an account
        exists; this guarantees one account can only ever collect once.
        """
        return self.grant(
            self.prices.free_grant_micro,
            kind=EntryKind.GRANT_FREE,
            idempotency_key=f"free:{self.account_id}",
            reason="Free tier: first search and its tailored documents.",
            valid_days=self.prices.free_grant_valid_days,
        )

    def grant_purchase(
        self, micro_credits: int, *, stripe_event_id: str, reason: str = ""
    ) -> LedgerEntry:
        """Mint purchased credits. Only ever called from a verified Stripe webhook.

        The Stripe event id is the idempotency key, which is what makes webhook replay —
        routine, and something Stripe does deliberately — safe.
        """
        return self.grant(
            micro_credits,
            kind=EntryKind.GRANT_PURCHASE,
            idempotency_key=f"stripe:{stripe_event_id}",
            reason=reason or f"Purchase via Stripe event {stripe_event_id}",
        )

    # -- spending -----------------------------------------------------------------

    def reserve(
        self, micro_credits: int, *, meter: Meter, operation_key: str, ttl_minutes: int = 30
    ) -> Reservation:
        """Hold credits before doing the work.

        Raises `InsufficientCredit` *before* anything expensive starts, so a user is never
        part-way through a run they cannot pay for.
        """
        if micro_credits < 0:
            raise ValueError("cannot reserve a negative amount")

        key = _key("reserve", self.account_id, meter, operation_key)
        if (existing := self.store.find_by_key(self.account_id, key)) is not None:
            return Reservation(
                id=existing.reservation_id or existing.id,
                account_id=self.account_id,
                meter=meter,
                reserved_micro=-existing.micro_credits,
                expires_at=existing.expires_at or datetime.now(UTC),
            )

        available = self.balance()
        if available < micro_credits:
            raise InsufficientCredit(needed=micro_credits, available=available)

        reservation_id = uuid4()
        expires = datetime.now(UTC) + timedelta(minutes=ttl_minutes)
        self.store.append(
            LedgerEntry(
                account_id=self.account_id,
                kind=EntryKind.RESERVE,
                micro_credits=-micro_credits,
                meter=meter,
                idempotency_key=key,
                reservation_id=reservation_id,
                reason=f"Reserved for {meter.value}",
                expires_at=expires,
            )
        )
        return Reservation(
            id=reservation_id,
            account_id=self.account_id,
            meter=meter,
            reserved_micro=micro_credits,
            expires_at=expires,
        )

    def settle(self, reservation: Reservation, actual_micro: int) -> LedgerEntry | None:
        """Close a reservation at its true cost, refunding any difference.

        Discovery is reserved on an estimate because the vendor bill is only knowable
        after the fetch. Over-reserving and refunding the remainder is the honest
        direction to be wrong in: the user is never charged more than the work cost, and
        never blocked mid-run by an estimate that came in low.
        """
        if actual_micro < 0:
            raise ValueError("actual cost cannot be negative")

        capped = min(actual_micro, reservation.reserved_micro)
        refund = reservation.reserved_micro - capped

        self.store.append(
            LedgerEntry(
                account_id=self.account_id,
                kind=EntryKind.SETTLE,
                micro_credits=0,
                meter=reservation.meter,
                idempotency_key=_key("settle", self.account_id, reservation.meter, str(reservation.id)),
                reservation_id=reservation.id,
                reason=f"Settled {meter_label(reservation.meter)} at {capped / MICROS_PER_CREDIT:.2f} credits",
            )
        )
        if refund <= 0:
            return None
        return self.store.append(
            LedgerEntry(
                account_id=self.account_id,
                kind=EntryKind.REFUND,
                micro_credits=refund,
                meter=reservation.meter,
                idempotency_key=_key("refund", self.account_id, reservation.meter, str(reservation.id)),
                reservation_id=reservation.id,
                reason="Unused portion of reservation returned",
            )
        )

    def release(self, reservation: Reservation, *, reason: str) -> LedgerEntry:
        """Refund a reservation in full because the work failed.

        Called on any error path. A user who got nothing pays nothing — a run that fails
        after charging is the fastest way to lose someone's trust in a metered product.
        """
        return self.store.append(
            LedgerEntry(
                account_id=self.account_id,
                kind=EntryKind.REFUND,
                micro_credits=reservation.reserved_micro,
                meter=reservation.meter,
                idempotency_key=_key("release", self.account_id, reservation.meter, str(reservation.id)),
                reservation_id=reservation.id,
                reason=reason,
            )
        )


def meter_label(meter: Meter) -> str:
    return {
        Meter.JOB_DISCOVERY: "job discovery",
        Meter.DOCUMENT_GENERATION: "document generation",
    }[meter]


def _key(prefix: str, account_id: UUID, meter: Meter, operation_key: str) -> str:
    digest = hashlib.sha256(f"{account_id}|{meter.value}|{operation_key}".encode()).hexdigest()
    return f"{prefix}:{digest[:40]}"
