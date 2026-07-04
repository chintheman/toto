import { useCurrentFrame, useVideoConfig, spring, interpolate, AbsoluteFill, Sequence, Audio, staticFile } from "remotion";
import { loadFont } from "@remotion/google-fonts/PlayfairDisplay";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";

const { fontFamily: headingFont } = loadFont("normal", { weights: ["400", "700", "900"] });
const { fontFamily: bodyFont } = loadInter("normal", { weights: ["400", "600", "700"] });

const COLORS = {
  cream: "#faf7f2",
  brown: "#3d3226",
  brownLight: "#6b5d4f",
  terracotta: "#c17a4d",
  terracottaLight: "#d4895a",
  sage: "#7d8c6b",
  sageLight: "#9aab8a",
  beige: "#e8e0d5",
  beigeDark: "#d4c9b8",
};

// ─── Animation helpers ─────────────────────────────────────────────────────

const fadeIn = (frame: number, start: number, dur: number = 20) =>
  interpolate(frame - start, [0, dur], [0, 1], { extrapolateRight: "clamp", extrapolateLeft: "clamp" });

const slideFromLeft = (frame: number, start: number, amount: number = 100, dur: number = 25) => ({
  opacity: fadeIn(frame, start, dur),
  transform: `translateX(${interpolate(frame - start, [0, dur], [-amount, 0], { extrapolateRight: "clamp", extrapolateLeft: "clamp" })}px)`,
});

const slideFromRight = (frame: number, start: number, amount: number = 100, dur: number = 25) => ({
  opacity: fadeIn(frame, start, dur),
  transform: `translateX(${interpolate(frame - start, [0, dur], [amount, 0], { extrapolateRight: "clamp", extrapolateLeft: "clamp" })}px)`,
});

const slideUp = (frame: number, start: number, amount: number = 60, dur: number = 25) => ({
  opacity: fadeIn(frame, start, dur),
  transform: `translateY(${interpolate(frame - start, [0, dur], [amount, 0], { extrapolateRight: "clamp", extrapolateLeft: "clamp" })}px)`,
});

const scaleIn = (frame: number, start: number) =>
  spring({ frame: frame - start, fps: 30, config: { damping: 14, stiffness: 60 } });

// ─── Background ────────────────────────────────────────────────────────────

const Background = () => (
  <AbsoluteFill style={{ backgroundColor: COLORS.cream }}>
    <svg style={{ position: "absolute", inset: 0, width: "100%", height: "100%", opacity: 0.025 }}>
      <defs>
        <filter id="noise">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="4" stitchTiles="stitch" />
        </filter>
      </defs>
      <rect width="100%" height="100%" filter="url(#noise)" />
    </svg>
    <div style={{ position: "absolute", top: -100, right: -100, width: 800, height: 800, borderRadius: "50%", border: `1px solid ${COLORS.beige}`, opacity: 0.2 }} />
    <div style={{ position: "absolute", bottom: -150, left: -150, width: 600, height: 600, borderRadius: "50%", border: `1px solid ${COLORS.beige}`, opacity: 0.15 }} />
  </AbsoluteFill>
);

// ─── Scene 1: Hook (0–150 / 0–5s) ─────────────────────────────────────────

const SceneHook = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "center", paddingLeft: 120 }}>
      <div style={{ ...slideFromLeft(frame, 8) }}>
        <span style={{ fontFamily: headingFont, fontSize: 220, fontWeight: 900, color: COLORS.brown, letterSpacing: "-0.03em", lineHeight: 0.95, display: "block" }}>
          The lottery
        </span>
        <span style={{ fontFamily: headingFont, fontSize: 220, fontWeight: 900, color: COLORS.sage, letterSpacing: "-0.03em", lineHeight: 0.95, display: "block", marginTop: -20 }}>
          is fair.
        </span>
      </div>
      <div style={{ ...slideFromLeft(frame, 30), marginTop: 24 }}>
        <span style={{ fontFamily: headingFont, fontSize: 220, fontWeight: 900, color: COLORS.brown, letterSpacing: "-0.03em", lineHeight: 0.95, display: "block" }}>
          Your strategy
        </span>
        <span style={{ fontFamily: headingFont, fontSize: 220, fontWeight: 900, color: COLORS.terracotta, letterSpacing: "-0.03em", lineHeight: 0.95, display: "block", marginTop: -20 }}>
          isn't.
        </span>
      </div>
    </AbsoluteFill>
  );
};

