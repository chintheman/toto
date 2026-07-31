// Analysis dataset shared by the site and the explainer video, so a data
// refresh updates both at once. Derived from 1,000+ Singapore TOTO draws.

import { evAtJackpot as evPercentAtJackpot, breakEvenJackpot, evPerDollar, probabilityAnyPrize, nCr, TOTAL_COMBINATIONS } from "./evMath";
// Summary, not the raw history: importing drawStats here would bundle all
// 1,193 draws into the browser for five table rows.
import { frequencyTop as derivedTop, frequencyBottom as derivedBottom, maxFreq as derivedMax } from "./drawStatsSummary";

// C(49,6) — total combinations; jackpot odds for N distinct combos = N in this.
export { TOTAL_COMBINATIONS } from "./evMath";

// $1 per combination always (System N tickets buy exactly C(N,6) combos for
// C(N,6) dollars), so a strategy's `cost` in dollars equals its exact
// distinct-combo count. That makes G1 and G2 computable in closed form:
//
//   G1 (jackpot, "6 of 6")        — exactly one winning combination exists,
//                                    so N distinct combos give N/13,983,816.
//   G2 ("5 of 6" + additional)    — exactly 6 combos are worth anything per
//                                    draw (choose which of the 6 winning
//                                    numbers is "missed"), so N combos give
//                                    6N/13,983,816.
//
// Both are exact regardless of how the combos are packaged (Ordinary vs
// System bets), because a G1 or G2 win can only ever be produced by ONE
// specific combination per draw — there is no scenario where two different
// sub-lines of the same System entry simultaneously qualify, so there is
// nothing for a Monte Carlo to average over and no double-counting to worry
// about. Treating them as simulated quantities is how "1k" ended up
// advertising G2 at 1 in 150K against a 1 in 140K jackpot — impossible,
// since G2 is exactly 6x more likely than G1 for any portfolio — and later
// how a 6,000,000-trial run still landed outside the true value (21.7K
// simulated against a 23.3K analytic ceiling for N=100): with only ~4.3e-5
// hit probability per combo, a few hundred total hits across the whole run
// carries several percent of sampling noise, enough to cross an exact bound
// in either direction.
//
// G3 ("5 of 6", no additional) has no such shortcut: System-bet entries
// share numbers across their C(k,6) sub-lines, so a single well-matched
// System 7 can produce several simultaneous G3-or-better hits from one
// draw. That correlation is real (verified: a System-7 entry containing 5+
// winning numbers routinely lights up multiple of its 7 sub-lines at once),
// and it pulls the true rate well below the naive per-combo sum — the
// measured rate for "1k" is 1 in 941 (20M-trial run, CI [928, 954]) for a
// portfolio whose 100 combos would suggest ~1 in 540 if they were
// independent. There's no closed form for that without modelling the exact
// deal pattern, so G3 stays a Monte Carlo estimate
// (scripts/simulateStrategies.ts, 500 portfolios x 40,000 draws).
function exactG1(costDollars: number): string {
  const oneIn = TOTAL_COMBINATIONS / costDollars;
  // "en-SG" is pinned deliberately. A bare toLocaleString() follows the
  // *viewer's* locale, so a German browser renders 69,919 as "69.919" — and
  // strategyInvariants' parseOneIn, which strips commas, would then read
  // that as 69.919 and silently pass a figure off by a factor of 1,000.
  // Only strategies costing more than $140 reach this branch today, so the
  // trap is latent rather than live, which is exactly why it needs pinning
  // before a cheaper budget tier lands on it.
  return `1 in ${Math.round(oneIn / 1000) * 1000 >= 100_000 ? Math.round(oneIn / 1000) + "K" : Math.round(oneIn).toLocaleString("en-SG")}`;
}
function exactG2(costDollars: number): string {
  const oneIn = TOTAL_COMBINATIONS / (6 * costDollars);
  return `1 in ${(oneIn / 1000).toFixed(1)}K`;
}

export const strats = {
  "1k": {
    name: "G3+ Optimised",
    tag: "Balanced spread",
    cost: 100,
    any: "51.9%",
    g3: "1 in 941",
    g2: exactG2(100),
    g1: exactG1(100),
    m: "12× System 7 + 16× Ordinary ($100)",
    w: "You want a good chance of winning something — any prize, any draw.",
  },
  "100k": {
    name: "G2 Hunter",
    tag: "Most tickets, widest spread",
    cost: 100,
    any: "61.0%",
    g3: "1 in 835",
    g2: exactG2(100),
    g1: exactG1(100),
    m: "10× System 7 + 30× Ordinary ($100)",
    w: "Forty tickets instead of twenty-eight, for the same $100 and the same 100 combinations — spread across more distinct numbers.",
  },
  mega: {
    name: "Jackpot or Bust",
    tag: "All-in on 14 numbers",
    cost: 54,
    any: "15.8%",
    g3: "1 in 2,002",
    g2: exactG2(54),
    g1: exactG1(54),
    m: "7× System 7 + 5× Ordinary ($54)",
    w: "You want the jackpot. Concentrated 14-number pool — live or die by those 14.",
  },
} as const;

