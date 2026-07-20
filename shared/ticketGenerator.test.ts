import { describe, expect, test } from "bun:test";
import { generatePortfolio, type StrategyKey } from "./ticketGenerator";
import { strats } from "./totoData";

const GOALS: StrategyKey[] = ["1k", "100k", "mega"];

describe("generatePortfolio", () => {
  test.each(GOALS)("%s: cost matches the strategy card", goal => {
    expect(generatePortfolio(goal, 42).cost).toBe(strats[goal].cost);
  });

  test.each(GOALS)("%s: tickets are valid (size, uniqueness, range)", goal => {
    for (const t of generatePortfolio(goal, 7).tickets) {
      expect(t.numbers.length).toBe(t.type === "S7" ? 7 : 6);
      expect(new Set(t.numbers).size).toBe(t.numbers.length);
      for (const n of t.numbers) {
        expect(n).toBeGreaterThanOrEqual(1);
        expect(n).toBeLessThanOrEqual(49);
      }
      const sorted = [...t.numbers].sort((a, b) => a - b);
      expect(t.numbers).toEqual(sorted);
    }
  });

  test("1k: the 12 System 7 tickets cover all 49 numbers", () => {
    for (const seed of [1, 2, 3, 99, 12345]) {
      const p = generatePortfolio("1k", seed);
      const s7 = p.tickets.filter(t => t.type === "S7");
      expect(s7.length).toBe(12);
      expect(new Set(s7.flatMap(t => t.numbers)).size).toBe(49);
    }
  });

  test("mega: 14-number pool, every ticket drawn from it", () => {
    const p = generatePortfolio("mega", 11);
    expect(p.pool).not.toBeNull();
    expect(p.pool!.length).toBe(14);
    expect(new Set(p.pool!).size).toBe(14);
    const pool = new Set(p.pool!);
    for (const t of p.tickets) {
      for (const n of t.numbers) expect(pool.has(n)).toBe(true);
    }
  });

  test("non-mega portfolios have no pool", () => {
    expect(generatePortfolio("1k", 5).pool).toBeNull();
    expect(generatePortfolio("100k", 5).pool).toBeNull();
  });

  test("same seed reproduces, different seed varies", () => {
    const a = generatePortfolio("1k", 123);
    const b = generatePortfolio("1k", 123);
    const c = generatePortfolio("1k", 124);
    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
    expect(JSON.stringify(a)).not.toBe(JSON.stringify(c));
  });

  test("spread strategies keep mean pairwise overlap low", () => {
    for (const seed of [1, 2, 3]) {
      // 100 tickets over 49 numbers: even spread keeps mean overlap near
      // the theoretical floor (~0.75); flag anything drifting past 1.5.
      expect(generatePortfolio("1k", seed).meanOverlap).toBeLessThan(1.5);
      expect(generatePortfolio("100k", seed).meanOverlap).toBeLessThan(1.5);
    }
  });
});
