import { useState, useEffect } from "react";
import { computeNextDraw, FALLBACK_JACKPOT, type NextDraw } from "../../shared/drawSchedule";

const REFRESH_MS = 60000;

export interface DrawInfo {
  day: string;
  date: string;
  jackpot: string;
  /** False while showing the placeholder jackpot, so the UI can avoid
   *  presenting a hardcoded constant as a live figure. */
  jackpotIsLive: boolean;
}

interface DrawApiPayload {
  next?: { day?: unknown; date?: unknown; iso?: unknown };
  jackpot?: unknown;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.length > 0;
}

export function useNextDraw(): DrawInfo {
  const [next, setNext] = useState<NextDraw>(() => computeNextDraw());
  const [jackpot, setJackpot] = useState(FALLBACK_JACKPOT);
  const [jackpotIsLive, setJackpotIsLive] = useState(false);
  // The server's own view of the next draw, when it gives us one. Preferred
  // over the local computation, which is at the mercy of the device clock.
  const [serverDraw, setServerDraw] = useState<{ day: string; date: string } | null>(null);

  useEffect(() => {
    const controller = new AbortController();

    const load = () => {
      fetch("/api/toto/draw", { signal: controller.signal })
        .then(r => (r.ok ? (r.json() as Promise<DrawApiPayload>) : null))
        .then(data => {
          if (!data) return;
          if (isNonEmptyString(data.jackpot)) {
            setJackpot(data.jackpot);
            setJackpotIsLive(true);
          }
          // The API already knows the next draw. Use it rather than
          // recomputing locally and silently disagreeing with the server
          // when the device clock is skewed.
          const day = data.next?.day;
          const date = data.next?.date;
          if (isNonEmptyString(day) && isNonEmptyString(date)) {
            // The API sends date as "Thu 24 Jul 2026"; strip the leading day
            // so it does not render twice next to `day`.
            const withoutDay = date.startsWith(`${day} `) ? date.slice(day.length + 1) : date;
            setServerDraw({ day, date: withoutDay });
          }
        })
        .catch(() => {
          // API unreachable (dev server, offline): keep the local fallback.
        });
    };

    load();
    // Refresh the jackpot on the same cadence as the date below. Previously
    // the jackpot fetched once on mount while the date recomputed every
    // minute, so a long-lived tab showed a fresh date beside a stale prize.
    const interval = setInterval(load, REFRESH_MS);
    return () => {
      controller.abort();
      clearInterval(interval);
    };
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      const fresh = computeNextDraw();
      setNext(prev => (prev.iso === fresh.iso ? prev : fresh));
    }, REFRESH_MS);
    return () => clearInterval(interval);
  }, []);

  return {
    day: serverDraw?.day ?? next.day,
    date: serverDraw?.date ?? next.date,
    jackpot,
    jackpotIsLive,
  };
}
