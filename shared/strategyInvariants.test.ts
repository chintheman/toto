// Property-based checks on the published strategy odds. These exist because
// the odds previously broke Boole's inequality: a Monte Carlo run landed
// outside a hard analytic bound (a few hundred hits on a rare event carries
// enough sampling noise to cross it), and nothing caught it before a human
// reviewer did by hand. A single reference computation checked against
// itself can't catch this class of bug — these tests check the published
// numbers against independent mathematical constraints instead.
import { describe, expect, test } from "bun:test";
import {
  strats,
  TOTAL_COMBINATIONS,
  SPREAD_ANY_PRIZE,
  SPREAD_ANY_PRIZE_CEILING,
  CONCENTRATED_ANY_PRIZE,
  SYSTEM_9_COMBOS,
  SYSTEM_7_COUNT_FOR_EQUAL_COST,
} from "./totoData";
import { generatePortfolio, type StrategyKey } from "./ticketGenerator";
import { probabilityAnyPrize, nCr } from "./evMath";

function subsets6(a: readonly number[]): number[][] {
  if (a.length === 6) return [a as number[]];
  const out: number[][] = [];
  for (let skip = 0; skip < a.length; skip++) out.push(a.filter((_, i) => i !== skip));
  return out;
}

function distinctComboCount(key: StrategyKey): number {
  const combos = generatePortfolio(key, 1).tickets.flatMap(t => subsets6(t.numbers));
  return new Set(combos.map(c => c.join(","))).size;
}

function parseOneIn(label: string): number {
  const match = label.match(/1 in ([\d,.]+)(K)?/);
  if (!match) throw new Error(`Can't parse odds label: ${label}`);
  const n = Number.parseFloat(match[1]!.replace(/,/g, ""));
  return match[2] === "K" ? n * 1000 : n;
}

const STRATEGY_KEYS = Object.keys(strats) as StrategyKey[];

describe("portfolio structure", () => {
  test("every strategy's dollar cost equals its distinct combination count", () => {
    // $1 per combination always. If this ever breaks, exactG1/exactG2 in
    // totoData.ts are silently wrong, since they use `cost` as N.
    for (const key of STRATEGY_KEYS) {
      expect(distinctComboCount(key)).toBe(strats[key].cost);
    }
  });
});

describe("G1 and G2 are exact, never simulated", () => {
  // A G1 or G2 win can only ever be produced by one specific combination
  // per draw, so these have closed forms and admit zero tolerance —
  // unlike G3, where system-bet sub-lines correlate and only a Monte Carlo
  // estimate is possible.
  test("G1 equals combos / 13,983,816, within display rounding", () => {
    for (const key of STRATEGY_KEYS) {
      const n = strats[key].cost;
      const exact = TOTAL_COMBINATIONS / n;
      expect(Math.abs(parseOneIn(strats[key].g1) - exact) / exact).toBeLessThan(0.005);
    }
  });

  test("G2 equals combos * 6 / 13,983,816, within display rounding", () => {
    for (const key of STRATEGY_KEYS) {
      const n = strats[key].cost;
      const exact = TOTAL_COMBINATIONS / (6 * n);
      expect(Math.abs(parseOneIn(strats[key].g2) - exact) / exact).toBeLessThan(0.005);
    }
  });

  test("two strategies with equal combo counts have identical G1 and G2", () => {
    // "1k" and "100k" both buy 100 distinct combos for $100. G1 and G2
    // depend only on combo count, not on how the combos are packaged, so
    // a strategy tag claiming one has "better G2 odds" than the other is
    // asserting a difference that cannot exist.
    const withHundredCombos = STRATEGY_KEYS.filter(k => strats[k].cost === 100);
    expect(withHundredCombos.length).toBeGreaterThanOrEqual(2);
    const [first, ...rest] = withHundredCombos;
    for (const key of rest) {
      expect(strats[key]!.g1).toBe(strats[first!]!.g1);
      expect(strats[key]!.g2).toBe(strats[first!]!.g2);
    }
  });
});

