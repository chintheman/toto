"""The model layer.

Two rules shape this module:

**Every call returns a validated Pydantic object.** `messages.parse()` constrains the
response to a schema and validates it, so downstream code never parses free text and a
malformed response fails here rather than three layers later as an attribute error.

**The tailoring and entailment calls see only the facts they were given.** That is the
whole safety property — `verify.check_numbers` can only be honest if the writer never had
access to a number outside its citation set. Context assembly is therefore a function of
an explicit fact list, never of "the whole profile".
"""

from __future__ import annotations

import os
from typing import TypeVar

import anthropic
from pydantic import BaseModel

from jobfit.domain.models import Fact

T = TypeVar("T", bound=BaseModel)

#: Tailoring, angle selection, entailment — judgement-heavy, low volume.
WRITER_MODEL = os.getenv("JOBFIT_MODEL_WRITER", "claude-opus-5")

#: Requirement extraction and description enrichment — high volume, low judgement.
EXTRACTOR_MODEL = os.getenv("JOBFIT_MODEL_EXTRACTOR", "claude-haiku-4-5")


class ModelRefusal(RuntimeError):
    """The model declined the request.

    A refusal arrives as a successful HTTP 200 with `stop_reason == "refusal"`, so code
    that reads `content[0]` without checking breaks on it. Raised here so callers can
    release the user's credit reservation rather than charge for nothing.
    """

    def __init__(self, category: str | None, explanation: str | None) -> None:
        self.category = category
        super().__init__(f"model declined the request ({category or 'unspecified'}): {explanation}")


class Client:
    """Thin wrapper over the Anthropic SDK.

    Deliberately thin — no prompt templating, no chain abstraction. The value is in the
    fact-scoping and the verification gate, not in a framework.
    """

    def __init__(self, api_key: str | None = None, max_retries: int = 3) -> None:
        # The SDK retries 429s and 5xx with exponential backoff itself; three attempts
        # rides out a rate-limit blip without turning a real outage into a long hang.
        self._client = anthropic.Anthropic(
            api_key=api_key or os.getenv("ANTHROPIC_API_KEY"),
            max_retries=max_retries,
        )

    def parse(
        self,
        *,
        schema: type[T],
        system: str,
        user: str,
        model: str = WRITER_MODEL,
        effort: str = "high",
        max_tokens: int = 16000,
        cache_system: bool = True,
    ) -> T:
        """One structured call, validated against `schema`.

        `cache_system` puts the cache breakpoint on the system prompt, which is the
        stable prefix across every job in a run — the per-job content lives in the user
        turn, after the breakpoint. Getting that order wrong is the usual reason caching
        silently does nothing.
        """
        system_block: list[anthropic.types.TextBlockParam] = [{"type": "text", "text": system}]
        if cache_system:
            system_block[0]["cache_control"] = {"type": "ephemeral"}

        response = self._client.messages.parse(
            model=model,
            max_tokens=max_tokens,
            output_config={"effort": effort},
            system=system_block,
            messages=[{"role": "user", "content": user}],
        )

        if response.stop_reason == "refusal":
            details = response.stop_details
            raise ModelRefusal(
                getattr(details, "category", None), getattr(details, "explanation", None)
            )
        if response.parsed_output is None:
            raise RuntimeError(
                f"model returned no parseable {schema.__name__} (stop_reason="
                f"{response.stop_reason}); if this is 'max_tokens', raise max_tokens"
            )
        return response.parsed_output


def render_facts(facts: tuple[Fact, ...]) -> str:
    """Render facts as the *only* evidence a writing or checking call may use.

    Rendered with explicit ids because generated output must cite them, and with the
    immutable fields called out because the model's single hardest constraint is to
    reproduce them character-for-character rather than tidying them up.
    """
    if not facts:
        return "(no facts provided)"

    blocks = []
    for fact in facts:
        lines = [f"[{fact.id}]"]
        for label, value in (
            ("Employer", fact.employer),
            ("Title", fact.title),
            ("Institution", fact.institution),
            ("Credential", fact.credential),
        ):
            if value:
                lines.append(f"  {label} (verbatim, do not alter): {value}")
        if fact.period:
            lines.append(f"  Period (verbatim, do not alter): {fact.period.render()}")
        lines.append(f"  Claim: {fact.claim}")
        if fact.evidence:
            lines.append(f"  Evidence: {fact.evidence}")
        blocks.append("\n".join(lines))
    return "\n\n".join(blocks)


#: Prepended to every writing prompt. The deterministic gate enforces these regardless,
#: but stating them up front means fewer regeneration cycles — and a rejected draft costs
#: the user a retry either way.
GROUNDING_RULES = """\
You may only use information from the facts provided below. Specifically:

- Every number you write must appear in a fact you were given. Do not compute, estimate,
  round, or infer a figure that is not stated. If a fact says "held the book" with no
  size, you may not write a size.
- Employers, job titles, institutions, credentials and dates must be reproduced exactly
  as written. Do not add a seniority prefix, expand an abbreviation, or tidy a title.
- You may select, reorder, compress, and rephrase. You may not add a claim.
- If the evidence does not support what the job asks for, say so plainly. A stated gap is
  more useful to the candidate than an implied strength.
"""
