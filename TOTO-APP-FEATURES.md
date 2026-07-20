# Toto App — Complete Feature & Content Reference

> **Compiled:** 2026-07-19 · **Repos:** `chintheman/toto` (public), `chintheman/toto-backend` (private)
> **Live site:** [0xsteamboat.me/projects/toto](https://www.0xsteamboat.me/projects/toto)
> **Stack:** React/Vite · SwiftUI · Remotion 4 · Supabase · Hono/Bun · Playwright

---

## 1. Modular Architecture

The Toto project is a **monorepo** of five interconnected modules plus supporting assets:

| Module | Directory | Purpose | Stack |
|--------|-----------|---------|-------|
| **Site** | `site/` | Public-facing research & strategy page | Vite + React 19 + Tailwind CSS 4 |
| **iOS App** | `ios/TotoApp/` | Native mobile experience | SwiftUI + XcodeGen + Supabase |
| **Video** | `video/` | 30-second explainer animation | Remotion 4 + ElevenLabs TTS |
| **API** | `api/draw.ts` | Draw date & jackpot endpoint | Hono on Bun, deployed via Zo Space |
| **CLI Generator** | Skill scripts | Terminal-based number generator | Python |
| **Auto-Fill Script** | Desktop scripts | Playwright browser automation | Node.js + Playwright |

---

## 2. Research Site Features (`site/`)

**Live at:** [0xsteamboat.me/projects/toto](https://www.0xsteamboat.me/projects/toto)
**Design language:** Cream (#FAF7F2) background · Terracotta (#C17A4D) accent · Sage (#7D8C6B) secondary · Brown (#3D3226) text · Beige (#E8E0D5) borders · Playfair Display headings · Inter body · Grain texture overlay

### 2.1 Hero Section
- **Next draw live timer** — auto-calculates next Mon/Thu 6:30pm SGT draw, refreshes every 60s via `useNextDraw()`
- Floating animated lottery balls (#15, #40, #28, #49) with CSS `float` keyframes
- Rotating decorative ring motifs
- **CTAs:** "Run my numbers" (→ calculator) and "Bust the myths first" (→ myths section)
- Scrolled-header behaviour: backdrop blur, sticky nav with calculate button

### 2.2 Data Facts Section ("What the Numbers Actually Say")
- **6 interactive flip cards** — tap to reveal detailed explanations:
  - 🔥 #15 — 175 appearances (most frequent)
  - 🌿 #45 — 119 appearances (least frequent)
  - 🤝 #2–15 — 30 co-appearances (most common pair)
  - 🙈 #27–45 — 5 co-appearances (rarest pair)
  - ♻️ 41.8% — 498 draws with zero carryover
  - 👫 #48–49 — 20× most common consecutive pair
- **Hot vs Cold frequency chart** — horizontal bar comparison of Top 5 vs Bottom 5 numbers
  - Top: #15 (175), #40 (168), #46 (161), #28 (161), #49 (160)
  - Bottom: #25 (135), #29 (132), #42 (127), #33 (126), #45 (119)
  - Animated bars with terracotta/sage gradient
  - Chi-squared disclaimer: "χ² = 38.18 says it's completely normal variance"

### 2.3 Myth-Busting Section ("7 Things People Believe That Are Simply Wrong")
- 7 expandable myth cards with strikethrough titles + verdict chips:
  1. 🎲 "Hot numbers win more" → Pure gambler's fallacy
  2. 🧊 "Cold numbers are 'due'" → The lottery doesn't owe you anything
  3. 📊 "Bigger systems = better odds" → Spread beats concentration
  4. 🔮 "Past patterns predict the future" → Not how probability works
  5. 📅 "Monday and Thursday draws differ" → Noise, not signal
  6. 🎫 "Buying more tickets doesn't help" → More tickets = proportionally better odds
  7. ⚖️ "The system is rigged" → Fair game, unfair maths
- "See all 7 myths" / "Show fewer" toggle
- Animated hover effects on cards

### 2.4 Strategy Accordions ("How to Play Smarter When the Math Allows It")
Three expandable accordion panels with visual accent:

1. **📊 When is it even worth playing?** — EV breakdown with 7-tier horizontal bar chart ($1M: −72% through $8M: +48%), threshold marker at $4.5M where EV turns positive
2. **🔄 Spread your tickets — don't pile into one system** — 12× Sys7 vs 1× Sys9 comparison with backtest results (49% vs 22% prize-winning rate)
3. **🧩 The only peer-reviewed lottery strategy** — Liu, Liu & Teo (2024, Management Science) pairwise overlap optimisation; 100% coverage with mean pairwise overlap of 0.753

### 2.5 Calculator ("Run Your Numbers")
- **Budget selector:** Dropdown ($20/$50/$100/$200/$500)
- **Goal selector:** Three strategies:
  - "Something — any prize works for me" → G3+ Optimised ($100 min)
  - "~$100,000 (Group 2)" → G2 Hunter ($100 min)
  - "The jackpot — I'm going big" → Jackpot or Bust ($54 min)
- **Live results card:** 4-column odds grid (Win anything / Win ~$1K / Win ~$100K / Win jackpot)
- **3 detail panels:** Method breakdown · Min spend · Best-when description
- Budget validation with minimum-spend warning

### 2.6 Playbook ("So What's the Play?")
4 numbered strategy cards:
1. **Only play when jackpot hits $4M+** — EV threshold reasoning
2. **Spread across all 49 numbers** — coverage principle
3. **Keep your tickets independent** — pairwise overlap insight
4. **Pick one goal and own the trade-off** — G3 vs G2 vs G1 trade-off

### 2.7 Footer
- Disclaimer: "The draw is fair. No strategy guarantees a win. Play responsibly."

### 2.8 Scroll-Reveal Animations
- `Section` component with IntersectionObserver — sections fade + translate-up on scroll
- `ScribbleDivider` — hand-drawn SVG separator between sections

---

## 3. iOS App Features (`ios/TotoApp/`)

**Stack:** Native SwiftUI · XcodeGen-generated Xcode project · iOS 17+ · Supabase SDK (`supabase-swift` 2.50.0) · SF Symbols icons
**Design:** System-native (not a site port) — rounded system fonts · `regularMaterial` card backgrounds · 6-colour ball palette cycling through blue/red/green/orange/purple/teal
**Data:** Pulls from Supabase `toto-data` (public, anon RLS) + `toto-recommendation` (private, Edge Functions only)

### 3.1 Onboarding Carousel
- **Mandatory full-screen swipeable carousel** (shown once, gated by `UserDefaults`)
- Replayable later via Learn tab
- **19 fallacy cards** loaded from Supabase, each with:
  - Emoji · Strikethrough myth statement · Green verdict pill · Explanation body · Optional stat callout
- Dark gradient background (black → indigo)
- Skip button available on any page; Done button on final page

### 3.2 Home Tab
- **Next Draw card** — calendar icon, upcoming draw date, estimated jackpot amount, snowball indicator
- Fallback to local schedule estimate when API unavailable
- **Latest Result card** — draw number, date, winning numbers + additional number as lottery ball views, jackpot-won/rolled-over indicator
- **Curated Facts section** — draws fun facts from Supabase for each winning number in the latest draw: "Fun Facts About Today's Numbers"
- Pull-to-refresh via `.refreshable`
- Loading state with `ProgressView`

### 3.3 History Tab
- **Scrollable infinite list** of past draws from Supabase (`toto-data`)
- Each row: draw number, date, miniature ball row (26px balls)
- **Pull-to-refresh navigation**
- **Draw detail view:** full winning numbers, additional number, **prize breakdown** (prize per winner + winner count per group 1–7), link to Singapore Pools source
- Infinite scroll with `loadMoreIfNeeded`
- Error state with `ContentUnavailableView` ("Couldn't load history")

### 3.4 Numbers Library Tab
- **5-column grid** of numbers 1–49, each as a tappable lottery ball (56px)
- **Number detail view** for each tapped number:
  - Large ball display (80px)
  - **Facts section** — loaded from Supabase `facts` repository (980-fact compendium) — headline + body per fact
  - **Recent appearances section** — draws containing this number with date + draw number
- Parallel loading of facts and draw history

### 3.5 Learn Tab
- **Replay onboarding** button (full-screen carousel replay)
- **Fallacy library** — full list of 19 fallacies from Supabase, each with:
  - Emoji + strikethrough myth statement + green verdict label
  - Navigation to detail view with full explanation
- Detail view: dark gradient background, full fallacy card presentation

### 3.6 Calculator Tab
- **Budget stepper** — adjustable $1–$1000 in $7 increments (matching System 7 cost)
- **EV status card:**
  - +EV / -EV indicator with directional arrow icon
  - "Every $1 spent returns about $X on average" at current jackpot
  - Jackpot gap-to-breakeven analysis ("The jackpot would need to grow to ~$X")
  - "Better times to play" guidance
- **Suggested allocation** — System 7 spread recommendation for current budget
- **Odds-by-bet-type table** — per-bet-type (Ordinary/System 7/System 8/System 9) probability of any prize + jackpot probability
- Loading and no-data states

### 3.7 App-Wide Components
- **LotteryBallView** — reusable number circle, 6-colour palette cycle, additional-number variant (grey)
- **CardBackground** modifier — `regularMaterial` rounded-corner container
- **Theme constants** — ball palette, EV colours, corner radius

### 3.8 Core Networking
- **SupabaseClients** — two Supabase project connections (`toto-data` public, `toto-recommendation` private)
- **DrawsRepository** — draw data fetch + prize groups
- **FactsRepository** — number fact queries
- **FallaciesRepository** — onboarding + full list fallacy queries
- **DeviceIdentity** — persistent device ID for future recommendation engine

### 3.9 Data Models
- **Draw** — drawNumber, drawDate, winningNumbers[6], additionalNumber, jackpotWon, sourceUrl, prizeGroups
- **NumberFact** — number, headline, body
- **Fallacy** — mythStatement, explanationBody, verdictLabel, emoji, statCallout
- **BetType** — ordinary, system7, system8, system9 (with id, numbersChosen, cost, displayName)
- **BetOdds** — betType, probabilityAnyPrize, probabilityJackpot, expectedValue
- **PrizeGroup** — groupNumber, prizePerWinner, winnerCount

### 3.10 EV Math Engine (EVMath.swift)
- Hypergeometric probability calculations (verified against Singapore Pools published odds)
- `probabilityAtLeastKMainMatches()` — system bet prize probability
- `probabilityJackpot()` — jackpot hit probability
- `expectedValue()` — EV per dollar for any bet type at given jackpot
- `breakEvenJackpot()` — jackpot threshold for +EV
- Per-group prize probabilities for Ordinary tickets
- PrizeGroupEstimate: G1 (live input), G2 $180K, G3 $1.8K, G4 $450 (typical), G5 $50, G6 $25, G7 $10 (fixed)
- Combinatorics helper (`nCr`)

---

## 4. Explainer Video (`video/`)

**Tool:** Remotion 4 · **Duration:** 30 seconds (900 frames at 30fps) · **Audio:** ElevenLabs TTS (toto-vo.mp3)  
**Same brand colours** as the research site (cream/terracotta/sage/brown palette)

### 4.1 Scene Structure

| Scene | Frames | Time | Content |
|-------|--------|------|---------|
| **Hook** | 0–150 | 0–5s | "The lottery is fair. Your strategy isn't." — large serif typography, slide-in animations |
| **Myths** | 150–330 | 5–11s | Bar chart animation: 5 numbers (15, 40, 46 hottish / 25, 45 cold) with spring-animated bars, "1,000+ draws, no pattern." χ² = 38.18 callout |
| **EV** | 330–510 | 11–17s | "Below $4M? Bad bet." — 7-bar EV chart ($1M to $8M), positive EV threshold line at $4.5M+ |
| **Strategy** | 510–690 | 17–23s | "Spread beats concentration" — 22% (1× Sys9) vs 49% (12 ordinary tickets) comparison |
| **Calculator** | 690–810 | 23–27s | "We built a calculator." — 3 stats (49.3%, 1:969, 1:140K) with strategy-adjusts-automatically tagline |
| **CTA** | 810–900 | 27–30s | ⢕ steamboat branding, "I LEARN · I BUILD · I SHARE" tagline, URL overlay |

### 4.2 Animation System
- Spring-based scaling for hero reveals
- SlideFromLeft/SlideFromRight/SlideUp helpers with opacity interpolation
- Background: cream solid + SVG fractal noise overlay + decorative circular rings
- Per-number bar charts using damper/stiffer spring configs

---

## 5. API (`api/draw.ts`)

**Stack:** Hono on Bun, deployed as Zo Space route at `/api/toto/draw`

- **Returns:** JSON with next draw date, day name, ISO timestamp, current jackpot amount, `drawPassed` boolean, `lastUpdated`
- **Schedule logic:** Monday & Thursday 6:30pm SGT, auto-advances after draw passes
- **Jackpot:** Configurable via `TOTO_JACKPOT` env var; defaults to "$2.5M"
- **Timezone:** All logic in SGT (UTC+8)

**Example response:**
```json
{
  "next": {
    "day": "Thu",
    "date": "Thu 24 Jul 2026",
    "iso": "2026-07-24T10:30:00.000Z"
  },
  "jackpot": "$2.5M",
  "drawPassed": false,
  "lastUpdated": "2026-07-19T13:48:00.000Z"
}
```

---

## 6. CLI Generator (Skill Scripts)

**Located at:** `~/.hermes/skills/analytics/toto-strategy/scripts/generate_numbers.py`

### 6.1 Usage
```bash
python3 generate_numbers.py              # Strategy A: G3+ ($100)
python3 generate_numbers.py 100          # Strategy A: G3+ ($100)
python3 generate_numbers.py 100 g2       # Strategy B: G2 ($100)
python3 generate_numbers.py 54 g1        # Strategy C: G1 ($54)
python3 generate_numbers.py 24           # Small play ($24)
```

### 6.2 Three Strategies

| Metric | A (G3+) | B (G2) | C (G1) |
|--------|:-------:|:------:|:------:|
| **Cost** | $100 | $100 | $54 |
| **Structure** | 12× Sys7 + 16× Ord | 10× Sys7 + 30× Ord | 7× Sys7 + ords |
| **P(any prize)** | **49.3%** | ~42% | ~22% |
| **P(G3 ~$1K)** | **1:969** | ~1:1,250 | ~1:2,800 |
| **P(G2 ~$100K)** | ~1:150K | **~1:100K** | ~1:200K |
| **P(G1 ~$4.5M)** | ~1:140K | ~1:140K | **1:4,656** |
| **Coverage** | 49/49 | 49/49 | 49/49 |

### 6.3 Strategy Details

**G3+ Focus (Strategy A):** Balanced pairwise overlap (Liu/Teo 2024). Maximises small-prize probability across all tiers. 12× Sys7 + 16× Ord = $100 total.

**G2 Focus (Strategy B):** Additional-number-aware clustering. 7 clusters of 7 numbers, ensures additional number coverage. 10× Sys7 + 30× Ord = $100 total.

**G1 Focus (Strategy C):** Jackpot-or-bust. 14-number "lucky pool" — P(all 6 numbers within pool) = C(14,6)/C(49,6) ≈ 1 in 4,656 (~30× better than 100 random tickets). 7× Sys7 + 5× Ord = $54 total.

---

## 7. Playwright Auto-Fill Script

**Located at:** `~/Desktop/toto-auto-fill.js`

- Opens Singapore Pools online Self Pick page via local Chromium
- **Security:** User logs in manually (script waits up to 120 seconds — never sees credentials)
- Auto-fills **100 pre-computed boards** (hardcoded optimised number sets)
- Clicks each number on the interactive number grid
- Reviews bet slip and clicks "Add to Bet Slip"
- Checkout remains manual (legal safety)

---

## 8. Research Foundation

### 8.1 Dataset
- **1,193 draws** analysed (#3000 Oct 27, 2014 – #4192 Jun 18, 2026)
- 7,158 winning numbers + 1,193 additional numbers
- 596 Monday + 597 Thursday draws

### 8.2 Statistical Tests

| Test | Result | Critical (α=0.05) | Verdict |
|------|--------|:-----------------:|:-------:|
| Chi-squared (df=48) | **χ² = 38.18** | 65.17 | ✅ Fair — no machine bias |
| Pairwise co-occurrence variance | Within expected noise | — | No anomalous pairs |
| Positional bias | Sorting artifact only | — | Expected structure |
| Draw-to-draw overlap | 0.76 avg (expected 0.61) | — | Weak, not significant |
| Additional number carryover | 13.0% (expected 12.2%) | — | Not significant |
| Mon vs Thu differences | Within random variance | — | Noise |

### 8.3 Academic Reference
Liu, Changchun; Liu, Ju; Teo, Chung-Piaw (2024). "From Coverage to Pairwise-Overlap: Lottery Number Selection under Budget Constraints." *Management Science* (forthcoming). SSRN: https://ssrn.com/abstract=4756280

---

## 9. Snowball-Aware EV Formula

**Non-snowballed draw:** EV = **−46%** per $1 (SG Pools returns 54% of sales as prizes). Never play.

**Snowballed draw:** `EV = snowball / sales − 0.46`

**Breakeven:** EV > 0 when `snowball > 0.46 × sales`.

| Snowball/Sales | Verdict | EV |
|:--------------:|:-------:|:--:|
| < 0.25 | 🟡 Small play | −20% to −5% |
| 0.25 – 0.46 | ✅ Full portfolio | −5% to breakeven |
| > 0.46 | ✅✅ Max play | **+1% to +30%** |

### Recommendation by Jackpot

| G1 Jackpot | Verdict | Recommended Play |
|:----------:|:-------:|:----------------:|
| < $2M | ❌ Skip | Don't play |
| $2M–$4M | 🟡 Small play | $24 (2× Sys7 + 10× Ord) |
| $4M–$6M | ✅ Full portfolio | $100 Strategy A or B |
| > $6M | ✅✅ Max play | Compute EV per snowball/sales ratio |

---

## 10. How They All Connect

```
┌──────────────┐     ┌──────────────┐     ┌───────────────┐
│  Research    │     │   iOS App    │     │  CLI Generator│
│  Site (Vite) │     │  (SwiftUI)   │     │  (Python)     │
│              │     │              │     │               │
│  ┌────────┐  │     │  ┌────────┐  │     │  generate_    │
│  │Strategy │  │     │  │Onboard-│  │     │  numbers.py   │
│  │Calc     │  │     │  │ing (19)│  │     │               │
│  │Myths (7)│  │     │  │Calc    │  │     │  3 strategies │
│  │EV Chart │  │     │  │History │  │     │  pairwise opt │
│  │Freq     │  │     │  │Numbers │  │     │  budget-aware │
│  └────────┘  │     │  │Learn   │  │     └───────────────┘
└──────────────┘     │  │Home    │  │            │
       │             │  └────────┘  │            │
       │             └──────┬───────┘            │
       │                    │                    │
       ▼                    ▼                    ▼
┌───────────────────────────────────────────────────────┐
│                 Supabase (toto-data)                    │
│  Draws history · Number facts (980) · Fallacies (19)   │
│  Public — anon RLS (read only)                          │
├───────────────────────────────────────────────────────┤
│           Supabase (toto-recommendation)                │
│  Private — Edge Functions only (future paid rec engine) │
└───────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  Playwright  │     │  Explainer    │     │  API         │
│  Auto-Fill   │     │  Video (Remo) │     │  (Hono/Bun)  │
│  100 boards  │     │  30s / 6 scns │     │  Draw info   │
│  Manual auth │     │  ElevenLabsVO │     │  /api/toto/  │
└──────────────┘     └───────────────┘     └──────┬───────┘
                                                   │
                                                   ▼
                                        Zo Space Route
                                    0xsteamboat.zo.space
```

### 10.1 Data Flow
- **Research site & iOS app** both consume Supabase `toto-data` (public) for draw history, facts, and fallacies
- **API** (`/api/toto/draw`) serves live next-draw info independently — consumed by the research site's `useNextDraw()` hook
- **CLI generator** runs locally with the embedded dataset (1,193 draws JSON), no server dependency
- **Auto-fill script** takes CLI-generated number sets and automates Singapore Pools web interface
- **Video** is a self-contained Remotion render — no server dependency post-render
- **Private backend** (separate repo) handles scraping, Supabase migrations, and the proprietary recommendation algorithm (never in public code)

---

## 11. Design System

### 11.1 Site Palette (Editorial/Warm)

| Token | Hex | Usage |
|-------|-----|-------|
| Cream | `#FAF7F2` | Page background |
| Cream Warm | `#F5F0E8` | Card background |
| Brown | `#3D3226` | Body text |
| Brown Light | `#6B5D4F` | Secondary text |
| Terracotta | `#C17A4D` | Primary accent, CTAs |
| Terracotta Light | `#D4895A` | Hover states |
| Sage | `#7D8C6B` | Secondary accent, positive EV |
| Sage Light | `#9AAB8A` | Hover states |
| Beige | `#E8E0D5` | Borders |
| Beige Dark | `#D4C9B8` | Neutral bars |

### 11.2 iOS Palette (System-Native)

| Element | Value |
|---------|-------|
| Ball colours | Blue, red, green, orange, purple, teal (cycling) |
| Card background | `.regularMaterial` |
| +EV | `.green` |
| -EV | `.red` |
| Typography | System font, rounded bold for balls, SF Symbols |

### 11.3 Typography
- **Site headings:** Playfair Display (serif)
- **Site body:** Inter (sans-serif)
- **iOS:** System font throughout

---

## 12. Known Gaps & Roadmap

### 12.1 Current Limitations
- **No live EV calculation on the research site** — EV chart is static reference data, not computed from live jackpot
- **API jackpot is a static env var** — manually updated, not auto-scraped
- **iOS app needs real Supabase credentials** — `SupabaseClients.swift` uses placeholder values
- **iOS is unverified by build** — no Xcode in the build environment
- **App Store submission** — not started
- **Paid recommendation engine** (Phase 3) — not built

### 12.2 Productization Roadmap

| Phase | What | Status |
|:-----:|------|:------:|
| 1 | **Explainability** — each number shows WHY it was picked | 🔜 |
| 2 | **Profile-based** — lucky numbers, birthdates, zodiac, strategy pref | 🔜 |
| 3 | **Gamification** — post-draw analysis, shareable cards | 🔜 |
| 4 | **Productization** — standalone app, Telegram `/toto` command, print output | 🔜 |
| 5 | **iOS App paid rec** — one-time IAP, crowd-avoidance + portfolio-overlap | ❌ Future |

### 12.3 Key Pitfalls
- TOTO is fair (χ² = 38.18). No strategy "beats" the system — only optimises within the math.
- EV depends on total sales, not just advertised G1. Two $4.5M G1 draws can have wildly different EV.
- Hot/cold frequency is descriptive, not predictive.
- G1 concentrated pool is a partial wheel, not a full C(49,6,6) covering.
- The recommendation algorithm must never be in public code.
- Sandbox scrapers have never tested against live singaporepools.com.sg.

---

*End of complete Toto app feature reference. For executable strategy details, see `skill_view(name='toto-strategy')`.*
