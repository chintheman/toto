import { useState, useEffect, useMemo } from "react";
import { theme, Section, ScribbleDivider } from "./brand";
import { BarChart3, Share2, Sparkles, AlertTriangle, ChevronDown } from "lucide-react";
import { useNextDraw } from "./useNextDraw";
import { strats, evByJackpot, evAtJackpot, frequencyTop, frequencyBottom, maxFreq } from "../../shared/totoData";
import { generatePortfolio, type Portfolio, type StrategyKey } from "../../shared/ticketGenerator";

// ─── Data ───────────────────────────────────────────────────────────────────

const myths = [
  { m: "Hot numbers win more", t: "Statistically? Nope. χ² (a test that checks if patterns are real or just random noise) comes out at 38.18 — well below the 65.17 threshold that would mean something's actually going on. Every number has the same odds, always.", e: "🎲", verdict: "Pure gambler's fallacy" },
  { m: "Cold numbers are 'due'", t: "Number 45 hasn't appeared in 200 draws? It still has the same ~12.2% chance this draw as #15 does. Draws have no memory.", e: "🧊", verdict: "The lottery doesn't owe you anything" },
  { m: "Bigger systems = better odds", t: "1× System 9 covers 84 combos across 9 numbers. 12× System 7 covers 84 combos across 49. Same spend — dramatically different coverage.", e: "📊", verdict: "Spread beats concentration" },
  { m: "Past patterns predict the future", t: "13,983,816 combinations. No memory. No momentum. The only pattern is that there is no pattern.", e: "🔮", verdict: "Not how probability works" },
  { m: "Monday and Thursday draws differ", t: "596 Mon vs 563 Thu draws analysed. Biggest frequency gap was #46 at 11.1% Mon vs 16.5% Thu. Statistically meaningless after correction.", e: "📅", verdict: "Noise, not signal" },
  { m: "Buying more tickets doesn't help", t: "It does — linearly. 100 tickets = 100/13,983,816 = 1 in 139,838 jackpot chance. Still a lottery, just slightly less hopeless.", e: "🎫", verdict: "More tickets = proportionally better odds" },
  { m: "The system is rigged", t: "1,000+ draws, chi-squared test passes every time. Singapore Pools is government-regulated and independently audited. The game is fair.", e: "⚖️", verdict: "Fair game, unfair maths" },
];

const funFacts = [
  { n: "#15", stat: "175 appearances", label: "Most frequent number", detail: "Shows up in 14.7% of all draws — but χ² says it's noise. Flukes happen at scale.", color: theme.terracotta, emoji: "🔥" },
  { n: "#45", stat: "119 appearances", label: "Least frequent number", detail: "Would need 27 more hits just to reach average. Random variance — not rigged, not cursed.", color: theme.sage, emoji: "🌿" },
  { n: "2–15", stat: "30 co-appearances", label: "Most common pair", detail: "Nearly 2× the expected rate. But it's still within chance. Pairs 5–49 (29×) right behind.", color: theme.brownLight, emoji: "🤝" },
  { n: "27–45", stat: "5 co-appearances", label: "Rarest pair", detail: "Only 0.33× the expected rate across 1,000+ draws. These two simply haven't met.", color: theme.brownLight, emoji: "🙈" },
  { n: "41.8%", stat: "498 draws", label: "Draws with zero carryover", detail: "In nearly half of all draws, not a single number repeated from the previous one.", color: theme.terracotta, emoji: "♻️" },
  { n: "48–49", stat: "20 consecutive pairs", label: "Favourite neighbours", detail: "The most common consecutive pair. 23–24 and 20–21 also hit 20× each.", color: theme.sage, emoji: "👫" },
];

const evData = evByJackpot.map(r => ({
  jackpot: r.jackpot,
  ev: r.ev < 0 ? `−${-r.ev}%` : `+${r.ev}%`,
  bar: Math.round((100 + r.ev) / 2),
  positive: r.ev > 0,
}));

// ─── Small components ───────────────────────────────────────────────────────

function LotteryBall({ n, size = 48, color = theme.terracotta }: { n: string | number; size?: number; color?: string }) {
  return (
    <div
      className="rounded-full flex items-center justify-center font-serif font-bold flex-shrink-0 shadow-sm"
      style={{
        width: size, height: size,
        background: `radial-gradient(circle at 35% 35%, ${color}ee, ${color}99)`,
        color: "#fff",
        fontSize: size * 0.32,
        boxShadow: `0 2px 8px ${color}44, inset 0 1px 2px rgba(255,255,255,0.3)`,
      }}
    >
      {n}
    </div>
  );
}

