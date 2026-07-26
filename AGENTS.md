# toto

Standalone Singapore TOTO analysis repo. Five modules:

- `site/` — Vite + React + Tailwind SPA with strategy calculator, myth-busting, EV charts, frequency data
- `video/` — Remotion 4 project for the 30-second explainer video
- `api/` — Hono API route for next draw date + jackpot
- `ios/` — native SwiftUI iOS app (TotoApp.xcodeproj, Supabase-backed; see `ios/DEPLOY_IOS.md` for App Store steps). Its design source of truth is the "App review request" Claude Design project (`TotoApp Refinements.dc.html` + `docs/design-changes.md`).
- `shared/` — single source of truth for the site/video/api: draw schedule, palette, EV maths, stats data, ticket generator, editorial content

## Key References

- **Live page:** https://www.0xsteamboat.me/projects/toto
- **Draw API:** https://0xsteamboat.zo.space/api/toto/draw
- **Video output:** rendered at `video/output.mp4`

## Conventions

- Site uses Playfair Display (serif) for headings, Inter for body
- Color palette in `shared/palette.ts`, re-exported for the site via `site/src/brand.tsx` (cream/terracotta/sage/brown)
- Draw schedule: Mon & Thu, 6:30pm SGT
- All time logic uses SGT (UTC+8)
- EV and probability figures come from `shared/evMath.ts`, a port of
  `ios/TotoApp/Features/Calculator/EVMath.swift`. Never hardcode an EV or
  odds number in a component or in copy — derive it, so the site, video and
  iOS app cannot drift apart. Change one side, change the other.
- Run `bun run typecheck` and `bun run test` from `site/` before pushing;
  `bun run build` runs the typecheck for you
