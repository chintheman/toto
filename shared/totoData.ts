// Analysis dataset shared by the site and the explainer video, so a data
// refresh updates both at once. Derived from 1,000+ Singapore TOTO draws.

import { evAtJackpot as evPercentAtJackpot, breakEvenJackpot } from "./evMath";

// C(49,6) — total combinations; jackpot odds for N distinct combos = N in this.
export { TOTAL_COMBINATIONS } from "./evMath";

export const strats = {
  "1k": {
    name: "G3+ Optimised",
    tag: "Best overall odds",
    cost: 100,
    any: "49.3%",
    g3: "1 in 969",
    // 100 combinations × P(5 main + additional) = 100 × 6/13,983,816.
    // Was "1 in 150K", which made G2 rarer than the jackpot — impossible,
    // since every combination is 6× more likely to hit G2 than G1.
    g2: "1 in 23K",
    g1: "1 in 140K",
    m: "12× System 7 + 16× Ordinary ($100)",
    w: "You want the best chance of winning something — any prize, any draw.",
  },
  "100k": {
    name: "G2 Hunter",
    tag: "Best G2 odds",
    cost: 100,
    any: "42%",
    g3: "1 in 1,250",
    g2: "1 in 100K",
    g1: "1 in 140K",
    m: "10× System 7 + 30× Ordinary ($100)",
    w: "You're specifically hunting the ~$100K prize. Accepts lower small-win frequency.",
  },
  mega: {
    name: "Jackpot or Bust",
    tag: "All-in on 14 numbers",
    cost: 54,
    any: "22%",
    g3: "1 in 2,800",
    g2: "1 in 200K",
    // 54 distinct combos → 54 / 13,983,816 ≈ 1 in 258,959.
    g1: "1 in 259K",
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

export const frequencyTop = [
  { n: "15", count: 175 },
  { n: "40", count: 168 },
  { n: "46", count: 161 },
  { n: "28", count: 161 },
  { n: "49", count: 160 },
] as const;

export const frequencyBottom = [
  { n: "25", count: 135 },
  { n: "29", count: 132 },
  { n: "42", count: 127 },
  { n: "33", count: 126 },
  { n: "45", count: 119 },
] as const;

// Derived rather than hand-maintained: a data refresh that updates the
// frequency tables now rescales every bar in the site and the video
// automatically, instead of silently leaving them on a stale maximum.
export const maxFreq = Math.max(...frequencyTop.map(f => f.count), ...frequencyBottom.map(f => f.count));
