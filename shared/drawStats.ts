// Every published frequency, percentage and chi-squared figure in this
// project is derived here from the raw draw history in data/draws.json,
// rather than transcribed by hand.
//
// The transcribed versions had already drifted: the site claimed a 1,159-draw
// dataset (596 Monday + 563 Thursday) while the data holds 1,193 draws — the
// Monday/Thursday split omits 34 Friday special draws. The percentages were
// computed against the full 1,193 and were correct; only the stated
// denominator was wrong, which made the two look inconsistent and invited a
// "fix" in the wrong direction.

import rawDraws from "./data/draws.json";
import { nCr, TOTAL_COMBINATIONS } from "./evMath";

export interface Draw {
  draw_no: number;
  date: string; // "Mon, 27 Oct 2014"
  date_iso: string;
  winning_numbers: number[];
  additional_number: number;
}

export const draws: Draw[] = rawDraws as Draw[];

export const TOTAL_DRAWS = draws.length;
export const FIRST_DRAW_ISO = draws[0]?.date_iso ?? "";
export const LAST_DRAW_ISO = draws[draws.length - 1]?.date_iso ?? "";

/** Draw counts by weekday label, e.g. { Mon: 596, Thu: 563, Fri: 34 }. */
export const drawsByDay: Record<string, number> = draws.reduce<Record<string, number>>((acc, d) => {
  const day = d.date.split(",")[0]?.trim() ?? "";
  acc[day] = (acc[day] ?? 0) + 1;
  return acc;
}, {});

/** How many times each of the 49 numbers has been drawn as a main number. */
export const frequencyByNumber: Map<number, number> = (() => {
  const counts = new Map<number, number>();
  for (let n = 1; n <= 49; n++) counts.set(n, 0);
  for (const draw of draws) {
    for (const n of draw.winning_numbers) counts.set(n, (counts.get(n) ?? 0) + 1);
  }
  return counts;
})();

/** Expected appearances per number if the draw is fair: draws x 6 / 49. */
export const EXPECTED_FREQUENCY = (TOTAL_DRAWS * 6) / 49;

/**
 * Pearson chi-squared over the 49 numbers. With 48 degrees of freedom the
 * 5% critical value is 65.17, so anything below that is consistent with a
 * fair draw.
 */
export const CHI_SQUARED = (() => {
  let total = 0;
  for (let n = 1; n <= 49; n++) {
    const observed = frequencyByNumber.get(n) ?? 0;
    total += (observed - EXPECTED_FREQUENCY) ** 2 / EXPECTED_FREQUENCY;
  }
  return total;
})();

export const CHI_SQUARED_THRESHOLD = 65.17;

// Ties break by the lower number in both directions, so the two tables are
// stable across data refreshes and never disagree about a boundary tie.
function counts(): { n: string; count: number }[] {
  return Array.from(frequencyByNumber.entries()).map(([n, count]) => ({ n: String(n), count }));
}

export function mostFrequent(count: number): { n: string; count: number }[] {
  return counts()
    .sort((a, b) => b.count - a.count || Number(a.n) - Number(b.n))
    .slice(0, count);
}

export function leastFrequent(count: number): { n: string; count: number }[] {
  return counts()
    .sort((a, b) => a.count - b.count || Number(a.n) - Number(b.n))
    .slice(0, count);
}

/**
 * Draws sharing no main number with the draw immediately before them. The
 * first draw has no predecessor, so the denominator is TOTAL_DRAWS - 1.
 */
export const ZERO_CARRYOVER_DRAWS = (() => {
  let total = 0;
  for (let i = 1; i < draws.length; i++) {
    const previous = new Set(draws[i - 1]?.winning_numbers ?? []);
    const shares = (draws[i]?.winning_numbers ?? []).some(n => previous.has(n));
    if (!shares) total++;
  }
  return total;
})();

export const ZERO_CARRYOVER_COMPARABLE = Math.max(TOTAL_DRAWS - 1, 1);

// ── Pair statistics ────────────────────────────────────────────────────────
// These back the "most/rarest pair" and "favourite neighbours" fun facts.
// They were previously hardcoded in content.ts — accurate at the time, but
// nothing would have caught them going stale after a data refresh, which is
// the same failure mode that produced the 1,159-draw claim.

export interface PairCount {
  pair: [number, number]; // ascending
  count: number;
}

