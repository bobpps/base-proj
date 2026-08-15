#!/usr/bin/env bash
#
# Prints a fingerprint of the working tree for the phase 7 review fan-out, per
# docs/engineering/subagent-briefs.md.
#
# Reviewers advise and never edit. This is how that gets checked rather than assumed: take the
# fingerprint before launching the passes, take it again afterwards, compare. A tree that moved
# means an agent exceeded its role, and that has to be known before those changes reach the commit
# — an unadjudicated reviewer fix is the one change nobody in the pipeline ever decided to make.
#
# It is a script because the same procedure was specified in prose twice and was wrong both times.
# First it compared only `git status --porcelain`, which is byte-identical when a reviewer edits a
# file that was already modified. Then it compared a diff that omits untracked files, which is what
# most new files are until phase 10 stages them. Both defects read as correct.
#
#   ./review-snapshot.sh [--repo <dir>]
#
# Compare `snapshot=`. The four components are printed so a difference can be placed without
# re-deriving it: which of head, status, tracked content, or untracked content moved.

set -euo pipefail

REPO="."
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2-}"; shift 2 ;;
    -h|--help) echo "usage: review-snapshot.sh [--repo <dir>]" >&2; exit 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "not a git repository: $REPO" >&2
  exit 2
}

hash_stdin() { git -C "$REPO" hash-object --stdin; }

# HEAD moves when a reviewer commits, which neither the status nor the diff would report: a commit
# takes the change out of both.
if head="$(git -C "$REPO" rev-parse HEAD 2>/dev/null)"; then
  tracked="$(git -C "$REPO" diff HEAD | hash_stdin)"
else
  head=none
  tracked="$(git -C "$REPO" diff | hash_stdin)"
fi

# Which paths are involved, untracked ones included as `??`. Sorted, because the order git reports
# in is not part of the answer.
status="$(git -C "$REPO" status --porcelain | LC_ALL=C sort | hash_stdin)"

# Untracked content, which `git diff HEAD` does not see at all. The path is hashed alongside the
# bytes so that renaming an untracked file registers. Ignored files are left out deliberately:
# build output moving is not a reviewer exceeding its role, and hashing it would make the check
# fail for the wrong reason on every run that compiles anything.
untracked="$(
  git -C "$REPO" ls-files --others --exclude-standard | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s\n' "$f"
    if [ -f "$REPO/$f" ]; then cat -- "$REPO/$f"; else printf '<not-a-regular-file>\n'; fi
  done | hash_stdin
)"

echo "head=$head"
echo "status=$status"
echo "tracked=$tracked"
echo "untracked=$untracked"
echo "snapshot=$(printf '%s\n%s\n%s\n%s\n' "$head" "$status" "$tracked" "$untracked" | hash_stdin)"
