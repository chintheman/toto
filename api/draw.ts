import type { Context } from "hono";
import { computeNextDraw } from "../shared/drawSchedule";

const DEFAULT_JACKPOT = "$2.5M";

export default (c: Context) => {
  const now = new Date();
  const next = computeNextDraw(now);

  return c.json(
    {
      next: {
        day: next.day,
        date: `${next.day} ${next.date}`,
        iso: next.iso,
      },
      jackpot: process.env.TOTO_JACKPOT || DEFAULT_JACKPOT,
      drawPassed: next.drawPassed,
      lastUpdated: now.toISOString(),
    },
    200,
    {
      // Payload only changes at draw boundaries (twice a week), so let
      // CDNs serve it instead of invoking the function per request.
      "Cache-Control": "public, s-maxage=300, stale-while-revalidate=3600",
    }
  );
};
