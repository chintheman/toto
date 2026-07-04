import { useState, useEffect } from "react";

const DRAW_DAYS = [1, 4]; // Monday=1, Thursday=4
const DRAW_HOUR = 18;
const DRAW_MIN = 30;
const SG_OFFSET = 8;

function toSGT(date: Date): Date {
  const utc = date.getTime() + date.getTimezoneOffset() * 60000;
  return new Date(utc + SG_OFFSET * 3600000);
}

function daysUntilDrawDay(sgtDay: number): number {
  for (const d of DRAW_DAYS) if (d >= sgtDay) return d - sgtDay;
  return 7 + DRAW_DAYS[0] - sgtDay;
}

export interface DrawInfo {
  day: string;
  date: string;
  jackpot: string;
}

function calcDraw(): DrawInfo {
  const now = new Date();
  const sgt = toSGT(now);
  const sgtDay = sgt.getDay();
  const sgtMinutes = sgt.getHours() * 60 + sgt.getMinutes();
  const drawMinutes = DRAW_HOUR * 60 + DRAW_MIN;

  let daysUntil = daysUntilDrawDay(sgtDay);
  if (daysUntil === 0 && sgtMinutes >= drawMinutes) {
    daysUntil = 7 + DRAW_DAYS[0] - sgtDay;
  }

  const next = new Date(sgt);
  next.setDate(next.getDate() + daysUntil);
  next.setHours(DRAW_HOUR, DRAW_MIN, 0, 0);

  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  return {
    day: days[next.getDay()],
    date: `${next.getDate()} ${months[next.getMonth()]} ${next.getFullYear()}`,
    jackpot: "$2.5M",
  };
}

export function useNextDraw(): DrawInfo {
  const [info, setInfo] = useState<DrawInfo>(calcDraw);
  useEffect(() => {
    const interval = setInterval(() => setInfo(calcDraw()), 60000);
    return () => clearInterval(interval);
  }, []);
  return info;
}
