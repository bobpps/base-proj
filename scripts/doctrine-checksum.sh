#!/usr/bin/env bash
#
# Prints a checksum over `docs/engineering/` — the doctrine layer.
#
# `init-project` fills in every project-specific value in this repository and must never touch a
# doctrine file. That is the load-bearing property of the whole two-layer design: the interview
# cannot weaken a rule, because no question it asks is capable of reaching one.
#
# A property that important should be checked rather than intended, so the skill records this
# checksum before its first question and compares it after its last write. Before-and-after is what
# makes the check work without a stored manifest: a clone whose git history was replaced — which is
# exactly what the template's own setup instructions tell people to do — has nothing to diff
# against, and a manifest committed alongside the files it describes is edited by whoever edits
# them.
#
#   ./doctrine-checksum.sh [--repo <dir>] [--dir <path>]
#
# Paths are hashed alongside contents, so a file that is deleted, renamed, or added registers just
# as a changed line does.

set -euo pipefail

REPO="."
DIR="docs/engineering"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2-}"; shift 2 ;;
    --dir)  DIR="${2-}";  shift 2 ;;
    -h|--help) echo "usage: doctrine-checksum.sh [--repo <dir>] [--dir <path>]" >&2; exit 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -d "$REPO/$DIR" ] || { echo "no such directory: $REPO/$DIR" >&2; exit 2; }

# `find` rather than `git ls-files`: an uncommitted or untracked change to a doctrine file is
# exactly the kind this check exists to catch, and git would not list it.
sum="$(
  find "$REPO/$DIR" -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s\n' "${f#"$REPO"/}"
    cat -- "$f"
  done | git hash-object --stdin
)"

echo "dir=$DIR"
echo "files=$(find "$REPO/$DIR" -type f | wc -l | tr -d ' ')"
echo "doctrine=$sum"
