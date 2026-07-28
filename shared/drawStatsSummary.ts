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

/** Share of all draws in which a number appears, as a percentage. */
export function appearanceRate(count: number): number {
  return (count / TOTAL_DRAWS) * 100;
}

/** Rounds to one decimal place for display, e.g. 14.7. */
export function oneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}
