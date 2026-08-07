fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run the test suite (no signing needed — safe to run anywhere, anytime).

### ios certs_bootstrap

```sh
[bundle exec] fastlane ios certs_bootstrap
```

ONE-TIME / RARE: (re)generate signing certs+profiles and push them to the encrypted toto-ios-certs repo. Run this yourself, interactively, the first time you set up a new machine, or after a cert expires or is revoked. Never call this from an unattended script — it can invalidate certs other machines are relying on.

### ios beta

```sh
[bundle exec] fastlane ios beta
```

The everyday 'ship a build' command: bumps the build number, builds, and uploads to TestFlight. Does NOT submit for App Review — that's the separate `release` lane, run only after you've tested the build yourself on TestFlight.

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Push App Store listing text/screenshots from fastlane/metadata/ without touching the binary or submitting anything for review. Safe to run any time you've edited the listing copy.

### ios pull_metadata

```sh
[bundle exec] fastlane ios pull_metadata
```

Pulls the CURRENT live App Store Connect listing (description, keywords, release notes, etc.) down into fastlane/metadata/, overwriting local files. Run this once to seed the metadata folder, or any time the listing was edited directly in the ASC web UI and you want that reflected locally.

### ios release

```sh
[bundle exec] fastlane ios release
```

Submits the build already sitting on TestFlight for App Review. Run this ONLY after you've personally tested that build on your phone via TestFlight and are happy with it — this lane assumes that judgment call already happened, it doesn't make it for you. automatic_release is deliberately off: you press the final 'Release This Version' button in ASC yourself once Apple approves.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
