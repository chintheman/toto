// TOTO 6/49 probability + expected-value math, shared by the site, the
// video and the API so every surface quotes the same numbers.
//
// This is a direct port of ios/TotoApp/Features/Calculator/EVMath.swift,
// which is the project's authoritative model and carries its own test
// suite (ios/TotoAppTests/EVMathTests.swift). Keep the two in sync: if you
// change a prize constant or a probability here, change it there too.
//
// CALIBRATION NOTE (carried over from the Swift original): the
// combinatorial probabilities are exact and reproduce Singapore Pools'
// published Ordinary-ticket odds (1.86% chance of any prize). The
// pari-mutuel prize AMOUNTS for Groups 2-4 are reference midpoints, not
// live payouts — real payouts depend on ticket-sales data the project has
// not backfilled yet. EV figures derived here are therefore approximate in
// magnitude, but the sign and rough scale are solid.

// C(49,6) — total combinations; jackpot odds for N distinct combos = N in this.
export const TOTAL_COMBINATIONS = 13_983_816;

/** Binomial coefficient. Returns 0 when the choice is impossible. */
export function nCr(n: number, r: number): number {
  if (r < 0 || n < 0 || r > n) return 0;
  const k = Math.min(r, n - r);
  let result = 1;
  for (let i = 0; i < k; i++) {
    result = (result * (n - i)) / (i + 1);
  }
  return Math.round(result);
}

/** Fixed (G5-G7) and reference-midpoint (G2-G4) prize amounts, in dollars. */
export const PRIZE_ESTIMATE = {
  g2Typical: 121_410,
  g3Typical: 1_612,
  g4Typical: 391,
  g5Fixed: 50,
  g6Fixed: 25,
  g7Fixed: 10,
} as const;

// Singapore TOTO prize groups: G1 = 6 main, G2 = 5 main + additional,
// G3 = 5 main, G4 = 4 main + additional, G5 = 4 main, G6 = 3 main +
// additional, G7 = 3 main.
const GROUP_SHAPES: readonly { group: number; main: number; additional: number }[] = [
  { group: 1, main: 6, additional: 0 },
  { group: 2, main: 5, additional: 1 },
  { group: 3, main: 5, additional: 0 },
  { group: 4, main: 4, additional: 1 },
  { group: 5, main: 4, additional: 0 },
  { group: 6, main: 3, additional: 1 },
  { group: 7, main: 3, additional: 0 },
];

/**
 * Exact per-group hit probabilities for a SINGLE Ordinary ($1) ticket,
 * over the 6 winning / 1 additional / 42 other split.
 */
export function ordinaryGroupProbabilities(): { group: number; probability: number }[] {
  return GROUP_SHAPES.map(({ group, main, additional }) => ({
    group,
    probability:
      (nCr(6, main) * nCr(1, additional) * nCr(42, 6 - main - additional)) / TOTAL_COMBINATIONS,
  }));
}

function prizeForGroup(group: number, jackpot: number): number {
  switch (group) {
    case 1: return jackpot;
    case 2: return PRIZE_ESTIMATE.g2Typical;
    case 3: return PRIZE_ESTIMATE.g3Typical;
    case 4: return PRIZE_ESTIMATE.g4Typical;
    case 5: return PRIZE_ESTIMATE.g5Fixed;
    case 6: return PRIZE_ESTIMATE.g6Fixed;
    case 7: return PRIZE_ESTIMATE.g7Fixed;
    default: return 0;
  }
}

/**
 * Expected return per $1 staked, excluding the jackpot term. Constant with
 * respect to jackpot size, so break-even solves in closed form.
 */
export const NON_JACKPOT_RETURN_PER_DOLLAR = ordinaryGroupProbabilities()
  .filter(entry => entry.group !== 1)
  .reduce((total, entry) => total + entry.probability * prizeForGroup(entry.group, 0), 0);

/** P(jackpot) for a single Ordinary combination. */
export const JACKPOT_PROBABILITY = 1 / TOTAL_COMBINATIONS;

/**
 * Expected value per dollar staked at a given jackpot, in dollars.
 * 1.0 = break-even, above 1.0 = +EV.
 */
export function evPerDollar(jackpotDollars: number): number {
  return NON_JACKPOT_RETURN_PER_DOLLAR + jackpotDollars * JACKPOT_PROBABILITY;
}

/** Expected value as a percentage swing, e.g. -33.8 means you lose 33.8c per $1. */
export function evAtJackpot(millions: number): number {
  return (evPerDollar(millions * 1_000_000) - 1) * 100;
}

/** The jackpot size, in dollars, at which a ticket crosses from -EV to +EV. */
export function breakEvenJackpot(): number {
  return (1 - NON_JACKPOT_RETURN_PER_DOLLAR) / JACKPOT_PROBABILITY;
}

/**
 * P(any prize) for a bet choosing N numbers. You win at least one prize iff
 * your N-number pool contains at least 3 of the 6 winning numbers.
 */
export function probabilityAnyPrize(numbersChosen: number): number {
  const total = nCr(49, numbersChosen);
  if (total === 0) return 0;
  let below = 0;
  for (let matches = 0; matches < 3; matches++) {
    below += nCr(6, matches) * nCr(43, numbersChosen - matches);
  }
  return 1 - below / total;
}

/** P(jackpot) for a bet choosing N numbers: C(43, N-6) / C(49, N). */
export function probabilityJackpot(numbersChosen: number): number {
  const total = nCr(49, numbersChosen);
  if (total === 0) return 0;
  return nCr(43, numbersChosen - 6) / total;
}

/**
 * Per-group probability for a portfolio of `combos` distinct combinations,
 * scaled from the single-combination distribution.
 *
 * APPROXIMATION: this is the same simplification the Swift original applies
 * to system bets — it scales the per-combination distribution by combination
 * count rather than solving which sub-ticket lands in which group. It is
 * directionally right and exact for the jackpot term (distinct combinations
 * are mutually exclusive jackpot winners), but it overstates the smaller
 * groups slightly for system bets, whose sub-tickets share numbers.
 */
export function portfolioGroupOdds(combos: number): { group: number; oneIn: number }[] {
  return ordinaryGroupProbabilities().map(({ group, probability }) => ({
    group,
    oneIn: 1 / (probability * combos),
  }));
}
