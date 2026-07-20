# TotoApp — Design Changes Handoff

> **Created:** 2026-07-20 · **Source:** Interactive mocks in `TotoApp Refinements.dc.html`
> **Status:** Active — implement from this spec

Source of truth: the interactive mocks in the "App review request" canvas (`TotoApp Refinements.dc.html`). This doc translates them into implementation-level specs for the iOS app.

---

## 1. Tab structure (4 tabs, was 5)

`Home · History · Calculator · Picks` (+ optional 5th `Learn`, see §6)

- **Numbers merges into History** as a segmented control: `Draws | Numbers`.
- **Learn** either becomes the 5th tab (if Picks ships) or folds into Home.

## 2. Home

- **Stale-while-revalidate**: persist last successful `Draw` + `UpcomingDraw` JSON to disk; on launch render cached data immediately with a "cached Xh ago" pill, refresh in background.
- **Error banner** (amber): "Couldn't refresh — showing results from X hours ago." + Retry button. Never a blank screen.
- **Latest result card** shows that draw's jackpot amount alongside rollover status.
- **Fun-fact number circles use the same color function as the Numbers grid** (single palette source, keyed by number).
- Fun-facts card footer: "Every number has a story — tap any ball in History → Numbers for more."
- Perf: fetch facts for all displayed numbers in ONE query (`.in("number_value", numbers)`), not 7 serial calls.

## 3. History

### Draws segment
- Rows open a **draw detail**: winning numbers + additional number, prize-group table (Group 1–4 amounts, winners, rollover status). Back button "‹ All draws".
- `refresh()` must NOT clear the list before fetching — replace on success only.

### Numbers segment (fun-facts framing)
- Intro line: "Every number from 1–49 has its own fun facts. Tap one to read its story."
- Tapping a ball opens a detail: big colored ball, ONE fact (headline + body).
- **Fact rotation**: persist a per-number visit count; show `facts[(visitCount − 1) % facts.count]` so each visit shows the next fact. Data from `number_facts` table.
- Fix: `draws(containingNumber:)` should also match `additional_number`, not just `winning_numbers`.

## 4. Calculator

Card order: **Budget → What $X can buy → Value of this draw → disclaimer.**

- **Budget input**: slider $1–$100,000 + tappable/typeable amount. Typed input clamps to range. Currency formatted with thousands separators (en-SG) everywhere. No preset buttons.
- **Budget state is shared app-wide** (Calculator ↔ Picks): one observable source; moving either updates both.
- **"What $X can buy"**: list of `count × betType` rows (Ordinary, System 7/8/9/10) with cost "$N of $budget", counts comma-formatted, name column vertically aligned (fixed-width count column, tabular numerals).
- **Value gauge copy** (exact): rate depends only on jackpot size, not spend ("every dollar gets the same ~58¢ back"); break-even needs ~$9.7M jackpot, but big jackpots split more often — "so in practice, break-even draws don't really exist."
- Never frame any draw as "+EV / good time to play."
- Fix: avoid `Int(1 / p)` trap when p can be 0.

## 5. Picks (new tab)

- Same shared budget UI as Calculator (with "synced with Calculator" pill).
- **Four goals** (radio cards, language is "Best odds…"):
  1. Best odds at the jackpot
  2. Best odds of winning at least $100
  3. Best odds of winning at least $1,000
  4. Best odds of doubling your money
- **Jackpot goal**: recommend `budget ×` distinct Ordinary lines. Odds = 1 in round(13,983,816 / budget). Math note: every $1 line has identical jackpot odds; system bets don't help.
- **Target goals ($100 / $1,000 / 2×)**: for each affordable bet type (Ordinary, Sys 7/8/9):
  - `entryPayout(m)` = Σ over prize tiers j=3..m of C(m,j)·C(k−m,6−j)·prize[j], with approx prizes {3: $10, 4: $50, 5: $1,500, 6: $1.5M}
  - `need` = smallest m where entryPayout(m) ≥ target
  - `pEntry` = Σ m=need..6 of C(6,m)·C(43,k−m)/C(49,k) (hypergeometric)
  - `pAny` = 1 − (1 − pEntry)^count → recommend the type maximising pAny
  - Always label as **estimate** (Groups 1–4 pool-shared). If no tier reaches the target, say so.
- **Premium teaser**: "More detailed, customised combinations are coming in a future premium version. Leave your email for 50% off at launch." Email field + "Notify me" → "✓ Saved".
- Disclaimer: "Every combination is equally likely to be drawn. These picks optimise structure, not luck. Play responsibly."

## 6. Education

### Onboarding carousel (rework of OnboardingCarouselView)
- Dark gradient (#0B0B12 → #2B2A55), **segmented progress bar** (not dots), "MYTH n OF 5" label, quiet Skip top-right.
- Page layout: tinted emoji circle + red "THE MYTH" chip → myth quote (24px, no strikethrough) → "THE TRUTH" divider → **green truth headline (the takeaway, largest accent)** → body → mono stat chip.
- Footer: white "Next myth" / "Done" button + "Review these anytime in the Learn tab".
- Resolve the mandatory-vs-Skip contradiction: Skip is allowed, content remains in Learn.

### Learn tab
- "Replay the intro" hero card (opens carousel full-screen).
- "Every myth, busted" list: emoji + myth title (no strikethrough) + green verdict; rows open a full myth card (same dark layout as carousel pages). Back: "‹ All myths".
- **Single content source** for carousel + Learn (the `fallacies` table). Final copy (5 myths, cleaned):

| myth | truth | verdict | stat |
|---|---|---|---|
| "Number 8 is hot right now, so it's bound to keep hitting." | Balls have no memory. | Busted: balls have no memory | P(any number) = 6/49 in every draw |
| "13 hasn't come up in months, so it's overdue." | Nothing is ever overdue. | Busted: the gambler's fallacy | Absences of 20+ draws happen by pure chance |
| "My birthday numbers are luckier for me." | Same odds, worse payout. | Busted: they cost you more | Numbers 32 to 49 are picked about 40% less often |
| "A pattern like all even numbers can't win." | Every combination is equal. | Busted: every combo is equal | All 13,983,816 combinations have identical odds |
| "Buy more tickets and you'll come out ahead." | Losses scale with spend. | Busted: losses scale too | Return is about 58 cents per $1, at any volume |

Body copy for each is in the mock (`fallacyDeck()` in the DC logic).

## 7. Codebase fixes (from review, not visible in mocks)

- Surface `errorMessage` in Home/Calculator UIs; replace `try?` swallowing in DrawDetail/NumberDetail/Learn with retry states.
- Reword/remove the System-entry "strategy" card claim that spreading yields more prize hits per dollar (EV is identical; only variance differs).
- Inject repositories via init defaults for testability.
- `FallacyDetailView` gradient should `ignoresSafeArea`.
