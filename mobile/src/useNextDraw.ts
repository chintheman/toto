import { useEffect, useState } from "react";
import { computeNextDraw, type NextDraw } from "../shared/drawSchedule";

// Live draw endpoint documented in the repo's AGENTS.md; the app falls
// back to local schedule math + default jackpot when unreachable.
const DRAW_API = "https://0xsteamboat.zo.space/api/toto/draw";
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
    fetch(DRAW_API, { signal: controller.signal })
      .then(r => (r.ok ? r.json() : null))
      .then(data => {
        if (typeof data?.jackpot === "string") setJackpot(data.jackpot);
      })
      .catch(() => {
        // Offline or API down: keep the local fallback.
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
