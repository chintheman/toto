import type { strats } from "./totoData";

export type StrategyKey = keyof typeof strats;

export interface Ticket {
  type: "S7" | "ORD"; // System 7 ($7, 7 numbers) or Ordinary ($1, 6 numbers)
  numbers: number[]; // sorted ascending
}

export interface Portfolio {
  goal: StrategyKey;
  tickets: Ticket[];
  cost: number; // $1 per combination: S7 = $7, ORD = $1
  meanOverlap: number; // mean pairwise shared numbers across tickets
  pool: number[] | null; // the 14-number pool for "mega", null otherwise
}

const ALL_NUMBERS = Array.from({ length: 49 }, (_, i) => i + 1);

// Deterministic PRNG (mulberry32) so a seed reproduces the same portfolio.
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffle<T>(source: readonly T[], rand: () => number): T[] {
  const arr = [...source];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    const tmp = arr[i] as T;
    arr[i] = arr[j] as T;
    arr[j] = tmp;
  }
  return arr;
}

// Deal `count` tickets of `size` numbers from `pool`, drawing from a
// shuffled deck that refills when it runs out. Every pool number is used
// once before any repeats, which spreads numbers as evenly as possible
// across tickets — the even-overlap criterion from Liu, Liu & Teo (2024).
function dealTickets(count: number, size: number, pool: readonly number[], rand: () => number): number[][] {
  const tickets: number[][] = [];
  let deck: number[] = [];
  for (let t = 0; t < count; t++) {
    const ticket: number[] = [];
    while (ticket.length < size) {
      if (deck.length === 0) deck = shuffle(pool, rand);
      const idx = deck.findIndex(n => !ticket.includes(n));
      if (idx === -1) {
        // Deck only holds numbers already in this ticket: force a refill.
        deck = [];
        continue;
      }
      ticket.push(...deck.splice(idx, 1));
    }
    tickets.push(ticket.sort((a, b) => a - b));
  }
  return tickets;
}

function meanPairwiseOverlap(tickets: number[][]): number {
  let total = 0;
  let pairs = 0;
  for (let i = 0; i < tickets.length; i++) {
    const set = new Set(tickets[i]);
    for (let j = i + 1; j < tickets.length; j++) {
      total += (tickets[j] ?? []).filter(n => set.has(n)).length;
      pairs++;
    }
  }
  return pairs ? total / pairs : 0;
}

export function generatePortfolio(goal: StrategyKey, seed: number): Portfolio {
  const rand = mulberry32(seed);
  let sys: number[][];
  let ord: number[][];
  let pool: number[] | null = null;

  if (goal === "mega") {
    // Jackpot or Bust: everything concentrated in one 14-number pool.
    pool = shuffle(ALL_NUMBERS, rand).slice(0, 14).sort((a, b) => a - b);
    sys = dealTickets(7, 7, pool, rand);
    ord = dealTickets(5, 6, pool, rand);
  } else if (goal === "1k") {
    // Pure Spread: 100x Ordinary, no System bets at all. Simulation showed
    // System-7 sub-lines correlate (one well-matched entry can light up
    // several of its own sub-lines on the same draw), which pulls down the
    // any-prize and G3-or-better rates versus fully independent lines. At
    // the same 100-combo cost, zero System bets measured 86.5% any-prize
    // and 1-in-~540 for G3-or-better, against 51.8%/1-in-948 for the old
    // 12xSystem7+16xOrdinary mix this replaces. G1 and G2 are unaffected —
    // both depend only on combo count, never on how combos are packaged.
    sys = [];
    ord = dealTickets(100, 6, ALL_NUMBERS, rand);
  } else {
    // G2 Hunter: 10× System 7 + 30× Ordinary across all 49 numbers.
    sys = dealTickets(10, 7, ALL_NUMBERS, rand);
    ord = dealTickets(30, 6, ALL_NUMBERS, rand);
  }

  const tickets: Ticket[] = [
    ...sys.map(numbers => ({ type: "S7" as const, numbers })),
    ...ord.map(numbers => ({ type: "ORD" as const, numbers })),
  ];

  return {
    goal,
    tickets,
    pool,
    cost: sys.length * 7 + ord.length,
    meanOverlap: meanPairwiseOverlap(tickets.map(t => t.numbers)),
  };
}
