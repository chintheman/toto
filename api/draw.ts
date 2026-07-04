import type { Context } from "hono";

const DRAW_DAYS = [1, 4]; // Monday=1, Thursday=4
const DRAW_HOUR = 18;
const DRAW_MIN = 30;
const SG_OFFSET = 8;
const DEFAULT_JACKPOT = "$2.5M";

function toSGT(date: Date): Date {
  const utc = date.getTime() + date.getTimezoneOffset() * 60000;
  return new Date(utc + SG_OFFSET * 3600000);
}

function daysUntilDrawDay(sgtDay: number): number {
  for (const d of DRAW_DAYS) {
    if (d >= sgtDay) return d - sgtDay;
  }
  return 7 + DRAW_DAYS[0] - sgtDay;
}

export default (c: Context) => {
  const now = new Date();
  const sgt = toSGT(now);
  const sgtDay = sgt.getDay();
  const sgtMinutes = sgt.getHours() * 60 + sgt.getMinutes();
  const drawMinutes = DRAW_HOUR * 60 + DRAW_MIN;

  let daysUntil = daysUntilDrawDay(sgtDay);
  let drawPassed = false;

  if (daysUntil === 0) {
    if (sgtMinutes < drawMinutes) {
      drawPassed = false;
    } else {
      drawPassed = true;
      daysUntil = 7 + DRAW_DAYS[0] - sgtDay;
    }
  }

  const next = new Date(sgt);
  next.setDate(next.getDate() + daysUntil);
  next.setHours(DRAW_HOUR, DRAW_MIN, 0, 0);

  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  return c.json({
    next: {
      day: days[next.getDay()],
      date: `${days[next.getDay()]} ${next.getDate()} ${months[next.getMonth()]} ${next.getFullYear()}`,
      iso: next.toISOString(),
    },
    jackpot: process.env.TOTO_JACKPOT || DEFAULT_JACKPOT,
    drawPassed,
    lastUpdated: sgt.toISOString(),
  });
};
