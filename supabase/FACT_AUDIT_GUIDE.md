# TOTO number-facts audit guide

Paste this whole file as the first message to a new Claude session that has
the **Supabase MCP connected** (with write access). It is a standalone brief:
that session needs nothing from the app codebase.

---

You are auditing, fact-checking, and expanding the trivia facts shown in the
TOTO iOS app. The facts live in **Supabase**, project **toto-data**
(ref `vpopzwluqosebiistdmd`), table **`public.number_facts`**. The app reads
this table live at runtime, so every edit you make appears in the app on the
next refresh — no deploy needed. Work carefully; this is user-facing content
in a "trust the data" product.

## The table

`public.number_facts` — ~980 rows, ~20 per number, numbers 1–49.

| Column | Meaning |
|---|---|
| `id` | primary key (identity) |
| `number_value` | 1–49, which number the fact is about |
| `headline` | bold top line on the card |
| `body` | the fact text shown in the box |
| `category` | one of `math`, `culture`, `superstition`, `pop_culture`, `singapore` |
| `priority` | higher shows first; also drives per-visit rotation order |
| `is_active` | `false` hides a fact from the app without deleting it |
| `source` | provenance label shown under the fact (see rules) |
| `last_reviewed` | `timestamptz`, NULL until you review the row; set to `now()` when done |

## Your workflow

1. **Work in batches by number.** Start with unreviewed rows:
   `SELECT * FROM number_facts WHERE last_reviewed IS NULL ORDER BY number_value, priority DESC LIMIT 20;`
2. **Verify each fact.** For every row decide: correct, wrong, or unverifiable.
   - **Correct** → tidy wording if needed, set an accurate `source`, set
     `last_reviewed = now()`.
   - **Wrong** → fix the `body` (and `headline` if needed), or if it can't be
     salvaged set `is_active = false`. Always set `last_reviewed = now()`.
   - **Unverifiable / dubious** → set `is_active = false` and
     `last_reviewed = now()`. Do not invent a citation to keep it.
3. **Never delete rows** — deactivate with `is_active = false` so it's reversible.
4. **Set `last_reviewed = now()` on every row you touch or clear**, so later
   passes can `WHERE last_reviewed IS NULL` and skip finished work.

## `source` rules (honest provenance, not fake citations)

Use one of these labels; do not fabricate specific academic citations.
- `Singapore Pools draw data` — statistical claims about draw history. **You
  can verify these against the real data**: the `draws` table in this same
  project has every draw (`winning_numbers int[]`, `additional_number`,
  `draw_date`). Recompute and correct any number that's off.
- `Mathematics` — provable mathematical facts.
- `Popular culture`, `Folklore & superstition`, `General knowledge` — widely
  known, by domain.
If a claim doesn't fit any of these honestly, it probably shouldn't ship —
deactivate it.

## Known issues to fix as you go

- **Shared headlines:** right now every fact for a given number tends to
  share ONE `headline`. Give each fact its own headline so it stands alone.
- **Duplicates / filler:** deactivate near-duplicate or vague filler facts.
- Aim for a solid ~8–12 genuinely interesting, correct facts per number
  rather than 20 mediocre ones.

## Adding new facts

```sql
INSERT INTO number_facts (number_value, headline, body, category, priority, is_active, source, last_reviewed)
VALUES (7, 'A short standalone headline', 'The fact text shown in the box.',
        'culture', 5, true, 'General knowledge', now());
```
- `priority`: use ~1–10; higher surfaces earlier. Spread values so rotation
  feels varied.
- Keep `body` to ~1–2 sentences; it's shown in a small card.
- Match the copy tone: smart, plain, a little playful, no em-dashes.

## Verifying the statistical facts against real data

Example — how often has number 7 actually appeared?
```sql
SELECT count(*) AS appearances,
       (SELECT count(*) FROM draws) AS total_draws
FROM draws
WHERE 7 = ANY(winning_numbers) OR additional_number = 7;
```
Use queries like this to fact-check any "appeared / most common / overdue"
style claim before trusting it.

## Progress tracking

```sql
SELECT count(*) FILTER (WHERE last_reviewed IS NOT NULL) AS reviewed,
       count(*) FILTER (WHERE last_reviewed IS NULL)     AS remaining,
       count(*) FILTER (WHERE NOT is_active)             AS retired
FROM number_facts;
```

Start with a couple of numbers end-to-end, show me the before/after, and we'll
lock the pattern before doing all 49.
