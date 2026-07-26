"""LinkedIn sourcing.

LinkedIn is the most valuable job source and the most dangerous one to take directly.
[Proxycurl shut down in July 2025](https://apiserpent.com/blog/best-linkedin-data-apis-2026)
after LinkedIn sued in N.D. Cal., choosing closure over continued litigation. hiQ won on
the CFAA — public data is not "unauthorised access" — but still settled, paid $500k and
destroyed its dataset, and *Meta v. Bright Data* (2024) keeps terms-of-service breach
alive as a contract claim. LinkedIn's official Job Posting API is partner-only and closed
to new applicants, so there is no licensed first-party route.

For a personal script this is a shrug. For a product that takes money it is an
existential, uninsurable liability, so jobfit **buys LinkedIn data rather than taking
it**. Four adapters implement one interface:

    licensed   the vendor's own index; nothing originates from our infrastructure
    serp       Google's index, which lists LinkedIn postings
    guest      LinkedIn's logged-out endpoint, requested by us     [self-host only]
    jobspy     the python-jobspy scraper, requested by us          [self-host only]

`hosted_safe` is False for the last two. `resolve_provider` refuses to build them when
running hosted, so the risky path cannot be enabled by a config typo — it takes an
explicit `allow_unsafe=True` from a self-hoster who has read the README.

The per-record cost this creates is not a tax. It is what makes the credit system honest:
users are charged against real spend, and resellers have a real margin to mark up.
"""

from __future__ import annotations

import os
from abc import abstractmethod
from enum import StrEnum

from jobfit.domain.models import SourceName
from jobfit.sources.base import Source


class LinkedInRoute(StrEnum):
    LICENSED = "licensed"
    SERP = "serp"
    GUEST = "guest"
    JOBSPY = "jobspy"


class LinkedInProvider(Source):
    """Common base for every LinkedIn route."""

    name = SourceName.LINKEDIN
    route: LinkedInRoute

    @property
    @abstractmethod
    def micro_usd_per_record(self) -> int:
        """Vendor cost per returned record, in millionths of a USD.

        Feeds the credit meter directly. Integers rather than floats because the ledger is
        summed rather than stored, and float error accumulates across a sum.
        """


class UnsafeRouteError(RuntimeError):
    """Raised when a scraping route is requested in a hosted deployment."""


def resolve_provider(
    route: str | LinkedInRoute | None = None, *, allow_unsafe: bool = False
) -> LinkedInProvider:
    """Build the configured LinkedIn provider.

    Reads `JOBFIT_LINKEDIN_ROUTE`, defaulting to `licensed` — the safe route is the
    default, and the dangerous ones require deliberate action to reach.
    """
    from jobfit.sources.linkedin import guest, jobspy_source, licensed, serp

    chosen = LinkedInRoute(route or os.getenv("JOBFIT_LINKEDIN_ROUTE", LinkedInRoute.LICENSED))
    builders = {
        LinkedInRoute.LICENSED: licensed.LicensedLinkedIn,
        LinkedInRoute.SERP: serp.SerpLinkedIn,
        LinkedInRoute.GUEST: guest.GuestLinkedIn,
        LinkedInRoute.JOBSPY: jobspy_source.JobSpyLinkedIn,
    }
    provider = builders[chosen]()

    if not provider.hosted_safe and not allow_unsafe:
        raise UnsafeRouteError(
            f"the {chosen.value!r} LinkedIn route requests from LinkedIn using this "
            "server's own IP, which breaches LinkedIn's terms and is the path that ended "
            "Proxycurl. It is available for self-hosting only: pass allow_unsafe=True or "
            "set JOBFIT_ALLOW_UNSAFE_SOURCES=1. Hosted deployments should use "
            "JOBFIT_LINKEDIN_ROUTE=licensed or =serp."
        )
    return provider


def unsafe_allowed() -> bool:
    return os.getenv("JOBFIT_ALLOW_UNSAFE_SOURCES", "").strip().lower() in {"1", "true", "yes"}
