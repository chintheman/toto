# TOTO Strategy Analyser

Singapore TOTO strategy tool built on 1,000+ draws of real data.

**Live:** [0xsteamboat.me/projects/toto](https://www.0xsteamboat.me/projects/toto) · **Repo:** [github.com/chintheman/toto](https://github.com/chintheman/toto)

## What's Here

| Directory | What |
|-----------|------|
| `shared/` | Single source of truth for the site, video and API — draw schedule, palette, EV maths, stats data, ticket generator, editorial content |
| `site/` | Standalone React + Vite + Tailwind site — TOTO page with strategy calculator, myth-busting, frequency analysis, and EV calculator |
| `video/` | Remotion project — 30-second explainer video with ElevenLabs voice-over |
| `api/` | Draw date API (Zo Space compatible) — serves next draw date + jackpot amount |
| `ios/` | Native SwiftUI iOS app (Supabase-backed) — see `ios/DEPLOY_IOS.md` |
| `images/` | Source graphics and assets |

## Quick Start

### Site

```bash
cd site
bun install
bun run dev        # dev server
bun run typecheck  # tsc --noEmit over site/ and shared/
bun run test       # shared/ unit tests (EV maths, ticket generator)
bun run build      # typecheck + production build → dist/
```

### Video

```bash
cd video
bun install
bun run render   # → output.mp4
```

### API

The draw info API runs as a Zo Space route at `/api/toto/draw`. The standalone source is in `api/draw.ts` — deploy it as a Hono route on any Bun server.

```bash
curl https://0xsteamboat.zo.space/api/toto/draw
```

Set `TOTO_JACKPOT` env var to override the default jackpot. It must match `$<number>M` (e.g. `$4.5M`); anything else is rejected and the API falls back to the shared placeholder with `jackpotIsLive: false`.

## Features

- **Live draw timer** — auto-calculates next Mon/Thu 6:30pm SGT draw, refreshes every 60s
- **Strategy calculator** — pick your budget and goal, get an optimised ticket strategy
- **Myth-busting** — 7 common lottery myths tested against real data
- **EV analysis** — expected value by jackpot size ($1M–$10M), derived from exact 6/49 combinatorics in `shared/evMath.ts`. Break-even is ~$9.23M, so every realistic jackpot is a losing bet
- **Hot/Cold frequency** — top 5 and bottom 5 numbers after 1,000+ draws
- **Explainer video** — 30-second Remotion video with ElevenLabs voice-over

## Data Source

All analysis is based on **1,193 Singapore TOTO draws** (draw 3000 to 4192, Oct 2014 to Jun 2026): 596 Monday, 563 Thursday and 34 Friday special draws. Chi-squared test: 38.18 — well below the significance threshold of 65.17. The game is fair.

The raw history lives in `shared/data/draws.json` and every published figure is derived from it. The site imports the generated `shared/drawStatsSummary.ts` rather than the raw history, so the browser doesn't download 1,193 draws for five table rows. Regenerate after a data refresh:

```bash
bun run shared/scripts/generateStatsSummary.ts
```

`shared/drawStats.test.ts` fails if the committed summary drifts from the dataset.

> Earlier copy quoted the dataset as 1,159 draws — that is the Monday + Thursday subtotal and silently drops the 34 Friday draws. The percentages were always computed over the full 1,193 and were correct; only the stated denominator was wrong.

## Tech Stack

- **Site:** React 19, Vite, Tailwind CSS 4, lucide-react
- **Video:** Remotion 4, React, ElevenLabs TTS
- **API:** Hono on Bun, Zo Space
