// GENERATED FILE — do not edit by hand.
// Run: bun run shared/scripts/generateStatsSummary.ts
//
// Derived from data/draws.json (1193 draws, 2014-10-27 to 2026-06-18).
// drawStats.test.ts fails if these values drift from the dataset.

export const TOTAL_DRAWS = 1193;
export const FIRST_DRAW_ISO = "2014-10-27";
export const LAST_DRAW_ISO = "2026-06-18";

/** Draw counts by weekday. Mon + Thu alone understates the dataset: the
 *  remainder are Friday special draws. */
export const drawsByDay: Record<string, number> = {"Mon":596,"Thu":563,"Fri":34};

export const EXPECTED_FREQUENCY = 146.08163265306123;
export const CHI_SQUARED = 38.18189438390612;
export const CHI_SQUARED_THRESHOLD = 65.17;

export const ZERO_CARRYOVER_DRAWS = 498;
export const ZERO_CARRYOVER_COMPARABLE = 1192;

export const frequencyTop = [
  { n: "15", count: 175 },
  { n: "40", count: 168 },
  { n: "46", count: 161 },
  { n: "49", count: 159 },
  { n: "22", count: 158 },
] as const;

export const frequencyBottom = [
  { n: "45", count: 118 },
  { n: "33", count: 125 },
  { n: "42", count: 127 },
  { n: "29", count: 132 },
  { n: "25", count: 133 },
] as const;

export const maxFreq = 175;

export interface PairCount {
  pair: [number, number];
  count: number;
}

/** Expected co-appearances for any pair in a fair draw: draws x C(47,4)/C(49,6). */
export const EXPECTED_PAIR_CO_APPEARANCES = 15.216836734693878;

/** Most and least frequent pairs, plus anything tied with them. */
export const mostCommonPair: PairCount = { pair: [2, 15], count: 30 };
export const runnerUpPair: PairCount = { pair: [5, 49], count: 29 };
export const rarestPair: PairCount = { pair: [14, 34], count: 5 };
export const rarestPairTies: PairCount[] = [{ pair: [27, 45], count: 5 }];
export const mostCommonConsecutivePair: PairCount = { pair: [20, 21], count: 20 };
export const consecutivePairTies: PairCount[] = [{ pair: [23, 24], count: 20 }, { pair: [48, 49], count: 20 }];

/** The number whose Monday vs Thursday appearance rates differ most. */
export const BIGGEST_WEEKDAY_GAP = { n: 46, mon: 11.073825503355705, thu: 16.518650088809945, gap: 5.44482458545424 };

/** Any one number's chance of appearing in any one draw: 6 of 49. */
export const SINGLE_NUMBER_APPEARANCE_RATE = 12.244897959183673;

/** Formats a pair for copy, e.g. "2–15" (en dash). */
export function pairLabel(p: PairCount): string {
  return `${p.pair[0]}–${p.pair[1]}`;
}

/** Share of all draws in which a number appears, as a percentage. */
export function appearanceRate(count: number): number {
  return (count / TOTAL_DRAWS) * 100;
}

/** Rounds to one decimal place for display, e.g. 14.7. */
export function oneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}