// ─── Scene 2: Myths (150–330 / 5–11s) ────────────────────────────────────

const SceneMyths = () => {
  const frame = useCurrentFrame();
  const numbers = [
    { num: 15, freq: 175, label: "HOT", color: COLORS.terracotta },
    { num: 40, freq: 168, label: "HOT", color: COLORS.terracotta },
    { num: 46, freq: 161, label: "HOT", color: COLORS.terracottaLight },
    { num: 25, freq: 135, label: "COLD", color: COLORS.sage },
    { num: 45, freq: 119, label: "COLD", color: COLORS.sage },
  ];
  const maxFreq = 175;

  return (
    <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "flex-end", paddingLeft: 120, paddingBottom: 120 }}>
      <div style={{ ...slideFromLeft(frame, 5), marginBottom: 32 }}>
        <span style={{ fontFamily: headingFont, fontSize: 180, fontWeight: 900, color: COLORS.brown, letterSpacing: "-0.03em", display: "block", lineHeight: 1 }}>
          1,000+ draws
        </span>
        <span style={{ fontFamily: headingFont, fontSize: 180, fontWeight: 900, color: COLORS.sage, letterSpacing: "-0.03em", display: "block", lineHeight: 1, marginTop: -16 }}>
          no pattern.
        </span>
      </div>

      <div style={{ display: "flex", alignItems: "flex-end", gap: 36 }}>
        {numbers.map((n, i) => {
          const delay = 30 + i * 10;
          const h = spring({ frame: frame - delay, fps: 30, config: { damping: 15, stiffness: 60 } }) * (n.freq / maxFreq) * 340;
          const op = fadeIn(frame, delay, 12);
          return (
            <div key={n.num} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12, opacity: op }}>
              <span style={{ fontFamily: headingFont, fontSize: 64, fontWeight: 900, color: n.color }}>{n.freq}</span>
              <div style={{ width: 72, height: h, backgroundColor: n.color, borderRadius: "8px 8px 0 0", opacity: 0.82 }} />
              <span style={{ fontFamily: headingFont, fontSize: 40, fontWeight: 700, color: COLORS.brown }}>#{n.num}</span>
              <span style={{ fontFamily: bodyFont, fontSize: 18, fontWeight: 600, color: n.color, letterSpacing: "0.1em" }}>{n.label}</span>
            </div>
          );
        })}
      </div>

      <div style={{ ...slideFromLeft(frame, 90), marginTop: 32 }}>
        <span style={{ fontFamily: headingFont, fontSize: 72, fontWeight: 900, color: COLORS.brown }}>χ² = 38.18 → </span>
        <span style={{ fontFamily: headingFont, fontSize: 72, fontWeight: 900, color: COLORS.sage }}>normal.</span>
      </div>
    </AbsoluteFill>
  );
};

// ─── Scene 3: EV (330–510 / 11–17s) ──────────────────────────────────────

