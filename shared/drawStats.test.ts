import { describe, expect, test } from "bun:test";
import {
  draws,
  TOTAL_DRAWS,
  drawsByDay,
  frequencyByNumber,
  EXPECTED_FREQUENCY,
  CHI_SQUARED,
  CHI_SQUARED_THRESHOLD,
  ZERO_CARRYOVER_DRAWS,
  ZERO_CARRYOVER_COMPARABLE,
  FIRST_DRAW_ISO,
  LAST_DRAW_ISO,
  mostFrequent,
  leastFrequent,
  appearanceRate,
  oneDecimal,
} from "./drawStats";
import { frequencyTop, frequencyBottom, maxFreq } from "./totoData";
import * as summary from "./drawStatsSummary";

describe("dataset integrity", () => {
  test("every draw has six distinct main numbers in range", () => {
    for (const draw of draws) {
      expect(draw.winning_numbers).toHaveLength(6);
      expect(new Set(draw.winning_numbers).size).toBe(6);
      for (const n of draw.winning_numbers) {
        expect(n).toBeGreaterThanOrEqual(1);
        expect(n).toBeLessThanOrEqual(49);
      }
    }
  });

  test("the additional number is never one of the main six", () => {
    for (const draw of draws) {
      expect(draw.winning_numbers).not.toContain(draw.additional_number);
    }
  });

  test("draw numbers are contiguous and ascending", () => {
    const first = draws[0]!.draw_no;
    const last = draws[draws.length - 1]!.draw_no;
    expect(last - first + 1).toBe(TOTAL_DRAWS);
  });

  /// The Monday/Thursday split alone is 1,159 and omits 34 Friday special
  /// draws. Quoting that as the dataset size is the drift this file exists
  /// to prevent.
  test("weekday counts add up to the full dataset", () => {
    const summed = Object.values(drawsByDay).reduce((a, b) => a + b, 0);
    expect(summed).toBe(TOTAL_DRAWS);
    expect((drawsByDay.Mon ?? 0) + (drawsByDay.Thu ?? 0)).toBeLessThan(TOTAL_DRAWS);
  });

  test("total main-number appearances equal six per draw", () => {
    const summed = Array.from(frequencyByNumber.values()).reduce((a, b) => a + b, 0);
    expect(summed).toBe(TOTAL_DRAWS * 6);
  });

  test("all 49 numbers have been drawn at least once", () => {
    expect(frequencyByNumber.size).toBe(49);
    for (const count of frequencyByNumber.values()) expect(count).toBeGreaterThan(0);
  });
});

describe("fairness", () => {
  test("expected appearances per number is draws x 6 / 49", () => {
    expect(EXPECTED_FREQUENCY).toBeCloseTo((TOTAL_DRAWS * 6) / 49, 6);
  });

  test("chi-squared is below the 5% critical value for 48 degrees of freedom", () => {
    expect(CHI_SQUARED).toBeLessThan(CHI_SQUARED_THRESHOLD);
  });

  test("chi-squared matches the figure published on the site", () => {
    expect(CHI_SQUARED).toBeCloseTo(38.18, 2);
  });
});

describe("frequency tables", () => {
  test("hottest and coldest numbers", () => {
    expect(mostFrequent(1)[0]).toEqual({ n: "15", count: 175 });
    expect(leastFrequent(1)[0]).toEqual({ n: "45", count: 118 });
  });

  test("top table is descending, bottom table ascending", () => {
    const top = mostFrequent(5);
    const bottom = leastFrequent(5);
    for (let i = 1; i < top.length; i++) expect(top[i]!.count).toBeLessThanOrEqual(top[i - 1]!.count);
    for (let i = 1; i < bottom.length; i++) {
      expect(bottom[i]!.count).toBeGreaterThanOrEqual(bottom[i - 1]!.count);
    }
  });

  test("the two tables never share a number", () => {
    const top = new Set(mostFrequent(5).map(e => e.n));
    for (const entry of leastFrequent(5)) expect(top.has(entry.n)).toBe(false);
  });

  /// The site imports a generated summary rather than the raw history, to
  /// keep 1,193 draws out of the browser bundle. These assertions are what
  /// stops that summary going stale: regenerate with
  /// `bun run shared/scripts/generateStatsSummary.ts`.
  test("the generated summary still matches the dataset", () => {
    expect(frequencyTop).toEqual(mostFrequent(5));
    expect(frequencyBottom).toEqual(leastFrequent(5));
    expect(maxFreq).toBe(mostFrequent(1)[0]!.count);
    expect(summary.TOTAL_DRAWS).toBe(TOTAL_DRAWS);
    expect(summary.CHI_SQUARED).toBeCloseTo(CHI_SQUARED, 9);
    expect(summary.EXPECTED_FREQUENCY).toBeCloseTo(EXPECTED_FREQUENCY, 9);
    expect(summary.ZERO_CARRYOVER_DRAWS).toBe(ZERO_CARRYOVER_DRAWS);
    expect(summary.ZERO_CARRYOVER_COMPARABLE).toBe(ZERO_CARRYOVER_COMPARABLE);
    expect(summary.drawsByDay).toEqual(drawsByDay);
    expect(summary.FIRST_DRAW_ISO).toBe(FIRST_DRAW_ISO);
    expect(summary.LAST_DRAW_ISO).toBe(LAST_DRAW_ISO);
  });
});

describe("published figures", () => {
  test("zero-carryover count and rate", () => {
    expect(ZERO_CARRYOVER_DRAWS).toBe(498);
    expect(oneDecimal((ZERO_CARRYOVER_DRAWS / ZERO_CARRYOVER_COMPARABLE) * 100)).toBe(41.8);
  });

  test("the hottest number's appearance rate", () => {
    expect(oneDecimal(appearanceRate(175))).toBe(14.7);
  });

  test("appearance rates are a share of the full dataset", () => {
    expect(appearanceRate(TOTAL_DRAWS)).toBeCloseTo(100, 6);
  });
});
