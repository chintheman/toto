// Monte Carlo estimate of each strategy's G3-or-better odds, used to set the
// published `g3` figure in totoData.ts. Slow by design (tens of millions of
// trials), so it is a manual tool rather than part of the test suite:
//
//   bun run shared/scripts/simulateStrategies.ts
//
// G1 and G2 are NOT simulated here. Both are exact in closed form — see the
// comment above `exactG1`/`exactG2` in totoData.ts — and an earlier version
// of this script simulated them anyway, which is how "1k" ended up
// publishing G2 at 1 in 21.7K against an analytic ceiling of 1 in 23.3K:
// a rare event (~4.3e-5 per combo) accumulates only a few hundred hits
// across millions of trials, and that few hundred carries several percent
// of sampling noise — enough to land outside a hard bound by chance.
//
// G3 has no such shortcut. System-bet entries share numbers across their
// C(k,6) sub-lines, so one well-matched System 7 can produce several
// simultaneous G3-or-better hits from a single draw — real, verified
// correlation that pulls the true rate well below what a naive per-combo
// sum would suggest. There is no closed form for that without modelling
// the exact deal pattern, so it stays a Monte Carlo estimate.
import { generatePortfolio, type StrategyKey } from "../ticketGenerator";
import { strats, TOTAL_COMBINATIONS } from "../totoData";

function subsets6(a: number[]): number[][] {
  if (a.length === 6) return [a];
  const o: number[][] = [];
  for (let s = 0; s < a.length; s++) o.push(a.filter((_, i) => i !== s));
  return o;
}
// Group 1: all 6 main match. Group 2: 5 main + the additional number.
// Group 3: 5 main, no additional. Below 3 main matches, nothing pays.
function group(mainMatches: number, hitAdditional: boolean): number | null {
  if (mainMatches === 6) return 1;
  if (mainMatches === 5) return hitAdditional ? 2 : 3;
  return null;
}
function randomDraw(): { main: Set<number>; add: number } {
  const pool = Array.from({ length: 49 }, (_, i) => i + 1);
  for (let i = 48; i > 0; i--) {
    const j = (Math.random() * (i + 1)) | 0;
    [pool[i], pool[j]] = [pool[j]!, pool[i]!];
  }
  return { main: new Set(pool.slice(0, 6)), add: pool[6]! };
}
function ci(hits: number, n: number): string {
  if (hits === 0) return `none in ${n.toLocaleString()}`;
  const p = hits / n;
  const se = Math.sqrt((p * (1 - p)) / n);
  const lo = 1 / (p + 1.96 * se);
  const hi = 1 / Math.max(p - 1.96 * se, 1e-12);
  return `1 in ${Math.round(1 / p).toLocaleString()}  [${Math.round(lo).toLocaleString()}–${hi > 1e7 ? "inf" : Math.round(hi).toLocaleString()}]`;
}

const PORTFOLIOS = 500;
const DRAWS_EACH = 40_000;
const keys: StrategyKey[] = ["1k", "100k", "mega"];

console.log(`Simulation: ${PORTFOLIOS} portfolios x ${DRAWS_EACH.toLocaleString()} random draws = ${(PORTFOLIOS * DRAWS_EACH).toLocaleString()} trials each\n`);

for (const key of keys) {
  const combos = generatePortfolio(key, 1).tickets.flatMap(t => subsets6(t.numbers)).length;
  let trials = 0;
  let any = 0;
  let atLeastG3 = 0;

  for (let seed = 1; seed <= PORTFOLIOS; seed++) {
    const lines = generatePortfolio(key, seed).tickets.flatMap(t => subsets6(t.numbers));
    for (let d = 0; d < DRAWS_EACH; d++) {
      const { main, add } = randomDraw();
      let won = false;
      let reachedG3 = false;
      for (const line of lines) {
        let matches = 0;
        for (const n of line) if (main.has(n)) matches++;
        if (matches < 3) continue;
        won = true;
        const g = group(matches, line.includes(add));
        if (g !== null && g <= 3) reachedG3 = true;
      }
      trials++;
      if (won) any++;
      if (reachedG3) atLeastG3++;
    }
  }

  const st = strats[key];
  const exactG1 = `1 in ${Math.round(TOTAL_COMBINATIONS / combos).toLocaleString()}`;
  const exactG2 = `1 in ${(TOTAL_COMBINATIONS / (6 * combos) / 1000).toFixed(1)}K`;
  console.log(`${st.name} (${key}, N=${combos} distinct combos)  —  ${st.m}`);
  console.log(`  any prize        : published ${st.any.padStart(6)}  |  simulated ${((any / trials) * 100).toFixed(1)}%`);
  console.log(`  G1 (exact)       : published ${st.g1.padStart(10)}  |  analytic  ${exactG1}`);
  console.log(`  G2 (exact)       : published ${st.g2.padStart(10)}  |  analytic  ${exactG2}`);
  console.log(`  G1-or-G2-or-G3   : published ${st.g3.padStart(10)}  |  simulated ${ci(atLeastG3, trials)}`);
  console.log();
}
