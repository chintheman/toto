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
  mostCommonPairs,
  rarestPairs,
  consecutivePairCounts,
  pairsWithCount,
  EXPECTED_PAIR_CO_APPEARANCES,
  BIGGEST_WEEKDAY_GAP,
  SINGLE_NUMBER_APPEARANCE_RATE,
  type PairCount,
} from "../drawStats";

const entries = (list: { n: string; count: number }[]) =>
  list.map(e => `  { n: "${e.n}", count: ${e.count} },`).join("\n");

const pairEntry = (p: PairCount) => `{ pair: [${p.pair[0]}, ${p.pair[1]}], count: ${p.count} }`;

const topPair = mostCommonPairs(2);
const rarePair = rarestPairs(1)[0]!;
const topConsecutive = mostCommonPairs(1, consecutivePairCounts)[0]!;

// "Tied with" copy needs the full tie set, not just the winner.
const rareTies = pairsWithCount(rarePair.count).filter(p => p.pair.join() !== rarePair.pair.join());
const consecutiveTies = pairsWithCount(topConsecutive.count, consecutivePairCounts).filter(
  p => p.pair.join() !== topConsecutive.pair.join()
);

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

export interface PairCount {
  pair: [number, number];
  count: number;
}

/** Expected co-appearances for any pair in a fair draw: draws x C(47,4)/C(49,6). */
export const EXPECTED_PAIR_CO_APPEARANCES = ${EXPECTED_PAIR_CO_APPEARANCES};

/** Most and least frequent pairs, plus anything tied with them. */
export const mostCommonPair: PairCount = ${pairEntry(topPair[0]!)};
export const runnerUpPair: PairCount = ${pairEntry(topPair[1]!)};
export const rarestPair: PairCount = ${pairEntry(rarePair)};
export const rarestPairTies: PairCount[] = [${rareTies.map(pairEntry).join(", ")}];
export const mostCommonConsecutivePair: PairCount = ${pairEntry(topConsecutive)};
export const consecutivePairTies: PairCount[] = [${consecutiveTies.map(pairEntry).join(", ")}];

/** The number whose Monday vs Thursday appearance rates differ most. */
export const BIGGEST_WEEKDAY_GAP = { n: ${BIGGEST_WEEKDAY_GAP.n}, mon: ${BIGGEST_WEEKDAY_GAP.mon}, thu: ${BIGGEST_WEEKDAY_GAP.thu}, gap: ${BIGGEST_WEEKDAY_GAP.gap} };

/** Any one number's chance of appearing in any one draw: 6 of 49. */
export const SINGLE_NUMBER_APPEARANCE_RATE = ${SINGLE_NUMBER_APPEARANCE_RATE};

/** Formats a pair for copy, e.g. "2–15" (en dash). */
export function pairLabel(p: PairCount): string {
  return \`\${p.pair[0]}–\${p.pair[1]}\`;
}

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
