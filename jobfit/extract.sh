#!/usr/bin/env bash
# Lift jobfit out of its host repository into a standalone one.
#
#     ./extract.sh chintheman/jobfit
#
# Run from anywhere inside the host repo, against an *empty* GitHub repository (no
# README, no .gitignore — an initial commit there gives the push nothing to fast-forward
# from). Everything the standalone repo needs already lives in this directory, so there
# is no post-extraction fixup step: CI, licence and packaging land at the new root.
#
# Idempotent. Re-run after more commits and it pushes the same history plus the new work.
set -euo pipefail

target=${1:-}
if [[ -z $target ]]; then
    echo "usage: $0 <owner>/<repo>   e.g. $0 chintheman/jobfit" >&2
    exit 2
fi

prefix=$(basename "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")
cd "$(git rev-parse --show-toplevel)"

# A throwaway branch name, so a stale one from an earlier run never gets pushed by
# mistake. --rejoin is deliberately not used: it writes a merge commit into the host
# repo's history, and the host repo is about to stop carrying this directory at all.
branch="jobfit-split-$$"
trap 'git branch -qD "$branch" 2>/dev/null || true' EXIT

echo "==> splitting $prefix/ into $branch"
git subtree split --prefix="$prefix" --branch="$branch" >/dev/null

echo "==> pushing to git@github.com:$target"
# Explicit URL rather than a named remote: the host repo's origin points elsewhere, and
# pushing a subtree split to the wrong place is not something you notice quickly.
for attempt in 1 2 3 4; do
    if git push "https://github.com/$target.git" "$branch:main"; then
        echo "==> done — https://github.com/$target"
        exit 0
    fi
    [[ $attempt -eq 4 ]] && break
    delay=$((2 ** attempt))
    echo "push failed, retrying in ${delay}s" >&2
    sleep "$delay"
done

echo "push failed after 4 attempts" >&2
exit 1
