# TotoApp (iOS)

Native SwiftUI app, iOS 17+. This project is generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` rather
than committing an `.xcodeproj` directly — this session can write Swift code
but cannot run Xcode to generate/validate project files, so XcodeGen is the
reliable headless path.

## Build (on your Mac)

```bash
brew install xcodegen
cd ios/TotoApp
xcodegen generate
open TotoApp.xcodeproj
```

Then build & run in Xcode (Cmd+R) targeting the Simulator or your device.

## Configuration needed before it'll run for real

- `Core/Networking/SupabaseClients.swift` currently has placeholder
  `SUPABASE_DATA_URL` / `SUPABASE_DATA_ANON_KEY` values — replace with the
  real `toto-data` Supabase project's URL and anon (public) key once that
  project exists. **Never put the `toto-recommendation` project's anon key
  or any service_role key in this app** — that project is only ever reached
  through its Edge Functions once Phase 3 (paid recommendations) is built.
- `project.yml`'s `DEVELOPMENT_TEAM` is blank — fill in your Apple Developer
  Team ID once you're enrolled (not required for Simulator builds, only for
  running on a physical device or anything involving push/StoreKit later).

## What's here (Phase 1 scope)

Onboarding (mandatory fallacy carousel), Home, History, Numbers, Learn,
Calculator. No push notifications (Phase 2) or paid recommendation engine
(Phase 3) yet — see `/root/.claude/plans/steady-herding-kazoo.md` in the
planning session, or ask for the plan to be re-shared, for the full phase
breakdown.

## Testing note

This session cannot compile or run this project (no Xcode/Simulator in a
Linux container) — every file here is unverified by an actual build.
Expect the first `xcodegen generate` + build on your Mac to surface
compile errors to fix together.