function FrequencyBar({ label, count, max, hot }: { label: string; count: number; max: number; hot: boolean }) {
  const pct = Math.round((count / max) * 100);
  return (
    <div className="flex items-center gap-3">
      <LotteryBall n={label} size={32} color={hot ? theme.terracotta : theme.sage} />
      <div className="flex-1 h-4 rounded-full overflow-hidden" style={{ background: theme.beige }}>
        <div
          className="h-full rounded-full transition-all duration-700"
          style={{
            width: `${pct}%`,
            background: hot
              ? `linear-gradient(90deg, ${theme.terracotta}, ${theme.terracottaLight})`
              : `linear-gradient(90deg, ${theme.sage}, ${theme.sageLight})`,
          }}
        />
      </div>
      <span className="w-9 sm:w-8 text-right text-xs font-mono font-medium" style={{ color: theme.brownLight }}>{count}</span>
    </div>
  );
}

function Accordion({ title, children, defaultOpen = false, accent = theme.terracotta }: {
  title: string; children: React.ReactNode; defaultOpen?: boolean; accent?: string;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div
      className="rounded-2xl overflow-hidden transition-all"
      style={{ background: theme.creamWarm, border: `1px solid ${open ? accent + "40" : theme.beige}` }}
    >
      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center gap-4 px-6 py-5 text-left"
      >
        <div className="w-1.5 h-6 rounded-full flex-shrink-0" style={{ background: open ? accent : theme.beigeDark }} />
        <span className="flex-1 font-serif text-lg" style={{ color: theme.brown }}>{title}</span>
        <ChevronDown
          size={18}
          className={`transition-transform duration-300 flex-shrink-0 ${open ? "rotate-180" : ""}`}
          style={{ color: theme.brownLight }}
        />
      </button>
      <div className={`transition-all duration-400 overflow-hidden ${open ? "max-h-[1000px] opacity-100" : "max-h-0 opacity-0"}`}>
        <div className="px-6 pb-6 text-base leading-relaxed space-y-3" style={{ color: theme.brownLight }}>
          {children}
        </div>
      </div>
    </div>
  );
}

function StatCard({ n, emoji, stat, label, detail, color }: typeof funFacts[0]) {
  const [flipped, setFlipped] = useState(false);
  return (
    <div
      className="rounded-2xl p-5 cursor-pointer select-none transition-all hover:-translate-y-0.5 hover:shadow-md"
      style={{ background: theme.creamWarm, border: `1px solid ${flipped ? color + "40" : theme.beige}`, minHeight: 150 }}
      onClick={() => setFlipped(!flipped)}
    >
      {!flipped ? (
        <div className="flex flex-col gap-2 h-full">
          <span className="text-2xl">{emoji}</span>
          <div className="font-serif text-xl font-bold" style={{ color }}>{stat}</div>
          <div className="text-sm font-medium leading-snug" style={{ color: theme.brown }}>{label}</div>
          <div className="text-sm sm:text-xs mt-auto pt-2" style={{ color: theme.brownLight + "99" }}>tap to find out why →</div>
        </div>
      ) : (
        <div className="flex flex-col gap-2 h-full">
          <div className="font-serif text-sm font-bold" style={{ color }}>{n}</div>
          <p className="text-sm leading-relaxed flex-1" style={{ color: theme.brownLight }}>{detail}</p>
          <div className="text-sm mt-auto pt-2" style={{ color: theme.brownLight + "99" }}>← tap to flip back</div>
        </div>
      )}
    </div>
  );
}

function EVChecker() {
  const [jm, setJm] = useState(2.5);
  const ev = Math.round(evAtJackpot(jm));
  const positive = ev > 0;
  return (
    <div className="rounded-xl p-4 my-3" style={{ background: theme.cream, border: `1px solid ${theme.beige}` }}>
      <div className="flex items-center justify-between mb-2">
        <label htmlFor="ev-slider" className="text-sm font-medium" style={{ color: theme.brown }}>
          Check a jackpot: <strong>${jm.toFixed(1)}M</strong>
        </label>
        <span className="font-serif text-lg font-bold" style={{ color: positive ? theme.sage : theme.terracotta }}>
          {positive ? "+" : ""}{ev}% EV
        </span>
      </div>
      <input
        id="ev-slider"
        type="range"
        min={1}
        max={10}
        step={0.1}
        value={jm}
        onChange={e => setJm(parseFloat(e.target.value))}
        className="w-full"
        style={{ accentColor: positive ? theme.sage : theme.terracotta }}
      />
      <p className="text-sm mt-2" style={{ color: theme.brownLight }}>
        Every $1 played returns ≈ <strong style={{ color: theme.brown }}>${(1 + ev / 100).toFixed(2)}</strong> on average —{" "}
        {positive
          ? "positive EV. This is one of the rare draws where the math is on your side."
          : "you're paying for entertainment, not value. Wait for $4.5M+."}
      </p>
    </div>
  );
}

