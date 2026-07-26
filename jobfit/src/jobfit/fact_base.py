"""Loading, validating and auditing the fact base."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

from jobfit.domain.models import Fact, FactBase, Period


class FactBaseError(ValueError):
    """Raised when a fact base is malformed. Always fatal — nothing downstream is safe."""


def load_fact_base(path: str | Path) -> FactBase:
    """Parse and validate a `facts.yaml`.

    Fails loudly and specifically. A fact base that half-loads is worse than one that
    does not load at all: the pipeline would silently generate a resume with a smaller
    evidence set than the user believes they authored, and the gate would then reject
    perfectly true claims.
    """
    path = Path(path)
    if not path.exists():
        raise FactBaseError(
            f"no fact base at {path}. Copy profile/facts.example.yaml to {path} and edit it."
        )

    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise FactBaseError(f"{path} is not valid YAML: {exc}") from exc

    if not isinstance(raw, dict) or "facts" not in raw:
        raise FactBaseError(f"{path} must be a mapping with a top-level 'facts:' key")

    entries = raw["facts"]
    if not isinstance(entries, list) or not entries:
        raise FactBaseError(f"{path}: 'facts' must be a non-empty list")

    facts: list[Fact] = []
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise FactBaseError(f"{path}: fact #{index + 1} is not a mapping")
        facts.append(_build_fact(entry, path, index))

    try:
        return FactBase(facts=tuple(facts))
    except ValueError as exc:
        raise FactBaseError(f"{path}: {exc}") from exc


def _build_fact(entry: dict[str, Any], path: Path, index: int) -> Fact:
    data = dict(entry)
    where = f"{path}: fact #{index + 1} ({data.get('id', 'no id')!r})"

    if isinstance(data.get("period"), str):
        try:
            data["period"] = Period.parse(data["period"])
        except ValueError as exc:
            raise FactBaseError(f"{where}: {exc}") from exc

    for key in ("claim", "evidence"):
        if isinstance(data.get(key), str):
            data[key] = " ".join(data[key].split())

    try:
        return Fact(**data)
    except ValueError as exc:
        raise FactBaseError(f"{where}: {exc}") from exc


def audit(facts: FactBase) -> list[str]:
    """Non-fatal quality warnings about the fact base itself.

    Surfaced by `jobfit facts audit`. These are about whether the *inputs* are strong
    enough to produce a defensible resume — the gate can only protect you from claims
    that contradict your facts, never from facts that were weak to begin with.
    """
    notes: list[str] = []

    for fact in facts.facts:
        if not fact.evidence:
            notes.append(
                f"{fact.id}: no evidence. If you cannot say how you would prove this in "
                "an interview, it does not belong on a resume."
            )
        if fact.numbers and not fact.evidence:
            notes.append(
                f"{fact.id}: contains numbers {sorted(fact.numbers)} but cites no source. "
                "Unsourced metrics are the first thing an interviewer probes."
            )
        if len(fact.claim) > 400:
            notes.append(
                f"{fact.id}: claim is {len(fact.claim)} characters. Long claims bundle "
                "several facts together, which makes citation imprecise. Split it."
            )

    if not any("failure" in f.tags or "failed" in f.claim.lower() for f in facts.facts):
        notes.append(
            "No fact records a failure or a hard decision. maxhire rates honest failure "
            "detail the highest-trust signal available — consider adding one."
        )

    tagged = sum(1 for f in facts.facts if f.tags)
    if tagged < len(facts.facts) * 0.8:
        notes.append(
            f"Only {tagged}/{len(facts.facts)} facts are tagged. Retrieval matches "
            "requirements against tags, so untagged facts are effectively invisible."
        )

    return notes
