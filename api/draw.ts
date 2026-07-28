import type { Context } from "hono";
import { computeNextDraw, FALLBACK_JACKPOT } from "../shared/drawSchedule";

// A jackpot must look like "$4.5M" / "$12M" before we present it as live.
// TOTO_JACKPOT is hand-set, so a typo would otherwise render straight into
// the hero and feed the EV calculator.
const JACKPOT_PATTERN = /^\$\d+(\.\d+)?M$/;

function resolveJackpot(raw: string | undefined): { jackpot: string; isLive: boolean } {
  if (raw && JACKPOT_PATTERN.test(raw.trim())) {
    return { jackpot: raw.trim(), isLive: true };
  }
  return { jackpot: FALLBACK_JACKPOT, isLive: false };
}

export default (c: Context) => {
  const now = new Date();
  const next = computeNextDraw(now);
  const { jackpot, isLive } = resolveJackpot(process.env.TOTO_JACKPOT);

  return c.json(
    {
      next: {
        day: next.day,
        date: `${next.day} ${next.date}`,
        iso: next.iso,
      },
      jackpot,
      jackpotIsLive: isLive,
      drawPassed: next.drawPassed,
      // The draw instant, not the response time: this payload is cached for
      // up to an hour under stale-while-revalidate, so a wall-clock stamp
      // here would be wrong for most of the responses actually served.
      nextDrawAt: next.iso,
    },
    200,
    {
      // Payload only changes at draw boundaries (twice a week), so let
      // CDNs serve it instead of invoking the function per request.
      "Cache-Control": "public, s-maxage=300, stale-while-revalidate=3600",
    }
  );
};
