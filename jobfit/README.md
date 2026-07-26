# jobfit

Finds jobs you want, and writes a resume and cover letter for each one that you can
defend in an interview without flinching.

The second half is the hard part. Every tool in this space enforces honesty with a prompt
instruction — *"do not fabricate", "preserve resume facts"*. A prompt is a request, not a
guarantee, and nothing downstream checks whether it was honoured. jobfit checks.

## The idea

Two words define the product: **honest** and **creative**. They pull against each other —
unconstrained creativity is what invents the metric that collapses under questioning.

The resolution is to split them:

- **Facts are immutable and cited.** A fact base you author by hand is the only source of
  truth. The writer may select, order, compress and rephrase facts. It may never add one.
  Every generated bullet permanently records the fact ids it came from.
- **Creativity operates on framing.** Which through-line to lead with, which evidence
  answers which requirement, how to bridge a gap honestly instead of implying experience
  you do not have. That is where the value is, and none of it requires inventing anything.

A `ResumeBullet` with no citations is not rejected at review time — it is unrepresentable
in the type system.

## The gate

Six checks run on every draft. **Four need no model at all**, which is the point: a gate
that depends on a model to catch a model's mistakes inherits the failure mode it exists to
catch.

| # | Check | Kind | What it stops |
|---|---|---|---|
| 1 | Immutables | deterministic | `Senior APAC Lead` when the fact says `APAC Lead` — a promotion you never had, one word from the truth |
| 2 | Number provenance | deterministic | `grew the book 40%` when no fact contains a 40 |
| 3 | Style | deterministic | Banned phrases, sentence-initial `I`, em-dash flood |
| 4 | ATS parse-back | deterministic | A beautiful PDF that a parser reads as gibberish |
| 5 | Claim entailment | model | Claims that overstate the facts that licensed them |
| 6 | Anti-slop rubric | model | Prose that is true but says nothing |

Any fatal finding fails the draft and triggers regeneration. After the retry budget is
spent the failure is surfaced, never shipped.

Number licensing is **per citation**, not global — a bullet may only use numbers from the
facts *it* cites, so a metric cannot launder itself from one job into another.

The dangerous failure is not an obviously invented claim. It is a *mutation*: plausible,
one word from the truth, invisible in a polished PDF, and indefensible in a reference
check. Check 1 targets mutations specifically, by similarity rather than by exact match.

## Status

Working: domain model, fact base loader and auditor, verification gate (checks 1–3), test
suite. In progress: sources, scoring, tailoring, rendering, credits.

Run the tests that decide whether the honesty claim is true:

```bash
uv venv && uv pip install -e ".[dev]"
uv run pytest tests/test_verify.py -v
```

## Sourcing and the law

LinkedIn is the most valuable source and the most dangerous one to take directly.
[Proxycurl shut down in July 2025](https://apiserpent.com/blog/best-linkedin-data-apis-2026)
after LinkedIn sued rather than keep litigating. hiQ won on the CFAA but settled, paid
$500k and destroyed its data. LinkedIn's official Job Posting API is partner-only and
**closed to new applicants**.

So jobfit does not scrape LinkedIn from its own servers. `LinkedInProvider` is an
interface with four adapters:

| Adapter | Who requests from LinkedIn | Use |
|---|---|---|
| `licensed` | The provider's own index (Bright Data, Coresignal) | **Hosted default.** Nothing originates from our infrastructure |
| `serp` | Google's index, which lists LinkedIn postings | Hosted fallback, widens coverage |
| `guest` | You | Self-host only, off by default, explicit opt-in |
| `jobspy` | You | Self-host only, opt-in |

Per-record data cost is real COGS, which is what makes the credits system honest and
gives resellers a margin to mark up. Swapping providers is one environment variable, so no
vendor can hold the product hostage.

Public ATS endpoints (Greenhouse, Lever, Ashby, Workable, SmartRecruiters, Recruitee) are
published by the companies themselves and carry none of this risk. MyCareersFuture is a
Singapore government API. Both are first-class sources.

## Layout

```
src/jobfit/
  domain/models.py     Job, Fact, Requirement, Coverage, TailoredResume
  fact_base.py         load, validate, audit
  verify.py            the gate
  sources/             linkedin/{licensed,serp,guest,jobspy}, ats, mycareersfuture
  pipeline/            enrich, extract, score
  tailor/              angles, resume, cover_letter
  render/              reportlab PDF, ATS parse-back
  billing/             append-only credit ledger, meters, Stripe
```

This directory is self-contained and carries its own `pyproject.toml`, licence and
history, so it lifts into a standalone repository with `git subtree split -P jobfit`.

## Licence

MIT.