describe("Boole's inequality — a portfolio can never beat the union bound", () => {
  // P(at least one of N distinct combos hits group g) <= N * P(single combo
  // hits g). This holds regardless of correlation between combos — Boole's
  // inequality is not an approximation, it's always true. A published
  // figure that beats this bound is not "optimistic," it's impossible.
  const WAYS: Record<number, number> = { 1: 1, 2: 6, 3: 252 };

  test("G1 respects its own bound with equality (no correlation possible)", () => {
    for (const key of STRATEGY_KEYS) {
      const n = strats[key].cost;
      const publishedP = 1 / parseOneIn(strats[key].g1);
      const ceiling = (n * WAYS[1]!) / TOTAL_COMBINATIONS;
      expect(publishedP).toBeLessThanOrEqual(ceiling * 1.001);
    }
  });

  test("G2 respects its own bound with equality (no correlation possible)", () => {
    for (const key of STRATEGY_KEYS) {
      const n = strats[key].cost;
      const publishedP = 1 / parseOneIn(strats[key].g2);
      const ceiling = (n * WAYS[2]!) / TOTAL_COMBINATIONS;
      expect(publishedP).toBeLessThanOrEqual(ceiling * 1.001);
    }
  });

  test("G1-or-better (g3 field) never beats the union bound", () => {
    // Real correlation between System-bet sub-lines pulls the true rate
    // below this ceiling — the published figure should sit comfortably
    // under it, not near it and never over it.
    for (const key of STRATEGY_KEYS) {
      const n = strats[key].cost;
      const publishedP = 1 / parseOneIn(strats[key].g3);
      const ceiling = (n * (WAYS[1]! + WAYS[2]! + WAYS[3]!)) / TOTAL_COMBINATIONS;
      expect(publishedP).toBeLessThanOrEqual(ceiling * 1.001);
    }
  });
});

describe("the $84 spread-vs-concentration figures quoted in site copy", () => {
  // These lived as prose in App.tsx ("~49% vs ~22%") where no test could see
  // them. Both were wrong, and the spread figure was not just optimistic but
  // impossible — 49% sits above the union bound for 12 System 7s. Moving them
  // into totoData.ts is only half the fix; this is the half that keeps them
  // honest.
  test("both portfolios really do cost the same $84", () => {
    expect(SYSTEM_9_COMBOS).toBe(nCr(9, 6));
    expect(SYSTEM_7_COUNT_FOR_EQUAL_COST * nCr(7, 6)).toBe(SYSTEM_9_COMBOS);
  });

  test("the spread figure never beats the union bound", () => {
    // P(at least one of 12 System 7s pays) <= 12 x P(one System 7 pays).
    // True regardless of how the 12 tickets overlap.
    expect(SPREAD_ANY_PRIZE).toBeLessThanOrEqual(SPREAD_ANY_PRIZE_CEILING);
    expect(SPREAD_ANY_PRIZE_CEILING).toBeCloseTo(12 * probabilityAnyPrize(7) * 100, 6);
  });

  test("the concentrated figure is exact, not a backtest", () => {
    // A System 9 pays iff >=3 of the 6 winners fall inside its 9 numbers —
    // closed form, so this admits no sampling tolerance at all.
    expect(CONCENTRATED_ANY_PRIZE).toBe(probabilityAnyPrize(9) * 100);
  });

  test("spread still beats concentration, which is the whole claim", () => {
    expect(SPREAD_ANY_PRIZE).toBeGreaterThan(CONCENTRATED_ANY_PRIZE);
  });
});

describe("pool-constrained strategies can't out-win their own pool", () => {
  // "mega" draws every ticket from a 14-number pool, so it cannot win
  // anything unless at least 3 of the 6 winning numbers land inside those
  // 14 — an exact ceiling on its any-prize rate, independent of how the
  // tickets are dealt. Nothing checked this before.
  test("mega's any-prize rate stays under its 14-number containment bound", () => {
    const pool = generatePortfolio("mega", 1).pool;
    expect(pool).not.toBeNull();
    const ceiling = probabilityAnyPrize(pool!.length) * 100;
    const published = Number.parseFloat(strats.mega.any);
    expect(published).toBeLessThanOrEqual(ceiling);
  });
});

describe("Singapore Pools published odds, as literal fixtures", () => {
  // Not derived from this codebase's own model — an external anchor. If
  // this drifts, the model itself is wrong, not just a specific figure.
  test("a single Ordinary ticket's any-prize odds match the published 1.86%", () => {
    expect(probabilityAnyPrize(6)).toBeCloseTo(0.0186, 3);
  });
});

describe("EV is a property of spend, not of packaging", () => {
  // At equal spend, every portfolio of distinct combinations has identical
  // expected value: EV is linear, so it can't depend on how combos are
  // grouped into System bets versus Ordinary tickets. Any two same-cost
  // strategies should have equal G1 and G2 (already covered above) and this
  // states the general principle the "best odds" copy used to violate.
  test("equal-cost strategies buy equal jackpot exposure", () => {
    const byCost = new Map<number, StrategyKey[]>();
    for (const key of STRATEGY_KEYS) {
      const list = byCost.get(strats[key].cost) ?? [];
      list.push(key);
      byCost.set(strats[key].cost, list);
    }
    for (const [, keys] of byCost) {
      if (keys.length < 2) continue;
      const combos = keys.map(k => distinctComboCount(k));
      expect(new Set(combos).size).toBe(1);
    }
  });
});
