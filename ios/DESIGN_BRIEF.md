# Design brief for Claude Design — TotoApp visual polish

Paste this into the "App review request" Claude Design project to iterate on
the two screens that currently read as "cheap AI demo." Everything else in
the app (Home, History, Calculator, Picks) is staying as-is for now.

## Context
- Native SwiftUI iOS app, iOS 17+. System typography (SF Pro), SF Symbols,
  standard iOS materials. Portrait only.
- Product: a myth-busting / odds-education app for Singapore TOTO. Tone is
  smart, honest, a little playful, never salesy. "Trust the data."
- Content is live from Supabase (myths carry: myth statement, a green
  "truth" headline, an explanation body, an optional mono stat, a category,
  and currently an emoji).

## Problem 1 — Onboarding carousel looks like an HTML demo
Current build: full-screen dark gradient (#0B0B12 → #2B2A55), a segmented
progress bar, "MYTH n OF 5", a tinted emoji circle + red "THE MYTH" chip,
the myth quote, a "THE TRUTH" divider, a green truth headline, body text, a
mono stat chip, and a white "Next myth" button.

Wanted: a genuinely premium first-run experience. Think Spotify Wrapped /
Duolingo onboarding polish — considered type hierarchy, motion, depth,
texture, a cohesive card treatment. Keep the myth → truth → why structure
and the skippable flow. Deliver as visual direction (layout, color, type,
motion notes) we can implement in SwiftUI.

## Problem 2 — Emojis look cheap
Emojis (🎲 ⏰ 🎂 📊 💸 …) currently mark each myth in the carousel, the myth
detail card, and previously the Learn list. They cheapen the look.

Wanted: a cleaner visual language per myth — e.g. a custom icon set, SF
Symbol treatments with tint systems, numbered/lettered tiles, or an
illustration style. Should scale to ~20 myths across 4 categories
(Randomness & memory · Picking numbers · Money & value · Mind & fairness).

## Problem 3 — Learn tab visual (structure already done in code)
The Learn list is now grouped into the 4 categories above with section
headers, and emojis were removed from the rows for now. It needs the same
elevated visual treatment as the carousel so the two feel like one product
(category headers, row styling, the myth-detail card).

## Deliverable
Screen mockups (carousel page, myth-detail card, Learn list) plus an icon /
color direction for the categories. We'll translate the result back into
SwiftUI, the same way the current screens were built.
