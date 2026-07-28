// Analysis dataset shared by the site and the explainer video, so a data
// refresh updates both at once. Derived from 1,000+ Singapore TOTO draws.

import { evAtJackpot as evPercentAtJackpot, breakEvenJackpot, TOTAL_COMBINATIONS } from "./evMath";
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
// about. Treating them as simulated quantities is how "1k" once advertised
// G2 at 1 in 150K against a 1 in 140K jackpot — impossible, since G2 is
// exactly 6x more likely than G1 for any portfolio — and later how a
// 6,000,000-trial run still landed outside the true value (21.7K simulated
// against a 23.3K analytic ceiling for N=100): with only ~4.3e-5 hit
// probability per combo, a few hundred total hits across the whole run
// carries several percent of sampling noise, enough to cross an exact bound
// in either direction.
//
// G3 ("5 of 6", no additional) has no such shortcut: System-bet entries
// share numbers across their C(k,6) sub-lines, so a single well-matched
// System 7 can produce several simultaneous G3-or-better hits from one
// draw. That correlation is real and measurable: "100k" (10x System 7 +
// 30x Ordinary) lands at 1 in 835 for G3-or-better, against the ~1 in 540
// a naive independent-combo estimate would predict for 100 combos. "1k" is
// now a deliberate control for this — 100 combos, zero System bets — and it
// measures 1 in ~540, matching the independent prediction almost exactly.
// That gap is the entire reason "1k" no longer uses System bets: they were
// quietly lowering the any-prize and G3-or-better rates for the packaging,
// not helping. There's no closed form for the correlated case without
// modelling the exact deal pattern, so G3 stays a Monte Carlo estimate
// (scripts/simulateStrategies.ts, 500 portfolios x 40,000 draws).
function exactG1(costDollars: number): string {
  const oneIn = TOTAL_COMBINATIONS / costDollars;
  return `1 in ${Math.round(oneIn / 1000) * 1000 >= 100_000 ? Math.round(oneIn / 1000) + "K" : Math.round(oneIn).toLocaleString()}`;
}
function exactG2(costDollars: number): string {
  const oneIn = TOTAL_COMBINATIONS / (6 * costDollars);
  return `1 in ${(oneIn / 1000).toFixed(1)}K`;
}

export const strats = {
  "1k": {
    name: "Pure Spread",
    tag: "Best any-prize odds",
    cost: 100,
    any: "86.5%",
    g3: "1 in 540",
    g2: exactG2(100),
    g1: exactG1(100),
    m: "100× Ordinary, no System bets ($100)",
    w: "You want the best chance of winning something — any prize, any draw. System-bet sub-lines correlate with each other, which quietly lowers this; 100 fully independent lines don't have that problem.",
  },
  "100k": {
    name: "G2 Hunter",
    tag: "Fewer, larger tickets",
    cost: 100,
    any: "61.0%",
    g3: "1 in 835",
    g2: exactG2(100),
    g1: exactG1(100),
    m: "10× System 7 + 30× Ordinary ($100)",
    w: "Same $100, same 100 combinations, packaged into fewer tickets to manage — a real convenience trade against Pure Spread's better odds, not a mathematical advantage.",
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
