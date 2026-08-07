# Don't hand-fill these files yet

This folder is where `deliver` (fastlane's App Store listing tool) reads
`description.txt`, `keywords.txt`, `release_notes.txt`, etc. from — but
it's empty right now on purpose.

**First real step, before anything else:** run

```
bundle exec fastlane pull_metadata
```

That downloads the **actual current live listing** from App Store
Connect into this folder, so you're editing real content, not
overwriting it with blank placeholder files (an empty `description.txt`
would genuinely blank out the live App Store description on the next
`fastlane metadata` push — `deliver` takes these files literally).

Once seeded, edit the `.txt` files here as normal, then
`bundle exec fastlane metadata` to push changes back up.
