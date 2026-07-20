# toto

Standalone Singapore TOTO analysis repo. Three main modules:

- `site/` — Vite + React + Tailwind SPA with strategy calculator, myth-busting, EV charts, frequency data
- `video/` — Remotion 4 project for the 30-second explainer video
- `api/` — Hono API route for next draw date + jackpot
- `mobile/` — Expo (React Native) iOS app; reuses `shared/` via the `mobile/shared` symlink (see `mobile/DEPLOY_IOS.md` for App Store steps)
- `shared/` — single source of truth for draw schedule, palette, stats data, ticket generator, and editorial content

## Key References

- **Live page:** https://www.0xsteamboat.me/projects/toto
- **Draw API:** https://0xsteamboat.zo.space/api/toto/draw
- **Video output:** rendered at `video/output.mp4`

## Conventions

- Site uses Playfair Display (serif) for headings, Inter for body
- Color palette in `site/src/brand.tsx` (cream/terracotta/sage/brown)
- Draw schedule: Mon & Thu, 6:30pm SGT
- All time logic uses SGT (UTC+8)
