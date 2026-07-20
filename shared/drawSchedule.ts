// Single source of truth for the TOTO draw schedule (see AGENTS.md:
// draws Mon & Thu at 6:30pm SGT; all time logic is SGT, UTC+8, no DST).
export const DRAW_DAYS = [1, 4]; // Monday=1, Thursday=4
export const DRAW_HOUR = 18;
export const DRAW_MIN = 30;
export const SG_OFFSET = 8;

const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export interface NextDraw {
  day: string; // "Thu"
  date: string; // "24 Jul 2026"
  iso: string; // real UTC instant of the draw
  drawPassed: boolean; // today is a draw day and 6:30pm SGT has passed
}

export function computeNextDraw(now: Date = new Date()): NextDraw {
  // Shift the epoch by +8h and read UTC getters to get SGT wall-clock
  // fields regardless of the host timezone.
  const sgt = new Date(now.getTime() + SG_OFFSET * 3600000);
  const sgtDay = sgt.getUTCDay();
  const sgtMinutes = sgt.getUTCHours() * 60 + sgt.getUTCMinutes();
  const drawPassed = DRAW_DAYS.includes(sgtDay) && sgtMinutes >= DRAW_HOUR * 60 + DRAW_MIN;

  let daysUntil = 0;
  for (let offset = 0; offset < 8; offset++) {
    if (DRAW_DAYS.includes((sgtDay + offset) % 7) && (offset > 0 || !drawPassed)) {
      daysUntil = offset;
      break;
    }
  }

  const drawEpoch = Date.UTC(
    sgt.getUTCFullYear(),
    sgt.getUTCMonth(),
    sgt.getUTCDate() + daysUntil,
    DRAW_HOUR - SG_OFFSET,
    DRAW_MIN
  );
  const sgtDraw = new Date(drawEpoch + SG_OFFSET * 3600000);

  return {
    day: DAY_NAMES[sgtDraw.getUTCDay()],
    date: `${sgtDraw.getUTCDate()} ${MONTH_NAMES[sgtDraw.getUTCMonth()]} ${sgtDraw.getUTCFullYear()}`,
    iso: new Date(drawEpoch).toISOString(),
    drawPassed,
  };
}