const SceneEV = () => {
  const frame = useCurrentFrame();
  const jackpots = [
    { amt: "$1M", ev: -72, color: COLORS.terracotta },
    { amt: "$2M", ev: -55, color: COLORS.terracotta },
    { amt: "$2.5M", ev: -42, color: COLORS.terracottaLight },
    { amt: "$3.5M", ev: -15, color: COLORS.beigeDark },
    { amt: "$4.5M", ev: 7, color: COLORS.sage },
    { amt: "$6M", ev: 25, color: COLORS.sage },
    { amt: "$8M", ev: 48, color: COLORS.sageLight },
  ];

  return (
    <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "flex-end", paddingLeft: 120, paddingBottom: 100 }}>
      <div style={{ ...slideFromLeft(frame, 5), marginBottom: 20 }}>
        <span style={{ fontFamily: headingFont, fontSize: 160, fontWeight: 900, color: COLORS.brown, letterSpacing: "-0.03em", display: "block", lineHeight: 1 }}>
          Below $4M?
        </span>
        <span style={{ fontFamily: headingFont, fontSize: 160, fontWeight: 900, color: COLORS.terracotta, letterSpacing: "-0.03em", display: "block", lineHeight: 1, marginTop: -16 }}>
          Bad bet.
        </span>
      </div>

      <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", maxWidth: 1100 }}>
        {jackpots.map((j, i) => {
          const delay = 30 + i * 10;
          const absEV = Math.abs(j.ev);
          const barH = spring({ frame: frame - delay, fps: 30, config: { damping: 15, stiffness: 55 } }) * absEV * 4;
          const op = fadeIn(frame, delay, 12);
          const pos = j.ev > 0;
          return (
            <div key={j.amt} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, opacity: op, minWidth: 72 }}>
              <span style={{ fontFamily: headingFont, fontSize: 40, fontWeight: 900, color: j.color }}>
                {pos ? "+" : ""}{j.ev}%
              </span>
              <div style={{
                width: 64,
                height: barH,
                backgroundColor: j.color,
                borderRadius: "6px 6px 0 0",
                opacity: 0.78,
              }} />
              <span style={{ fontFamily: bodyFont, fontSize: 22, fontWeight: 600, color: COLORS.brown, whiteSpace: "nowrap" }}>{j.amt}</span>
            </div>
          );
        })}
      </div>

      <div style={{ marginTop: 24, width: 680, height: 2, backgroundColor: COLORS.sage, opacity: 0.35 }} />
      <div style={{ ...slideFromLeft(frame, 120) }}>
        <span style={{ fontFamily: headingFont, fontSize: 44, fontWeight: 700, color: COLORS.sage, marginTop: 8, display: "block" }}>
          ↑ Positive EV threshold: $4.5M+
        </span>
      </div>
    </AbsoluteFill>
  );
};

// ─── Scene 4: Strategy (510–690 / 17–23s) ────────────────────────────────

const SceneStrategy = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "center", paddingLeft: 120 }}>
      <div style={{ ...slideFromLeft(frame, 5), marginBottom: 48 }}>
        <span style={{ fontFamily: headingFont, fontSize: 170, fontWeight: 900, color: COLORS.brown, letterSpacing: "-0.03em", display: "block", lineHeight: 1 }}>
          Spread beats
        </span>
        <span style={{ fontFamily: headingFont, fontSize: 170, fontWeight: 900, color: COLORS.sage, letterSpacing: "-0.03em", display: "block", lineHeight: 1, marginTop: -16 }}>
          concentration
        </span>
      </div>

      <div style={{ display: "flex", gap: 80, alignItems: "flex-end" }}>
        {/* Concentrated */}
        <div style={{ ...slideFromLeft(frame, 20), opacity: fadeIn(frame, 20) }}>
          <div style={{ fontFamily: headingFont, fontSize: 160, fontWeight: 900, color: COLORS.terracotta, lineHeight: 1 }}>22%</div>
          <div style={{ fontFamily: bodyFont, fontSize: 36, fontWeight: 600, color: COLORS.brownLight, marginTop: 8 }}>1× System 9</div>
        </div>

        {/* VS */}
        <div style={{ opacity: fadeIn(frame, 35), fontFamily: headingFont, fontSize: 60, fontWeight: 900, color: COLORS.beigeDark, paddingBottom: 20 }}>
          vs
        </div>

        {/* Spread */}
        <div style={{ ...slideFromRight(frame, 45), opacity: fadeIn(frame, 45) }}>
          <div style={{ fontFamily: headingFont, fontSize: 160, fontWeight: 900, color: COLORS.sage, lineHeight: 1 }}>49%</div>
          <div style={{ fontFamily: bodyFont, fontSize: 36, fontWeight: 600, color: COLORS.brownLight, marginTop: 8 }}>12 ordinary tickets</div>
        </div>
      </div>

      <div style={{ ...slideFromLeft(frame, 75), marginTop: 40 }}>
        <span style={{ fontFamily: bodyFont, fontSize: 44, fontWeight: 600, color: COLORS.sage }}>Same $84 spend.{" "}</span>
        <span style={{ fontFamily: bodyFont, fontSize: 44, fontWeight: 400, color: COLORS.brownLight }}>Keep them independent.</span>
      </div>
    </AbsoluteFill>
  );
};

// ─── Scene 5: Calculator (690–810 / 23–27s) ──────────────────────────────

