// Analysis dataset shared by the site and the explainer video, so a data
// refresh updates both at once. Derived from 1,000+ Singapore TOTO draws.

// C(49,6) — total combinations; jackpot odds for N distinct combos = N in this.
export const TOTAL_COMBINATIONS = 13_983_816;

export const strats = {
  "1k": {
    name: "G3+ Optimised",
    tag: "Best overall odds",
    cost: 100,
    any: "49.3%",
    g3: "1 in 969",
    g2: "1 in 150K",
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

// EV per dollar spent vs jackpot size (m = jackpot in $M); bar width
// derives as (100 + ev) / 2.
export const evByJackpot = [
  { jackpot: "$1M", m: 1, ev: -72 },
  { jackpot: "$2M", m: 2, ev: -55 },
  { jackpot: "$2.5M", m: 2.5, ev: -42 },
  { jackpot: "$3.5M", m: 3.5, ev: -15 },
  { jackpot: "$4.5M", m: 4.5, ev: 7 },
  { jackpot: "$6M", m: 6, ev: 25 },
  { jackpot: "$8M", m: 8, ev: 48 },
] as const;

// EV% at an arbitrary jackpot size, linearly interpolated between the
// table's points and extrapolated with the last segment's slope above it.
export function evAtJackpot(millions: number): number {
  let prev: (typeof evByJackpot)[number] = evByJackpot[0];
  if (millions <= prev.m) return prev.ev;
  for (const pt of evByJackpot) {
    if (millions <= pt.m) {
      return prev.ev + ((millions - prev.m) / (pt.m - prev.m)) * (pt.ev - prev.ev);
    }
    prev = pt;
  }
  const a = evByJackpot[evByJackpot.length - 2] ?? prev;
  return prev.ev + ((millions - prev.m) / (prev.m - a.m)) * (prev.ev - a.ev);
}

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

export const maxFreq = 175;