/** Co-appearance count for all C(49,2) = 1,176 unordered pairs. */
export const pairCounts: PairCount[] = (() => {
  const counts = new Map<string, number>();
  for (let a = 1; a <= 49; a++) {
    for (let b = a + 1; b <= 49; b++) counts.set(`${a},${b}`, 0);
  }
  for (const draw of draws) {
    const sorted = [...draw.winning_numbers].sort((x, y) => x - y);
    for (let i = 0; i < sorted.length; i++) {
      for (let j = i + 1; j < sorted.length; j++) {
        const key = `${sorted[i]},${sorted[j]}`;
        counts.set(key, (counts.get(key) ?? 0) + 1);
      }
    }
  }
  return Array.from(counts.entries()).map(([key, count]) => {
    const [a, b] = key.split(",").map(Number) as [number, number];
    return { pair: [a, b] as [number, number], count };
  });
})();

/**
 * Expected co-appearances for any given pair in a fair draw: both numbers
 * land iff the remaining 4 winning numbers come from the other 47, so
 * P = C(47,4) / C(49,6) per draw.
 */
export const EXPECTED_PAIR_CO_APPEARANCES = (TOTAL_DRAWS * nCr(47, 4)) / TOTAL_COMBINATIONS;

// Ties break by the pair's own ordering so the tables stay stable across
// data refreshes, matching the mostFrequent/leastFrequent convention above.
function byCount(ascending: boolean) {
  return (a: PairCount, b: PairCount) =>
    (ascending ? a.count - b.count : b.count - a.count) ||
    a.pair[0] - b.pair[0] ||
    a.pair[1] - b.pair[1];
}

export function mostCommonPairs(count: number, pool = pairCounts): PairCount[] {
  return [...pool].sort(byCount(false)).slice(0, count);
}

export function rarestPairs(count: number, pool = pairCounts): PairCount[] {
  return [...pool].sort(byCount(true)).slice(0, count);
}

/** Pairs of adjacent numbers, e.g. 23-24. Used for the "neighbours" fact. */
export const consecutivePairCounts: PairCount[] = pairCounts.filter(p => p.pair[1] - p.pair[0] === 1);

/** How many pairs share the top (or bottom) count — "tied with" copy needs it. */
export function pairsWithCount(target: number, pool = pairCounts): PairCount[] {
  return pool.filter(p => p.count === target).sort(byCount(false));
}

// ── Weekday comparison ─────────────────────────────────────────────────────

export interface WeekdayGap {
  n: number;
  mon: number; // appearance rate on Monday draws, as a percentage
  thu: number;
  gap: number; // absolute difference in percentage points
}

/**
 * The number whose Monday and Thursday appearance rates differ most. Quoted
 * in the "Monday and Thursday draws differ" myth as the *largest* gap the
 * dataset offers — so it has to be found, not remembered, or the myth ends
 * up citing a number that is no longer the extreme.
 */
export const weekdayGaps: WeekdayGap[] = (() => {
  const mondays = draws.filter(d => d.date.startsWith("Mon"));
  const thursdays = draws.filter(d => d.date.startsWith("Thu"));
  const rate = (subset: Draw[], n: number) =>
    subset.length ? (subset.filter(d => d.winning_numbers.includes(n)).length / subset.length) * 100 : 0;
  const out: WeekdayGap[] = [];
  for (let n = 1; n <= 49; n++) {
    const mon = rate(mondays, n);
    const thu = rate(thursdays, n);
    out.push({ n, mon, thu, gap: Math.abs(mon - thu) });
  }
  return out.sort((a, b) => b.gap - a.gap || a.n - b.n);
})();

export const BIGGEST_WEEKDAY_GAP: WeekdayGap = weekdayGaps[0]!;

/** Share of all draws in which a given number appears, as a percentage. */
export function appearanceRate(count: number): number {
  return (count / TOTAL_DRAWS) * 100;
}

/**
 * A single number's chance of appearing in any one draw: 6 of 49, so
 * 12.24%. Quoted in the "cold numbers are due" myth, where the whole point
 * is that this value is identical for every number.
 */
export const SINGLE_NUMBER_APPEARANCE_RATE = (6 / 49) * 100;

/** Rounds to one decimal place for display, e.g. 14.7. */
export function oneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}