const SceneCalculator = () => {
  const frame = useCurrentFrame();

  const stats = [
    { value: "49.3%", label: "Win anything", color: COLORS.sage, delay: 25 },
    { value: "1:969", label: "Win ~$1,000", color: COLORS.terracotta, delay: 45 },
    { value: "1:140K", label: "Win jackpot", color: COLORS.brown, delay: 65 },
  ];

  return (
    <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "center", paddingLeft: 120 }}>
      <div style={{ ...slideFromLeft(frame, 5), marginBottom: 56 }}>
        <span style={{ fontFamily: headingFont, fontSize: 180, fontWeight: 900, color: COLORS.brown, letterSpacing: "-0.03em", display: "block", lineHeight: 1 }}>
          We built a
        </span>
        <span style={{ fontFamily: headingFont, fontSize: 180, fontWeight: 900, color: COLORS.terracotta, letterSpacing: "-0.03em", display: "block", lineHeight: 1, marginTop: -16 }}>
          calculator.
        </span>
      </div>

      <div style={{ display: "flex", gap: 60 }}>
        {stats.map((s, i) => (
          <div key={s.label} style={{ ...slideUp(frame, s.delay, 60, 28) }}>
            <div style={{ fontFamily: headingFont, fontSize: 140, fontWeight: 900, color: s.color, lineHeight: 1 }}>{s.value}</div>
            <div style={{ fontFamily: bodyFont, fontSize: 36, fontWeight: 500, color: COLORS.brownLight, marginTop: 12 }}>{s.label}</div>
          </div>
        ))}
      </div>

      <div style={{ ...slideFromLeft(frame, 90), marginTop: 44 }}>
        <span style={{ fontFamily: bodyFont, fontSize: 36, color: COLORS.brownLight, fontStyle: "italic" }}>
          Strategy adjusts to your parameters. Automatically.
        </span>
      </div>
    </AbsoluteFill>
  );
};

// ─── Scene 6: CTA (810–900 / 27–30s) ─────────────────────────────────────

const SceneCTA = () => {
  const frame = useCurrentFrame();
  const s = scaleIn(frame, 10);

  return (
    <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "center", paddingLeft: 120 }}>
      <div style={{ transform: `scale(${s})`, transformOrigin: "left center" }}>
        <span style={{ fontFamily: headingFont, fontSize: 180, fontWeight: 900, color: COLORS.brown, letterSpacing: "-0.03em" }}>
          ⢕ steamboat
        </span>
      </div>

      <div style={{ ...slideFromLeft(frame, 35), display: "flex", gap: 28, marginTop: 24 }}>
        <span style={{ fontFamily: bodyFont, fontSize: 48, fontWeight: 600, color: COLORS.brownLight, letterSpacing: "0.06em" }}>I LEARN</span>
        <span style={{ fontSize: 48, color: COLORS.beigeDark }}>·</span>
        <span style={{ fontFamily: bodyFont, fontSize: 48, fontWeight: 600, color: COLORS.terracotta, letterSpacing: "0.06em" }}>I BUILD</span>
        <span style={{ fontSize: 48, color: COLORS.beigeDark }}>·</span>
        <span style={{ fontFamily: bodyFont, fontSize: 48, fontWeight: 600, color: COLORS.sage, letterSpacing: "0.06em" }}>I SHARE</span>
      </div>

      <div style={{ ...slideFromLeft(frame, 55) }}>
        <span style={{ fontFamily: bodyFont, fontSize: 36, color: COLORS.brownLight, marginTop: 28, display: "block", opacity: 0.7 }}>
          0xsteamboat.me/projects/toto
        </span>
      </div>
    </AbsoluteFill>
  );
};

// ─── Main Composition ──────────────────────────────────────────────────────

export const TotoVideo = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.cream, fontFamily: bodyFont }}>
      <Audio src={staticFile("toto-vo.mp3")} />
      <Background />
      <Sequence from={0} durationInFrames={150}><SceneHook /></Sequence>
      <Sequence from={135} durationInFrames={210}><SceneMyths /></Sequence>
      <Sequence from={330} durationInFrames={195}><SceneEV /></Sequence>
      <Sequence from={510} durationInFrames={195}><SceneStrategy /></Sequence>
      <Sequence from={690} durationInFrames={135}><SceneCalculator /></Sequence>
      <Sequence from={810} durationInFrames={90}><SceneCTA /></Sequence>
    </AbsoluteFill>
  );
};
