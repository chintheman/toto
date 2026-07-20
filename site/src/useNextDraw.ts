import { useState, useEffect } from "react";
import { computeNextDraw, type NextDraw } from "../../shared/drawSchedule";

const FALLBACK_JACKPOT = "$2.5M";

export interface DrawInfo {
  day: string;
  date: string;
  jackpot: string;
}

export function useNextDraw(): DrawInfo {
  const [next, setNext] = useState<NextDraw>(() => computeNextDraw());
  const [jackpot, setJackpot] = useState(FALLBACK_JACKPOT);

  useEffect(() => {
    const controller = new AbortController();
    fetch("/api/toto/draw", { signal: controller.signal })
      .then(r => (r.ok ? r.json() : null))
      .then(data => {
        if (typeof data?.jackpot === "string") setJackpot(data.jackpot);
      })
      .catch(() => {
        // API unreachable (dev server, offline): keep the local fallback.
      });
    return () => controller.abort();
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      const fresh = computeNextDraw();
      setNext(prev => (prev.iso === fresh.iso ? prev : fresh));
    }, 60000);
    return () => clearInterval(interval);
  }, []);

  return { day: next.day, date: next.date, jackpot };
}
