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

/** Share of all draws in which a given number appears, as a percentage. */
export function appearanceRate(count: number): number {
  return (count / TOTAL_DRAWS) * 100;
}

/** Rounds to one decimal place for display, e.g. 14.7. */
export function oneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}
