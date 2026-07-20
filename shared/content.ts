// Editorial content shared by the site and the iOS app. `accent` keys map
// to the shared palette (see palette.ts) so each surface resolves colors
// through its own theme import.

export type Accent = "terracotta" | "sage" | "brownLight";

export const myths = [
  { m: "Hot numbers win more", t: "Statistically? Nope. χ² (a test that checks if patterns are real or just random noise) comes out at 38.18 — well below the 65.17 threshold that would mean something's actually going on. Every number has the same odds, always.", e: "🎲", verdict: "Pure gambler's fallacy" },
  { m: "Cold numbers are 'due'", t: "Number 45 hasn't appeared in 200 draws? It still has the same ~12.2% chance this draw as #15 does. Draws have no memory.", e: "🧊", verdict: "The lottery doesn't owe you anything" },
  { m: "Bigger systems = better odds", t: "1× System 9 covers 84 combos across 9 numbers. 12× System 7 covers 84 combos across 49. Same spend — dramatically different coverage.", e: "📊", verdict: "Spread beats concentration" },
  { m: "Past patterns predict the future", t: "13,983,816 combinations. No memory. No momentum. The only pattern is that there is no pattern.", e: "🔮", verdict: "Not how probability works" },
  { m: "Monday and Thursday draws differ", t: "596 Mon vs 563 Thu draws analysed. Biggest frequency gap was #46 at 11.1% Mon vs 16.5% Thu. Statistically meaningless after correction.", e: "📅", verdict: "Noise, not signal" },
  { m: "Buying more tickets doesn't help", t: "It does — linearly. 100 tickets = 100/13,983,816 = 1 in 139,838 jackpot chance. Still a lottery, just slightly less hopeless.", e: "🎫", verdict: "More tickets = proportionally better odds" },
  { m: "The system is rigged", t: "1,000+ draws, chi-squared test passes every time. Singapore Pools is government-regulated and independently audited. The game is fair.", e: "⚖️", verdict: "Fair game, unfair maths" },
] as const;

export const funFacts = [
  { n: "#15", stat: "175 appearances", label: "Most frequent number", detail: "Shows up in 14.7% of all draws — but χ² says it's noise. Flukes happen at scale.", accent: "terracotta" as Accent, emoji: "🔥" },
  { n: "#45", stat: "119 appearances", label: "Least frequent number", detail: "Would need 27 more hits just to reach average. Random variance — not rigged, not cursed.", accent: "sage" as Accent, emoji: "🌿" },
  { n: "2–15", stat: "30 co-appearances", label: "Most common pair", detail: "Nearly 2× the expected rate. But it's still within chance. Pairs 5–49 (29×) right behind.", accent: "brownLight" as Accent, emoji: "🤝" },
  { n: "27–45", stat: "5 co-appearances", label: "Rarest pair", detail: "Only 0.33× the expected rate across 1,000+ draws. These two simply haven't met.", accent: "brownLight" as Accent, emoji: "🙈" },
  { n: "41.8%", stat: "498 draws", label: "Draws with zero carryover", detail: "In nearly half of all draws, not a single number repeated from the previous one.", accent: "terracotta" as Accent, emoji: "♻️" },
  { n: "48–49", stat: "20 consecutive pairs", label: "Favourite neighbours", detail: "The most common consecutive pair. 23–24 and 20–21 also hit 20× each.", accent: "sage" as Accent, emoji: "👫" },
] as const;
