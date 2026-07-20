# toto

Standalone Singapore TOTO analysis repo. Three main modules:

- `site/` — Vite + React + Tailwind SPA with strategy calculator, myth-busting, EV charts, frequency data
- `video/` — Remotion 4 project for the 30-second explainer video
- `api/` — Hono API route for next draw date + jackpot
- `ios/` — native SwiftUI iOS app (TotoApp.xcodeproj, Supabase-backed; see `ios/DEPLOY_IOS.md` for App Store steps). Its design source of truth is the "App review request" Claude Design project (`TotoApp Refinements.dc.html` + `docs/design-changes.md`).
- `shared/` — single source of truth for the site/video/api: draw schedule, palette, stats data, ticket generator, editorial content

## Key References

- **Live page:** https://www.0xsteamboat.me/projects/toto
- **Draw API:** https://0xsteamboat.zo.space/api/toto/draw
- **Video output:** rendered at `video/output.mp4`

## Conventions

- Site uses Playfair Display (serif) for headings, Inter for body
- Color palette in `site/src/brand.tsx` (cream/terracotta/sage/brown)
- Draw schedule: Mon & Thu, 6:30pm SGT
- All time logic uses SGT (UTC+8)