// ── The $84 spread-vs-concentration comparison ─────────────────────────────
//
// The site's "spread your tickets" accordion and the "bigger systems" myth
// both compare two portfolios that cost exactly the same $84: one System 9
// (84 combos locked inside 9 numbers) against 12 System 7s (84 combos dealt
// across all 49). The published figures used to be "~49% vs ~22%", and both
// were wrong:
//
//   - The concentrated side is EXACT, not a backtest. A System 9 wins
//     something iff at least 3 of the 6 winning numbers fall inside its 9,
//     which is probabilityAnyPrize(9) = 6.7% — not 22%. The old figure
//     overstated it by more than 3x.
//   - The spread side was not merely optimistic, it was impossible. Boole's
//     inequality caps 12 System 7s at 12 x probabilityAnyPrize(7) = 37.1%,
//     so a published 49% claimed a rate the union bound forbids. This is the
//     same class of error strategyInvariants.test.ts was written to catch —
//     it just lived in site prose, which no test was reading.
//
// The true gap is wider than the false one: 36.5% against 6.7% is 5.5x, not
// the 2.2x the old numbers implied. Being accurate makes the point better.
export const SYSTEM_9_COMBOS = nCr(9, 6); // 84 combos for $84
export const SYSTEM_7_COUNT_FOR_EQUAL_COST = SYSTEM_9_COMBOS / nCr(7, 6); // 12 tickets

/** Exact: a System 9 pays iff >=3 of the 6 winners land inside its 9 numbers. */
export const CONCENTRATED_ANY_PRIZE = probabilityAnyPrize(9) * 100;

/**
 * Monte Carlo, 2,000,000 draws against 12 System 7s dealt evenly across all
 * 49 numbers (95% CI +/-0.07pp). No closed form exists: the 12 tickets share
 * numbers, so their sub-lines correlate and the events are not independent.
 * strategyInvariants.test.ts asserts this stays under the union bound.
 */
export const SPREAD_ANY_PRIZE = 36.5;

/** Ceiling the spread figure can never exceed, whatever the correlation. */
export const SPREAD_ANY_PRIZE_CEILING = SYSTEM_7_COUNT_FOR_EQUAL_COST * probabilityAnyPrize(7) * 100;

// EV expressed as cents returned per dollar staked, for the "what's the
// play" copy. Previously hardcoded as "about 52-66c at a typical $2-5M
// jackpot"; the model actually gives 48c at $2M and 70c at $5M, so both
// ends of the stated range were wrong. Derived now, so the copy tracks the
// prize constants instead of drifting from them.
export function centsPerDollarAtJackpot(millions: number): number {
  return Math.round(evPerDollar(millions * 1_000_000) * 100);
}

// Jackpot sizes charted on the EV curve. The top of the range sits above
// break-even (~$9.23M) so the chart shows where the line actually crosses
// instead of stopping short of it.
const EV_CHART_POINTS = [1, 2, 2.5, 3.5, 4.5, 6, 8, 10] as const;

function formatMillions(m: number): string {
  return `$${m}M`;
}

// EV per dollar spent vs jackpot size (m = jackpot in $M), derived from the
// shared combinatorial model rather than hardcoded. Previously this was a
// table of seven hand-entered constants that claimed +7% at $4.5M and +48%
// at $8M; the derivation gives -33.8% and -8.8%.
export const evByJackpot = EV_CHART_POINTS.map(m => ({
  jackpot: formatMillions(m),
  m,
  ev: Math.round(evPercentAtJackpot(m) * 10) / 10,
}));

// The jackpot size, in millions, at which a ticket crosses into +EV.
export const BREAK_EVEN_MILLIONS = Math.round((breakEvenJackpot() / 1_000_000) * 100) / 100;

// EV% at an arbitrary jackpot size, computed exactly from the model.
export { evAtJackpot } from "./evMath";

// Derived from the raw draw history rather than transcribed. The previous
// hardcoded tables had drifted from the data: they listed 28 at 161 and 49 at
// 160 in the top five (the data has 49 at 159 and 22 at 158), and every entry
// in the bottom five was one or two appearances high.
export const frequencyTop = derivedTop;
export const frequencyBottom = derivedBottom;

// Derived rather than hand-maintained: a data refresh that updates the
// frequency tables now rescales every bar in the site and the video
// automatically, instead of silently leaving them on a stale maximum.
export const maxFreq = derivedMax;
