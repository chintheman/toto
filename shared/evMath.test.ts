import { describe, expect, test } from "bun:test";
import {
  TOTAL_COMBINATIONS,
  NON_JACKPOT_RETURN_PER_DOLLAR,
  nCr,
  evPerDollar,
  evAtJackpot,
  breakEvenJackpot,
  probabilityAnyPrize,
  probabilityJackpot,
  ordinaryGroupProbabilities,
} from "./evMath";

describe("nCr", () => {
  test("matches known binomial coefficients", () => {
    expect(nCr(49, 6)).toBe(TOTAL_COMBINATIONS);
    expect(nCr(7, 6)).toBe(7);
    expect(nCr(9, 6)).toBe(84);
    expect(nCr(6, 6)).toBe(1);
  });

  test("returns 0 for impossible choices", () => {
    expect(nCr(5, 6)).toBe(0);
    expect(nCr(6, -1)).toBe(0);
  });
});

describe("group probabilities", () => {
  test("covers all seven Singapore TOTO prize groups", () => {
    const groups = ordinaryGroupProbabilities().map(g => g.group);
    expect(groups).toEqual([1, 2, 3, 4, 5, 6, 7]);
  });

  test("jackpot probability is 1 in C(49,6)", () => {
    const g1 = ordinaryGroupProbabilities().find(g => g.group === 1)!;
    expect(g1.probability).toBeCloseTo(1 / TOTAL_COMBINATIONS, 12);
  });

  test("G2 is exactly six times more likely than the jackpot", () => {
    const [g1, g2] = [1, 2].map(n => ordinaryGroupProbabilities().find(g => g.group === n)!);
    expect(g2.probability / g1.probability).toBeCloseTo(6, 9);
  });

  test("P(any prize) for an Ordinary ticket reproduces the published 1.86%", () => {
    // Singapore Pools publishes 1 in 54 (~1.86%) for a $1 Ordinary ticket.
    expect(probabilityAnyPrize(6)).toBeCloseTo(0.0186, 4);
  });

  test("P(jackpot) for an Ordinary ticket is 1 in 13,983,816", () => {
    expect(probabilityJackpot(6)).toBeCloseTo(1 / TOTAL_COMBINATIONS, 12);
  });

  test("a System 7 covers seven combinations' worth of jackpot odds", () => {
    expect(probabilityJackpot(7)).toBeCloseTo(7 / TOTAL_COMBINATIONS, 12);
  });
});

describe("expected value", () => {
  test("non-jackpot return is about 34 cents per dollar", () => {
    expect(NON_JACKPOT_RETURN_PER_DOLLAR).toBeCloseTo(0.3399, 4);
  });

  test("EV is negative at every jackpot the site charts", () => {
    for (const millions of [1, 2, 2.5, 3.5, 4.5, 6, 8]) {
      expect(evAtJackpot(millions)).toBeLessThan(0);
    }
  });

  test("EV matches the derivation at reference jackpots", () => {
    expect(evAtJackpot(2.5)).toBeCloseTo(-48.1, 1);
    expect(evAtJackpot(4.5)).toBeCloseTo(-33.8, 1);
    expect(evAtJackpot(8)).toBeCloseTo(-8.8, 1);
  });

  test("break-even sits above $9M, far beyond the site's old $4.2M claim", () => {
    const breakEven = breakEvenJackpot();
    expect(breakEven).toBeCloseTo(9_230_552, -2);
    expect(breakEven).toBeGreaterThan(9_000_000);
  });

  test("EV crosses 1.0 exactly at the break-even jackpot", () => {
    expect(evPerDollar(breakEvenJackpot())).toBeCloseTo(1, 9);
  });

  test("EV increases monotonically with jackpot size", () => {
    const points = [1, 2, 3, 5, 8, 12].map(m => evAtJackpot(m));
    for (let i = 1; i < points.length; i++) {
      expect(points[i]!).toBeGreaterThan(points[i - 1]!);
    }
  });
});