function TicketPortfolio({ portfolio, onShuffle }: { portfolio: Portfolio; onShuffle: () => void }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    const lines = portfolio.tickets.map(
      t => `${t.type === "S7" ? "System 7" : "Ordinary"}: ${t.numbers.join(" ")}`
    );
    navigator.clipboard
      ?.writeText(lines.join("\n"))
      .then(() => {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      })
      .catch(() => {});
  };
  return (
    <div className="rounded-2xl p-5 mt-4" style={{ background: theme.creamWarm, border: `1px solid ${theme.beige}` }}>
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
        <div>
          <h4 className="font-serif text-lg" style={{ color: theme.brown }}>Your tickets</h4>
          <p className="text-[11px] sm:text-xs" style={{ color: theme.brownLight }}>
            Mean pairwise overlap: {portfolio.meanOverlap.toFixed(2)} numbers
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={onShuffle}
            className="px-4 py-1.5 rounded-full text-xs font-medium transition-all hover:opacity-80"
            style={{ background: theme.cream, color: theme.brownLight, border: `1px solid ${theme.beigeDark}` }}
          >
            🎲 Shuffle
          </button>
          <button
            onClick={copy}
            className="px-4 py-1.5 rounded-full text-xs font-medium transition-all hover:opacity-80"
            style={{ background: theme.terracotta, color: "#fff" }}
          >
            {copied ? "✓ Copied" : "Copy list"}
          </button>
        </div>
      </div>

      {portfolio.pool && (
        <div className="flex flex-wrap items-center gap-1.5 mb-4">
          <span className="text-[11px] sm:text-xs mr-1" style={{ color: theme.brownLight }}>Your 14-number pool:</span>
          {portfolio.pool.map(n => (
            <LotteryBall key={n} n={n} size={26} color={theme.brownLight} />
          ))}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
        {portfolio.tickets.map((t, i) => (
          <div
            key={i}
            className="flex items-center gap-1.5 rounded-xl px-3 py-2"
            style={{ background: theme.cream, border: `1px solid ${theme.beige}` }}
          >
            <span
              className="text-[10px] font-mono font-bold w-9 flex-shrink-0"
              style={{ color: t.type === "S7" ? theme.sage : theme.terracotta }}
            >
              {t.type === "S7" ? "S7" : "ORD"}
            </span>
            <div className="flex flex-wrap gap-1">
              {t.numbers.map(n => (
                <LotteryBall key={n} n={n} size={26} color={t.type === "S7" ? theme.sage : theme.terracotta} />
              ))}
            </div>
          </div>
        ))}
      </div>

      <p className="text-[11px] sm:text-xs mt-4 text-center" style={{ color: theme.brownLight }}>
        Random low-overlap numbers — every set has identical odds. Shuffling doesn't improve them; it just feels better.
      </p>
    </div>
  );
}

// ─── Page ───────────────────────────────────────────────────────────────────

export default function Toto() {
  const [amt, setAmt] = useState("100");
  const [goal, setGoal] = useState("1k");
  const [showAllMyths, setShowAllMyths] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [showTickets, setShowTickets] = useState(false);
  const [seed, setSeed] = useState(() => Date.now() % 1_000_000);
  const draw = useNextDraw();

  useEffect(() => setShowTickets(false), [goal]);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const s = strats[goal as keyof typeof strats];
  const bdgt = parseInt(amt);
  const ok = bdgt >= s.cost;

  const portfolio = useMemo(
    () => (showTickets && ok ? generatePortfolio(goal as StrategyKey, seed) : null),
    [showTickets, ok, goal, seed]
  );

  return (
    <>
      <style>{`
        html { scroll-behavior: smooth; }
        body { background: ${theme.cream}; }
        .font-serif  { font-family: 'Playfair Display', Georgia, serif; }
        .font-body   { font-family: 'Inter', system-ui, -apple-system, sans-serif; }

        .grain-overlay::before {
          content: '';
          position: fixed; top: 0; left: 0;
          width: 100%; height: 100%;
          pointer-events: none; z-index: 100; opacity: 0.025;
          background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
        }

        @keyframes float { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-7px)} }
        .float   { animation: float 5s ease-in-out infinite; }
        .float-1 { animation-delay: 0s; }
        .float-2 { animation-delay: 0.8s; }
        .float-3 { animation-delay: 1.6s; }
        .float-4 { animation-delay: 2.4s; }

        @keyframes spin-slow { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }
        .spin-slow { animation: spin-slow 30s linear infinite; }

        .myth-card:hover { transform: translateX(4px); }
        .myth-card { transition: transform 0.2s ease; }

        select { appearance: none; cursor: pointer; }
        select:focus { outline: 2px solid ${theme.terracotta}55; outline-offset: 2px; }
      `}</style>

      <div className="grain-overlay font-body min-h-screen" style={{ background: theme.cream, color: theme.brown }}>

        {/* ── Nav ── */}
        <header className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300`}
          style={{
            padding: scrolled ? "0.5rem 0" : "0.75rem 0",
            backgroundColor: scrolled ? `${theme.cream}f0` : theme.cream,
            borderBottom: scrolled ? `1px solid ${theme.beige}` : "1px solid transparent",
            backdropFilter: scrolled ? "blur(12px)" : "none",
            WebkitBackdropFilter: scrolled ? "blur(12px)" : "none",
          }}>
          <div className="max-w-5xl mx-auto px-4 sm:px-6 flex items-center justify-between">
            <span className="font-serif text-lg tracking-tight" style={{ color: theme.brown }}>⢕ steamboat</span>
            <div className="flex items-center gap-2 sm:gap-4 text-[11px] sm:text-xs" style={{ color: theme.brownLight }}>
              <a href="#calc"
                className="px-3 sm:px-4 py-1.5 rounded-full text-[11px] sm:text-xs font-medium transition-all hover:scale-105"
                style={{ background: theme.terracotta, color: "#fff", textDecoration: "none" }}>
                Calculate ↓
              </a>
            </div>
          </div>
        </header>

        {/* ── Hero ── */}
        <Section>
          <header className="px-6 pt-20 pb-12 text-center relative overflow-hidden" style={{ minHeight: 480 }}>
            {/* Background image */}
            <div
              className="absolute inset-0 bg-cover bg-center pointer-events-none"
              style={{ backgroundImage: "url('/images/toto-hero.jpg')", opacity: 0.12 }}
            />
            {/* Floating balls decoration */}
            <div className="absolute inset-0 pointer-events-none overflow-hidden">
              <div className="absolute top-12 left-[8%] float float-1 opacity-30">
                <LotteryBall n={15} size={52} color={theme.terracotta} />
              </div>
              <div className="absolute top-24 right-[10%] float float-2 opacity-25">
                <LotteryBall n={40} size={44} color={theme.sage} />
              </div>
              <div className="absolute bottom-16 left-[18%] float float-3 opacity-20">
                <LotteryBall n={28} size={36} color={theme.brownLight} />
              </div>
              <div className="absolute bottom-20 right-[20%] float float-4 opacity-25">
                <LotteryBall n={49} size={48} color={theme.terracotta} />
              </div>
              {/* Ring motifs */}
              <div className="absolute top-8 right-[28%] w-28 h-28 rounded-full border spin-slow" style={{ borderColor: theme.terracotta + "20", borderWidth: 1 }} />
              <div className="absolute bottom-8 left-[30%] w-20 h-20 rounded-full border" style={{ borderColor: theme.sage + "25", borderWidth: 1 }} />
            </div>

            <div className="max-w-3xl mx-auto relative z-10">
              <div className="inline-flex items-center gap-2.5 px-4 sm:px-5 py-2 sm:py-2.5 rounded-full text-sm sm:text-base font-medium mb-5 sm:mb-7"
                style={{ background: `${theme.terracotta}18`, color: theme.terracotta, border: `1px solid ${theme.terracotta}35` }}>
                <span className="w-2 h-2 rounded-full bg-current animate-pulse" />
                Next Draw · {draw.day} {draw.date} · <strong>{draw.jackpot} jackpot</strong>
              </div>
              <h1 className="font-serif mb-5" style={{ fontSize: "clamp(2.4rem, 7vw, 4.5rem)", lineHeight: 1.08, letterSpacing: "-0.02em", color: theme.brown }}>
                TOTO Strategy<br />
                <span style={{ color: theme.terracotta }}>Without the Nonsense</span>
              </h1>
              <p className="text-lg max-w-lg mx-auto leading-relaxed" style={{ color: theme.brownLight }}>
                1,000+ draws. Every myth busted with real data.<br />Know the math before you spend a cent.
              </p>
              <div className="mt-8 flex flex-wrap gap-3 justify-center">
                <a href="#calc" className="inline-flex items-center gap-2 px-6 py-3 rounded-full text-sm font-medium transition-all hover:scale-105"
                  style={{ background: theme.terracotta, color: "#fff" }}>
                  Run my numbers
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
                </a>
                <a href="#myths" className="inline-flex items-center gap-2 px-6 py-3 rounded-full text-sm font-medium transition-all hover:scale-105"
                  style={{ background: theme.creamWarm, color: theme.brownLight, border: `1px solid ${theme.beige}` }}>
                  Bust the myths first
                </a>
              </div>
            </div>
          </header>
        </Section>

        <div className="max-w-5xl mx-auto px-4">
          <ScribbleDivider />

          {/* ── Data Facts ── */}
          <Section>
            <section className="py-8">
              <div className="flex items-center gap-3 mb-2">
                <Sparkles size={16} style={{ color: theme.terracotta }} />
                <span className="text-[11px] sm:text-xs tracking-widest uppercase" style={{ color: theme.brownLight }}>1,000+ draws of data</span>
              </div>
              <h2 className="font-serif mb-3" style={{ fontSize: "clamp(1.8rem, 4vw, 2.5rem)", letterSpacing: "-0.02em" }}>
                What the Numbers Actually Say
              </h2>
              <p className="text-[13px] sm:text-sm mb-8 max-w-xl" style={{ color: theme.brownLight }}>
                Randomness creates fascinating quirks. None of them are exploitable — but all of them are interesting. Tap any card.
              </p>

              {/* Flip cards */}
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-10">
                {funFacts.map((f, i) => (
                  <StatCard key={i} {...f} />
                ))}
              </div>

              {/* Frequency chart */}
              <div className="rounded-2xl p-6" style={{ background: theme.creamWarm, border: `1px solid ${theme.beige}` }}>
                <div className="flex items-center justify-between mb-5">
                  <h3 className="font-serif text-lg">Hot vs Cold</h3>
                  <span className="text-[11px] sm:text-xs px-2.5 py-1 rounded-full" style={{ background: theme.beige, color: theme.brownLight }}>1,000+ draws</span>
                </div>
                <div className="space-y-3 mb-4">
                  <p className="text-[11px] sm:text-xs uppercase tracking-wider mb-3" style={{ color: theme.terracotta }}>🔥 Top 5 most frequent</p>
                  {frequencyTop.map(d => (
                    <FrequencyBar key={d.n} label={d.n} count={d.count} max={maxFreq} hot={true} />
                  ))}
                </div>
                <div className="space-y-3 mt-6">
                  <p className="text-[11px] sm:text-xs uppercase tracking-wider mb-3" style={{ color: theme.sage }}>🌿 Bottom 5 least frequent</p>
                  {frequencyBottom.map(d => (
                    <FrequencyBar key={d.n} label={d.n} count={d.count} max={maxFreq} hot={false} />
                  ))}
                </div>
                <p className="text-[11px] sm:text-xs mt-5 pt-4 text-center" style={{ color: theme.brownLight, borderTop: `1px solid ${theme.beige}` }}>
                  That 56-draw gap between #15 and #45 looks dramatic. χ² = 38.18 says it's completely normal variance. The draw is fair.
                </p>
              </div>
            </section>
          </Section>

          <ScribbleDivider color={theme.sageLight} />

          {/* ── Myths ── */}
          <Section>
            <section id="myths" className="py-8">
              <div className="flex items-center gap-3 mb-2">
                <AlertTriangle size={16} style={{ color: theme.sage }} />
                <span className="text-[11px] sm:text-xs tracking-widest uppercase" style={{ color: theme.brownLight }}>myth-busting</span>
              </div>
              <h2 className="font-serif mb-3" style={{ fontSize: "clamp(1.8rem, 4vw, 2.5rem)", letterSpacing: "-0.02em" }}>
                7 Things People Believe<br />
                <span style={{ color: theme.sage }}>That Are Simply Wrong</span>
              </h2>
              <p className="text-[13px] sm:text-sm mb-8 max-w-xl" style={{ color: theme.brownLight }}>
                Lottery folklore doesn't survive contact with data. Here's what 1,000+ draws actually show.
              </p>

              <div className="space-y-3">
                {(showAllMyths ? myths : myths.slice(0, 4)).map((m, i) => (
                  <div
                    key={i}
                    className="myth-card rounded-2xl overflow-hidden"
                    style={{ background: theme.creamWarm, border: `1px solid ${theme.beige}` }}
                  >
                    <div className="flex gap-4 p-5">
                      <span className="text-2xl flex-shrink-0 mt-0.5">{m.e}</span>
                      <div className="flex-1 min-w-0">
                        <div className="flex flex-wrap items-start gap-2 mb-2">
                          <h3 className="font-serif font-medium line-through opacity-50 text-sm" style={{ color: theme.brown }}>{m.m}</h3>
                          <span className="text-[11px] sm:text-xs px-2 py-0.5 rounded-full flex-shrink-0" style={{ background: `${theme.sage}18`, color: theme.sage }}>
                            ✓ {m.verdict}
                          </span>
                        </div>
                        <p className="text-base sm:text-sm leading-relaxed" style={{ color: theme.brownLight }}>{m.t}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              <button
                onClick={() => setShowAllMyths(!showAllMyths)}
                className="mt-5 flex items-center gap-2 text-sm font-medium transition-all hover:opacity-70"
                style={{ color: theme.terracotta }}
              >
                {showAllMyths ? "← Show fewer" : `See all ${myths.length} myths →`}
              </button>
            </section>
          </Section>

          <ScribbleDivider />

          {/* ── Strategy ── */}
          <Section>
            <section className="py-8 relative">
              <div
                className="absolute inset-0 bg-cover bg-center pointer-events-none rounded-3xl"
                style={{ backgroundImage: "url('/images/toto-probability.jpg')", opacity: 0.04 }}
              />
              <div className="relative">
                <span className="block text-[11px] sm:text-xs uppercase tracking-widest mb-2" style={{ color: theme.brownLight }}>the strategy</span>
                <h2 className="font-serif mb-3" style={{ fontSize: "clamp(1.8rem, 4vw, 2.5rem)", letterSpacing: "-0.02em" }}>
                  How to Play Smarter<br />
                  <span style={{ color: theme.terracotta }}>When the Math Allows It</span>
                </h2>
                <p className="text-[13px] sm:text-sm mb-8 max-w-xl" style={{ color: theme.brownLight }}>
                  The draw is fair — but your strategy isn't locked in. Three things actually move the needle.
                </p>

                <div className="space-y-3">
                  <Accordion title="📊 When is it even worth playing?" defaultOpen accent={theme.terracotta}>
                    <p><strong style={{ color: theme.brown }}>Expected Value (EV)</strong> is simple: for every $1 you spend, how much prize money do you get back on average? Below ~$3.5M jackpot, that's about 30–50¢. Above $4.5M, you're over $1.</p>
                    <div className="rounded-xl p-4 my-3" style={{ background: theme.cream, border: `1px solid ${theme.beige}` }}>
                      {evData.map((r, i) => (
                        <div key={i} className="flex items-center gap-3 py-1.5">
                          <span className="w-14 text-[11px] sm:text-xs font-medium text-right" style={{ color: theme.brown }}>{r.jackpot}</span>
                          <div className="flex-1 h-5 rounded-full overflow-hidden" style={{ background: theme.beige }}>
                            <div
                              className="h-full rounded-full transition-all duration-700"
                              style={{
                                width: `${r.bar}%`,
                                background: r.positive
                                  ? `linear-gradient(90deg, ${theme.sage}, ${theme.terracotta})`
                                  : theme.beigeDark,
                              }}
                            />
                          </div>
                          <span className="w-14 text-[11px] sm:text-xs font-medium text-right" style={{ color: r.positive ? theme.sage : theme.brownLight }}>{r.ev}</span>
                        </div>
                      ))}
                    </div>
                    <EVChecker />
                    <p><strong style={{ color: theme.brown }}>Bottom line:</strong> Wait for $4M+. Everything below that is expensive entertainment.</p>
                  </Accordion>

                  <Accordion title="🔄 Spread your tickets — don't pile into one system" accent={theme.sage}>
                    <p>A System 9 ticket ($84) covers 84 combinations — but only across 9 numbers. If those 9 numbers miss, you win nothing.</p>
                    <p>12 ordinary tickets at $7 each cover the same 84 combinations but spread across up to 72 different numbers. Same spend, far better coverage.</p>
                    <p><strong style={{ color: theme.brown }}>Backtest result:</strong> The spread strategy wins a prize in ~49% of draws vs ~22% for the concentrated approach.</p>
                  </Accordion>

                  <Accordion title="🧩 The only peer-reviewed lottery strategy" accent={theme.brownLight}>
                    <p><strong style={{ color: theme.brown }}>Liu, Liu & Teo (2024, Management Science)</strong> proved that evenly distributing number overlap across your tickets — not maximising coverage, not randomising — gives the best expected prize count.</p>
                    <p>It sounds technical. Practically it means: structure your tickets so they're as independent of each other as possible. One ticket losing shouldn't drag the others with it.</p>
                    <p><strong style={{ color: theme.brown }}>Our Optimal Region strategy</strong> achieves 100% coverage with mean pairwise overlap of 0.753 — best of any $100 portfolio tested across 1,000+ draws.</p>
                  </Accordion>
                </div>
              </div>
            </section>
          </Section>

          <ScribbleDivider color={theme.terracottaLight} />

          {/* ── Calculator ── */}
          <Section>
            <section id="calc" className="py-8">
              <div className="flex items-center gap-3 mb-2">
                <BarChart3 size={16} style={{ color: theme.terracotta }} />
                <span className="text-[11px] sm:text-xs tracking-widest uppercase" style={{ color: theme.brownLight }}>the calculator</span>
              </div>
              <h2 className="font-serif mb-3" style={{ fontSize: "clamp(1.8rem, 4vw, 2.5rem)", letterSpacing: "-0.02em" }}>
                Run Your Numbers
              </h2>
              <p className="text-[13px] sm:text-sm mb-8 max-w-xl" style={{ color: theme.brownLight }}>
                Pick your budget and your goal. The strategy adjusts automatically.
              </p>

              <div className="rounded-3xl p-6 md:p-10" style={{ background: theme.creamWarm, border: `1px solid ${theme.beige}` }}>
                {/* Inputs */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
                  <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: theme.brownLight }}>How much do you want to spend?</label>
                    <div className="relative">
                      <select
                        value={amt}
                        onChange={e => setAmt(e.target.value)}
                        className="w-full px-5 py-3.5 rounded-full text-sm font-medium pr-10"
                        style={{ background: theme.cream, color: theme.brown, border: `1px solid ${theme.beigeDark}` }}
                      >
                        {["20","50","100","200","500"].map(v => <option key={v} value={v}>${v}</option>)}
                      </select>
                      <ChevronDown size={14} className="absolute right-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: theme.brownLight }} />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: theme.brownLight }}>What are you hoping to win?</label>
                    <div className="relative">
                      <select
                        value={goal}
                        onChange={e => setGoal(e.target.value)}
                        className="w-full px-5 py-3.5 rounded-full text-sm font-medium pr-10"
                        style={{ background: theme.cream, color: theme.brown, border: `1px solid ${theme.beigeDark}` }}
                      >
                        <option value="1k">Something — any prize works for me</option>
                        <option value="100k">~$100,000 (Group 2)</option>
                        <option value="mega">The jackpot — I'm going big</option>
                      </select>
                      <ChevronDown size={14} className="absolute right-4 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: theme.brownLight }} />
                    </div>
                  </div>
                </div>

                {/* Result */}
                <div className="rounded-2xl p-6 mb-6" style={{ background: theme.cream, border: `1px solid ${theme.beige}` }}>
                  <div className="flex items-start gap-4 mb-6">
                    <div
                      className="w-12 h-12 rounded-full flex items-center justify-center text-white font-serif font-bold text-lg flex-shrink-0"
                      style={{ background: `radial-gradient(circle at 35% 35%, ${theme.terracotta}, ${theme.terracotta}99)` }}
                    >
                      {s.name[0]}
                    </div>
                    <div>
                      <h3 className="font-serif text-xl mb-0.5" style={{ color: theme.brown }}>{s.name}</h3>
                      <p className="text-sm" style={{ color: theme.brownLight }}>{s.tag}</p>
                    </div>
                  </div>

                  {!ok ? (
                    <div className="text-sm px-4 py-3 rounded-xl" style={{ background: `${theme.terracotta}12`, color: theme.brownLight }}>
                      This strategy needs a <strong style={{ color: theme.brown }}>${s.cost} minimum</strong>. Bump up your spend, or pick a different goal.
                    </div>
                  ) : (
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                      {[
                        { v: s.any,  label: "Win anything",   color: theme.terracotta },
                        { v: s.g3,   label: "Win ~$1,000",    color: theme.sage },
                        { v: s.g2,   label: "Win ~$100,000",  color: theme.brownLight },
                        { v: s.g1,   label: "Win jackpot",    color: theme.terracotta },
                      ].map((item, i) => (
                        <div key={i} className="text-center p-4 rounded-xl" style={{ background: `${item.color}12` }}>
                          <div className="font-serif font-bold text-xl mb-1" style={{ color: item.color }}>{item.v}</div>
                          <div className="text-[11px] sm:text-xs leading-tight" style={{ color: theme.brownLight }}>{item.label}</div>
                        </div>
                      ))}
                    </div>
                  )}

                  {ok && !portfolio && (
                    <button
                      onClick={() => setShowTickets(true)}
                      className="mt-5 w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-3 rounded-full text-sm font-medium transition-all hover:scale-[1.02]"
                      style={{ background: theme.terracotta, color: "#fff" }}
                    >
                      🎟 Generate my tickets
                    </button>
                  )}
                  {portfolio && (
                    <TicketPortfolio portfolio={portfolio} onShuffle={() => setSeed(v => v + 1)} />
                  )}
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-sm" style={{ color: theme.brownLight }}>
                  <div className="rounded-xl p-4" style={{ background: `${theme.terracotta}08`, border: `1px solid ${theme.terracotta}20` }}>
                    <span className="block text-sm sm:text-xs uppercase tracking-wider mb-1" style={{ color: theme.terracotta }}>Method</span>
                    {s.m}
                  </div>
                  <div className="rounded-xl p-4" style={{ background: `${theme.sage}08`, border: `1px solid ${theme.sage}20` }}>
                    <span className="block text-sm sm:text-xs uppercase tracking-wider mb-1" style={{ color: theme.sage }}>Min spend</span>
                    ${s.cost}
                  </div>
                  <div className="rounded-xl p-4" style={{ background: `${theme.brownLight}08`, border: `1px solid ${theme.brownLight}20` }}>
                    <span className="block text-sm sm:text-xs uppercase tracking-wider mb-1" style={{ color: theme.brownLight }}>Best when</span>
                    {s.w}
                  </div>
                </div>
              </div>
            </section>
          </Section>

          <ScribbleDivider />

          {/* ── Playbook ── */}
          <Section>
            <section className="py-8">
              <div className="flex items-center gap-3 mb-2">
                <Share2 size={16} style={{ color: theme.terracotta }} />
                <span className="text-[11px] sm:text-xs tracking-widest uppercase" style={{ color: theme.brownLight }}>the tldr</span>
              </div>
              <h2 className="font-serif mb-8" style={{ fontSize: "clamp(1.8rem, 4vw, 2.5rem)", letterSpacing: "-0.02em" }}>
                So What's the Play?
              </h2>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {[
                  { color: theme.terracotta, n: "01", title: "Only play when jackpot hits $4M+", body: "Below that, every dollar buys ~30–50¢ of expected prize money. Above $4.5M, you're in positive EV territory. The jackpot size is the only variable you control." },
                  { color: theme.sage,       n: "02", title: "Spread across all 49 numbers",    body: "12× System 7 covers every number for $84. One System 9 covers 9 numbers for the same price. Same cost, completely different odds profile." },
                  { color: theme.brownLight, n: "03", title: "Keep your tickets independent",    body: "Minimise overlap between tickets. If one misses, the others should still have a chance. This is the Liu & Teo (2024) insight — it's peer-reviewed and it works." },
                  { color: theme.terracotta, n: "04", title: "Pick one goal and own the trade-off", body: "Frequent small wins vs jackpot upside. The calculator above shows exactly what you're trading. Neither is wrong — just be honest with yourself about what you want." },
                ].map(({ color, n, title, body }, i) => (
                  <div
                    key={i}
                    className="rounded-2xl p-6 transition-all hover:-translate-y-0.5 hover:shadow-md"
                    style={{ background: `${color}0c`, border: `1px solid ${color}28` }}
                  >
                    <div className="flex items-start gap-3 mb-3">
                      <span className="font-serif text-3xl font-bold opacity-20 leading-none" style={{ color }}>{n}</span>
                      <h3 className="font-serif text-lg leading-snug" style={{ color }}>{title}</h3>
                    </div>
                    <p className="text-base leading-relaxed" style={{ color: theme.brownLight }}>{body}</p>
                  </div>
                ))}
              </div>
            </section>
          </Section>

          {/* ── Footer ── */}
          <ScribbleDivider />
          <footer className="px-4 sm:px-6 py-8 text-center" style={{ borderTop: `1px solid ${theme.beige}` }}>
            <p className="text-[10px] sm:text-[11px]" style={{ color: theme.brownLight }}>
              The draw is fair. No strategy guarantees a win. Play responsibly.
            </p>
          </footer>
        </div>
      </div>
    </>
  );
}
