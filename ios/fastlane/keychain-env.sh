#!/usr/bin/env bash
#
# Runs any command with the App Store Connect credentials loaded from the
# macOS Keychain, e.g.
#
#   fastlane/keychain-env.sh bundle exec fastlane beta
#
# This is the Keychain equivalent of `op run --env-file=... --`: the secrets
# exist only in the child process's environment, never on disk and never in
# this repo. Nothing is echoed — don't add `set -x` here.
#
# The three App Store Connect items live under the Keychain account
# `toto-asc`. See SETUP.md for how to create them.

set -euo pipefail

ACCOUNT="toto-asc"

# Reads one Keychain item. `security -w` hex-encodes any value containing
# embedded newlines, which is true of the multi-line .p8 PEM but not of the
# plain single-line IDs — so decode only when the value actually looks like
# hex. Getting this wrong surfaces later as a confusing "MalformedFraming"
# error from the JWT signer rather than anything mentioning the Keychain.
read_secret() {
  local service="$1" value
  if ! value="$(security find-generic-password -a "$ACCOUNT" -s "$service" -w 2>/dev/null)"; then
    echo "keychain-env.sh: missing Keychain item '$service' (account '$ACCOUNT')." >&2
    echo "  Add it with: security add-generic-password -a $ACCOUNT -s $service -w" >&2
    echo "  See ios/fastlane/SETUP.md." >&2
    return 1
  fi
  if [[ "$value" =~ ^([0-9A-Fa-f]{2})+$ && ${#value} -gt 64 ]]; then
    printf '%s' "$value" | xxd -r -p
  else
    printf '%s' "$value"
  fi
}

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") <command> [args...]" >&2
  echo "example: $(basename "$0") bundle exec fastlane beta" >&2
  exit 64
fi

APP_STORE_CONNECT_API_KEY_ID="$(read_secret toto-asc-api-key-id)"
APP_STORE_CONNECT_API_ISSUER_ID="$(read_secret toto-asc-issuer-id)"
APP_STORE_CONNECT_API_KEY_CONTENT="$(read_secret toto-asc-api-key-p8)"
export APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_API_ISSUER_ID APP_STORE_CONNECT_API_KEY_CONTENT

# Only the lanes that touch signing (anything calling `match`) need this, so a
# missing passphrase is a warning rather than a hard failure — `fastlane test`
# and `pull_metadata` run fine without it.
if MATCH_PASSWORD="$(read_secret toto-asc-match-password 2>/dev/null)"; then
  export MATCH_PASSWORD
else
  echo "keychain-env.sh: no 'toto-asc-match-password' in the Keychain — continuing." >&2
  echo "  Signing lanes (beta, release, certs_bootstrap) will fail without it." >&2
fi

exec "$@"
