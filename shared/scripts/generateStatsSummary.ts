#!/usr/bin/env bun
// Regenerates shared/drawStatsSummary.ts from data/draws.json.
//
// The site and video import the summary, not the raw history: bundling all
// 1,193 draws shipped ~150 KB of JSON to the browser for a handful of
// numbers. drawStats.test.ts asserts the committed summary still matches the
// dataset, so a stale summary fails CI rather than silently going out of date.
//
//   bun run shared/scripts/generateStatsSummary.ts

import {
  TOTAL_DRAWS,
  FIRST_DRAW_ISO,
  LAST_DRAW_ISO,
  drawsByDay,
  EXPECTED_FREQUENCY,
  CHI_SQUARED,
  ZERO_CARRYOVER_DRAWS,
  ZERO_CARRYOVER_COMPARABLE,
  mostFrequent,
  leastFrequent,
} from "../drawStats";

const entries = (list: { n: string; count: number }[]) =>
  list.map(e => `  { n: "${e.n}", count: ${e.count} },`).join("\n");

const file = `// GENERATED FILE — do not edit by hand.
// Run: bun run shared/scripts/generateStatsSummary.ts
//
// Derived from data/draws.json (${TOTAL_DRAWS} draws, ${FIRST_DRAW_ISO} to ${LAST_DRAW_ISO}).
// drawStats.test.ts fails if these values drift from the dataset.

export const TOTAL_DRAWS = ${TOTAL_DRAWS};
export const FIRST_DRAW_ISO = "${FIRST_DRAW_ISO}";
export const LAST_DRAW_ISO = "${LAST_DRAW_ISO}";

/** Draw counts by weekday. Mon + Thu alone understates the dataset: the
 *  remainder are Friday special draws. */
export const drawsByDay: Record<string, number> = ${JSON.stringify(drawsByDay)};

export const EXPECTED_FREQUENCY = ${EXPECTED_FREQUENCY};
export const CHI_SQUARED = ${CHI_SQUARED};
export const CHI_SQUARED_THRESHOLD = 65.17;

export const ZERO_CARRYOVER_DRAWS = ${ZERO_CARRYOVER_DRAWS};
export const ZERO_CARRYOVER_COMPARABLE = ${ZERO_CARRYOVER_COMPARABLE};

export const frequencyTop = [
${entries(mostFrequent(5))}
] as const;

export const frequencyBottom = [
${entries(leastFrequent(5))}
] as const;

export const maxFreq = ${mostFrequent(1)[0]?.count ?? 0};

/** Share of all draws in which a number appears, as a percentage. */
export function appearanceRate(count: number): number {
  return (count / TOTAL_DRAWS) * 100;
}

/** Rounds to one decimal place for display, e.g. 14.7. */
export function oneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}
`;

await Bun.write(new URL("../drawStatsSummary.ts", import.meta.url), file);
console.log(`Wrote drawStatsSummary.ts from ${TOTAL_DRAWS} draws.`);
