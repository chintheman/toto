// Editorial content shared by the site and the iOS app. `accent` keys map
// to the shared palette (see palette.ts) so each surface resolves colors
// through its own theme import.
//
// Every statistic quoted below is interpolated from drawStats.ts, which
// derives it from data/draws.json. Copy that states a number in prose is
// exactly where transcription drift hides: this file previously said the
// dataset was 1,159 draws (596 Monday + 563 Thursday) while the percentages
// were computed over the true 1,193 — the Mon/Thu split silently drops 34
// Friday special draws.

// Summary, not the raw history — see the note in totoData.ts.
import {
  TOTAL_DRAWS,
  drawsByDay,
  EXPECTED_FREQUENCY,
  CHI_SQUARED,
  CHI_SQUARED_THRESHOLD,
  ZERO_CARRYOVER_DRAWS,
  ZERO_CARRYOVER_COMPARABLE,
  frequencyTop,
  frequencyBottom,
  appearanceRate,
  oneDecimal,
  mostCommonPair,
  runnerUpPair,
  rarestPair,
  rarestPairTies,
  mostCommonConsecutivePair,
  consecutivePairTies,
  EXPECTED_PAIR_CO_APPEARANCES,
  BIGGEST_WEEKDAY_GAP,
  SINGLE_NUMBER_APPEARANCE_RATE,
  pairLabel,
  type PairCount,
} from "./drawStatsSummary";
import {
  SYSTEM_9_COMBOS,
  SYSTEM_7_COUNT_FOR_EQUAL_COST,
  SPREAD_ANY_PRIZE,
  CONCENTRATED_ANY_PRIZE,
} from "./totoData";

export type Accent = "terracotta" | "sage" | "brownLight";

const hottest = frequencyTop[0];
const coldest = frequencyBottom[0];
const zeroCarryoverPct = oneDecimal((ZERO_CARRYOVER_DRAWS / ZERO_CARRYOVER_COMPARABLE) * 100);
const shortfall = Math.round(EXPECTED_FREQUENCY - coldest.count);

// "Nearly 2x the expected rate" is a claim about a ratio, so state the ratio
// the data actually gives rather than a remembered adjective.
const timesExpected = (p: PairCount) => (p.count / EXPECTED_PAIR_CO_APPEARANCES).toFixed(2);
const tieClause = (ties: PairCount[]) =>
  ties.length === 0
    ? ""
    : ` Tied with ${ties.map(pairLabel).join(" and ")}.`;

export const myths = [
  { m: "Hot numbers win more", t: `Statistically? Nope. χ² (a test that checks if patterns are real or just random noise) comes out at ${CHI_SQUARED.toFixed(2)} — well below the ${CHI_SQUARED_THRESHOLD} threshold that would mean something's actually going on. Every number has the same odds, always.`, e: "🎲", verdict: "Pure gambler's fallacy" },
  { m: "Cold numbers are 'due'", t: `#${coldest.n} is our coldest number — ${coldest.count} hits in ${TOTAL_DRAWS.toLocaleString("en-SG")} draws, against ${hottest.count} for #${hottest.n}. It still has the same ~${oneDecimal(SINGLE_NUMBER_APPEARANCE_RATE)}% chance this draw as #${hottest.n} does. Draws have no memory.`, e: "🧊", verdict: "The lottery doesn't owe you anything" },
  { m: "Bigger systems = better odds", t: `1× System 9 covers ${SYSTEM_9_COMBOS} combos across 9 numbers. ${SYSTEM_7_COUNT_FOR_EQUAL_COST}× System 7 covers ${SYSTEM_9_COMBOS} combos across 49. Same spend — and the spread wins something ${oneDecimal(SPREAD_ANY_PRIZE)}% of the time against ${oneDecimal(CONCENTRATED_ANY_PRIZE)}% for the System 9.`, e: "📊", verdict: "Spread beats concentration" },
  { m: "Past patterns predict the future", t: "13,983,816 combinations. No memory. No momentum. The only pattern is that there is no pattern.", e: "🔮", verdict: "Not how probability works" },
  { m: "Monday and Thursday draws differ", t: `${drawsByDay.Mon ?? 0} Mon vs ${drawsByDay.Thu ?? 0} Thu draws analysed, plus ${drawsByDay.Fri ?? 0} Friday special draws. Biggest frequency gap was #${BIGGEST_WEEKDAY_GAP.n} at ${oneDecimal(BIGGEST_WEEKDAY_GAP.mon)}% Mon vs ${oneDecimal(BIGGEST_WEEKDAY_GAP.thu)}% Thu. Statistically meaningless after correction.`, e: "📅", verdict: "Noise, not signal" },
  { m: "Buying more tickets doesn't help", t: "It does — linearly. 100 tickets = 100/13,983,816 = 1 in 139,838 jackpot chance. Still a lottery, just slightly less hopeless.", e: "🎫", verdict: "More tickets = proportionally better odds" },
  { m: "The system is rigged", t: `${TOTAL_DRAWS.toLocaleString("en-SG")} draws, chi-squared test passes every time. Singapore Pools is government-regulated and independently audited. The game is fair.`, e: "⚖️", verdict: "Fair game, unfair maths" },
] as const;

export const funFacts = [
  { n: `#${hottest.n}`, stat: `${hottest.count} appearances`, label: "Most frequent number", detail: `Shows up in ${oneDecimal(appearanceRate(hottest.count))}% of all draws — but χ² says it's noise. Flukes happen at scale.`, accent: "terracotta" as Accent, emoji: "🔥" },
  { n: `#${coldest.n}`, stat: `${coldest.count} appearances`, label: "Least frequent number", detail: `Would need ${shortfall} more hits just to reach the ${oneDecimal(EXPECTED_FREQUENCY)} average. Random variance — not rigged, not cursed.`, accent: "sage" as Accent, emoji: "🌿" },
  { n: pairLabel(mostCommonPair), stat: `${mostCommonPair.count} co-appearances`, label: "Most common pair", detail: `${timesExpected(mostCommonPair)}× the expected rate. But it's still within chance. Pair ${pairLabel(runnerUpPair)} (${runnerUpPair.count}×) right behind.`, accent: "brownLight" as Accent, emoji: "🤝" },
  { n: pairLabel(rarestPair), stat: `${rarestPair.count} co-appearances`, label: "Rarest pair", detail: `Only ${timesExpected(rarestPair)}× the expected rate across ${TOTAL_DRAWS.toLocaleString("en-SG")} draws.${tieClause(rarestPairTies)}`, accent: "brownLight" as Accent, emoji: "🙈" },
  { n: `${zeroCarryoverPct}%`, stat: `${ZERO_CARRYOVER_DRAWS} draws`, label: "Draws with zero carryover", detail: "In more than four draws in ten, not a single number repeated from the previous one.", accent: "terracotta" as Accent, emoji: "♻️" },
  { n: pairLabel(mostCommonConsecutivePair), stat: `${mostCommonConsecutivePair.count} co-appearances`, label: "Favourite neighbours", detail: `The most common consecutive pair.${tieClause(consecutivePairTies)}`, accent: "sage" as Accent, emoji: "👫" },
] as const;
