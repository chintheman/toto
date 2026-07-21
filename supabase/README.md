# Supabase backend (project: toto-data / vpopzwluqosebiistdmd)

The iOS app reads everything from this project via the publishable key
(SELECT-only under RLS). Draw data is kept fresh by a self-contained
Postgres scraper — no external server or edge function.

## Live draw scraper

**`public.scrape_toto()`** — a `SECURITY DEFINER` plpgsql function that,
on each run:

1. Fetches Singapore Pools' pre-generated draw-list fragment
   (`.../DataFileArchive/Lottery/Output/toto_result_draw_list_en.html`) and
   reads the latest **finalized** draw number (`winningSharesUploaded='True'`).
2. For each draw newer than what we have, fetches that draw's results page
   (`toto_results.aspx?sppl=base64("DrawNumber=N")`), parses the winning
   numbers, additional number, jackpot pool, rollover status, and the full
   Group 1–7 prize table, and upserts `draws` + `draw_prize_groups`.
   (Backfill is capped at 25 draws per run as a safety limit.)
3. Fetches the next-draw estimate fragment
   (`toto_next_draw_estimate_en.html`) and refreshes the single
   `upcoming_draw` row (date + estimated jackpot).

Fetching uses the `http` Postgres extension (the database's own network
egress reaches singaporepools.com.sg directly).

## Schedule

`pg_cron` job **`scrape-toto`** runs `SELECT public.scrape_toto();` every
5 minutes (`*/5 * * * *`, UTC). Because it polls continuously rather than
on a fixed Mon/Thu assumption, it picks up special-day and off-time draws
within ~5 minutes of Singapore Pools finalizing the winning shares.

Check status / run manually:

```sql
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'scrape-toto';
SELECT public.scrape_toto();                       -- run now, returns a summary
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
```

Notes:
- A draw only appears once its prize shares are published (the
  `winningSharesUploaded='True'` gate), so numbers + prizes land together.
- The function is idempotent: re-running re-parses and upserts, so a bad
  parse self-heals on the next successful run.

## Other objects
- `fallacies.category` groups the Learn myths into curiosity statements.
- `number_facts.source` records provenance (data-derived vs editorial).
- `premium_interest` stores Picks email sign-ups (anon INSERT only).
