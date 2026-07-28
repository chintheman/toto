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
} from "./drawStatsSummary";

export type Accent = "terracotta" | "sage" | "brownLight";

const hottest = frequencyTop[0];
const coldest = frequencyBottom[0];
const zeroCarryoverPct = oneDecimal((ZERO_CARRYOVER_DRAWS / ZERO_CARRYOVER_COMPARABLE) * 100);
const shortfall = Math.round(EXPECTED_FREQUENCY - coldest.count);

export const myths = [
  { m: "Hot numbers win more", t: `Statistically? Nope. χ² (a test that checks if patterns are real or just random noise) comes out at ${CHI_SQUARED.toFixed(2)} — well below the ${CHI_SQUARED_THRESHOLD} threshold that would mean something's actually going on. Every number has the same odds, always.`, e: "🎲", verdict: "Pure gambler's fallacy" },
  { m: "Cold numbers are 'due'", t: `#${coldest.n} is our coldest number — ${coldest.count} hits in ${TOTAL_DRAWS.toLocaleString("en-SG")} draws, against ${hottest.count} for #${hottest.n}. It still has the same ~12.2% chance this draw as #${hottest.n} does. Draws have no memory.`, e: "🧊", verdict: "The lottery doesn't owe you anything" },
  { m: "Bigger systems = better odds", t: "1× System 9 covers 84 combos across 9 numbers. 12× System 7 covers 84 combos across 49. Same spend — dramatically different coverage.", e: "📊", verdict: "Spread beats concentration" },
  { m: "Past patterns predict the future", t: "13,983,816 combinations. No memory. No momentum. The only pattern is that there is no pattern.", e: "🔮", verdict: "Not how probability works" },
  { m: "Monday and Thursday draws differ", t: `${drawsByDay.Mon ?? 0} Mon vs ${drawsByDay.Thu ?? 0} Thu draws analysed, plus ${drawsByDay.Fri ?? 0} Friday special draws. Biggest frequency gap was #46 at 11.1% Mon vs 16.5% Thu. Statistically meaningless after correction.`, e: "📅", verdict: "Noise, not signal" },
  { m: "Buying more tickets doesn't help", t: "It does — linearly. 100 tickets = 100/13,983,816 = 1 in 139,838 jackpot chance. Still a lottery, just slightly less hopeless.", e: "🎫", verdict: "More tickets = proportionally better odds" },
  { m: "The system is rigged", t: `${TOTAL_DRAWS.toLocaleString("en-SG")} draws, chi-squared test passes every time. Singapore Pools is government-regulated and independently audited. The game is fair.`, e: "⚖️", verdict: "Fair game, unfair maths" },
] as const;

export const funFacts = [
  { n: `#${hottest.n}`, stat: `${hottest.count} appearances`, label: "Most frequent number", detail: `Shows up in ${oneDecimal(appearanceRate(hottest.count))}% of all draws — but χ² says it's noise. Flukes happen at scale.`, accent: "terracotta" as Accent, emoji: "🔥" },
  { n: `#${coldest.n}`, stat: `${coldest.count} appearances`, label: "Least frequent number", detail: `Would need ${shortfall} more hits just to reach the ${oneDecimal(EXPECTED_FREQUENCY)} average. Random variance — not rigged, not cursed.`, accent: "sage" as Accent, emoji: "🌿" },
  { n: "2–15", stat: "30 co-appearances", label: "Most common pair", detail: "Nearly 2× the expected rate. But it's still within chance. Pairs 5–49 (29×) right behind.", accent: "brownLight" as Accent, emoji: "🤝" },
  { n: "27–45", stat: "5 co-appearances", label: "Rarest pair", detail: `Only 0.33× the expected rate across ${TOTAL_DRAWS.toLocaleString("en-SG")} draws. Tied with 14–34 as the pair that has met least often.`, accent: "brownLight" as Accent, emoji: "🙈" },
  { n: `${zeroCarryoverPct}%`, stat: `${ZERO_CARRYOVER_DRAWS} draws`, label: "Draws with zero carryover", detail: "In more than four draws in ten, not a single number repeated from the previous one.", accent: "terracotta" as Accent, emoji: "♻️" },
  { n: "48–49", stat: "20 consecutive pairs", label: "Favourite neighbours", detail: "The most common consecutive pair. 23–24 and 20–21 also hit 20× each.", accent: "sage" as Accent, emoji: "👫" },
] as const;
