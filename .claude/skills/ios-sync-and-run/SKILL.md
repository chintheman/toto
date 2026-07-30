---
name: ios-sync-and-run
description: Guided runbook for getting the latest chintheman/toto iOS app changes onto the user's Mac, past the repo's recurring mobile/app.json merge conflict, and running in Xcode on a physical device. Use this whenever the user asks to pull/sync/clone the latest iOS changes, mentions getting a PR or merge onto their Mac, says something like "push this to Xcode" / "get this on my phone" / "sync my local clone", or hits a git pull/checkout error involving mobile/app.json, an unmerged path, or a project.pbxproj conflict in this repo. Not for the full App Store submission flow (archive/upload/review) — that's ios/DEPLOY_IOS.md; this skill only covers sync + local device run, and should point to that doc when the user is ready to ship.
---

# iOS sync and run (chintheman/toto)

Xcode only runs on the user's own Mac — this skill can't execute git or
Xcode commands on their machine directly. Its job is to hand them the
*exact* next command for wherever they are in the process, not a wall of
general git advice. Read what they paste back (a terminal screenshot, an
error message, `git status` output) and jump straight to the matching step
below rather than re-explaining the whole flow from the top.

## Why this exists

This repo used to contain a `mobile/` Expo/EAS app that was replaced by the
native `ios/` SwiftUI app (see git log: "Replace Expo app with native
SwiftUI TotoApp + design refinements"). The user's local Mac clone predates
that replacement and still has a `mobile/app.json` with real, meaningful
local edits (their actual Expo EAS `projectId`/`owner` config) that were
never merged upstream. Because the file was deleted from the repo's history
on one side and kept locally on the other, it collides on *every* pull —
not a one-time fluke. Never discard it; the fix each time is to keep the
user's local version and move on.

## Step 1: Sync to latest `main`

Give the user this block to run:

```bash
git checkout main
git fetch origin main
git pull origin main
```

### If `mobile/app.json` blocks it

Three shapes this shows up in, matched to what the user pastes back:

**A. Plain uncommitted local diff** (git status just shows it modified, no
"Unmerged paths" section) — stash it out of the way, pull, restore it:
```bash
git stash push -- mobile/app.json
git pull origin main
git stash pop
```

**B. Already conflicted, normal two-sided conflict** (`git status` shows
"Unmerged paths", `git checkout`/`git pull` refuse with "you have unmerged
files"):
```bash
git checkout --ours mobile/app.json
git add mobile/app.json
git status
```

**C. `git checkout --ours` itself fails** with `error: path 'mobile/app.json'
does not have our version` — this happens when the file exists on the
incoming side but isn't tracked in the user's current HEAD at all (a
different unmerged-path shape than B, not a real error to troubleshoot
further). The fix is simpler: `git add` alone stages the working-tree
version as-is, which is exactly "keep local":
```bash
git add mobile/app.json
git status
```

After B or C, check what `git status` says:
- **"All conflicts fixed but you are still merging"** → `git commit --no-edit`, then retry `git pull origin main`.
- **"Changes to be committed: new file: mobile/app.json"** (no merge in progress, just a local branch that's behind) → commit and pull:
  ```bash
  git commit -m "Keep local Expo/EAS config"
  git pull origin main
  ```

Stray untracked entries like `mobile/.expo/`, `mobile/package-lock.json`,
or a leftover `toto/` subfolder are harmless local build artifacts — leave
them, don't clean them up as part of this flow, they won't block a pull
unless origin happens to add those exact paths (it doesn't).

### If `project.pbxproj` blocks it instead

Xcode sometimes re-sorts existing `PBXBuildFile`/`PBXFileReference` entries
in `ios/TotoApp.xcodeproj/project.pbxproj` with no real content change.
Confirm with `git diff ios/TotoApp.xcodeproj/project.pbxproj` — if it's
pure reordering (same entries, different order, nothing added or removed),
it's safe to discard:
```bash
git checkout -- ios/TotoApp.xcodeproj/project.pbxproj
git pull origin main
```
If the diff shows real new/removed entries instead, stop and ask before
discarding — that could be a genuine registration for a new Swift file.

### Confirm the sync worked

```bash
git log -1 --oneline
```
Tell the user what commit that is (cross-check against the PR/merge commit
they're expecting) so they know they're actually looking at the new code,
not a stale checkout.

## Step 2: Build and run on device

```bash
open ios/TotoApp.xcodeproj
```

Then in Xcode:
1. **Product → Clean Build Folder** (⇧⌘K) — worth doing after any pull/merge,
   avoids stale-derived-data build weirdness that looks like a real bug but
   isn't.
2. Pick the physical iPhone in the toolbar's run-destination menu (not a
   simulator).
3. **Product → Run** (⌘R).
4. First run on a given device only: the phone will show an "Untrusted
   Developer" prompt — Settings → General → VPN & Device Management → tap
   the developer profile → Trust.

## Step 3: Ready to ship?

If the user wants to actually submit to the App Store (archive, upload,
App Store Connect listing, version bump), don't duplicate that here — read
and follow `ios/DEPLOY_IOS.md` in this repo instead, so the two guides
can't drift apart. This skill's job ends at "running on my phone."
