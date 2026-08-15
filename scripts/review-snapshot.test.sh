#!/usr/bin/env bash
#
# Runs review-snapshot.sh against a real repository.
#
# Two of these assertions are the review findings that produced the script, kept as tests so the
# fix cannot quietly regress: an edit to an already-modified file, and an edit to an untracked one.
# Both leave `git status --porcelain` byte-identical, which is exactly why the earlier prose
# versions of this procedure looked correct.
#
# Plain bash and git, no framework, because the template ships no stack.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/review-snapshot.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }

snap()   { "$SCRIPT" --repo "$D" | sed -n 's/^snapshot=//p'; }
status() { "$SCRIPT" --repo "$D" | sed -n 's/^status=//p'; }

changed() { # changed <name> <before> <after>
  if [ "$2" != "$3" ]; then pass "$1"; else fail "$1" "snapshot did not move: $2"; fi
}
same() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected no move, got [$2] then [$3]"; fi
}

D="$(mktemp -d)"
git init --quiet -b main "$D"
git -C "$D" config user.email t@t; git -C "$D" config user.name t
printf 'one\n' > "$D/tracked.txt"
printf 'ignored\n' > "$D/.gitignore"
echo "build/" >> "$D/.gitignore"
git -C "$D" add -A; git -C "$D" commit --quiet -m base

echo "review-snapshot.sh"

# --- 1. an untouched tree fingerprints the same twice ------------------------------------------
A="$(snap)"; B="$(snap)"
same "stable on an untouched tree" "$A" "$B"

# --- 2. the round-11 case: editing a file that was already modified ----------------------------
printf 'two\n' > "$D/tracked.txt"          # now modified, and the reviewer has not run yet
BEFORE="$(snap)"; ST_BEFORE="$(status)"
printf 'three\n' > "$D/tracked.txt"        # a "reviewer" edits the same already-modified file
AFTER="$(snap)"; ST_AFTER="$(status)"
same    "already-modified file: git status alone cannot see it" "$ST_BEFORE" "$ST_AFTER"
changed "already-modified file: the snapshot sees it"           "$BEFORE"    "$AFTER"

# --- 3. the round-12 case: editing an untracked file -------------------------------------------
printf 'draft\n' > "$D/new.txt"            # created in phase 5, still untracked
BEFORE="$(snap)"; ST_BEFORE="$(status)"
printf 'edited\n' > "$D/new.txt"           # a "reviewer" edits it
AFTER="$(snap)"; ST_AFTER="$(status)"
same    "untracked file: git status alone cannot see it" "$ST_BEFORE" "$ST_AFTER"
changed "untracked file: the snapshot sees it"           "$BEFORE"    "$AFTER"

# --- 4. a new untracked file ------------------------------------------------------------------
BEFORE="$(snap)"
printf 'extra\n' > "$D/added-by-reviewer.txt"
changed "a new untracked file moves the snapshot" "$BEFORE" "$(snap)"

# --- 5. renaming an untracked file, same bytes -------------------------------------------------
BEFORE="$(snap)"
mv "$D/added-by-reviewer.txt" "$D/renamed.txt"
changed "renaming an untracked file moves the snapshot" "$BEFORE" "$(snap)"

# --- 6. a reviewer that commits ----------------------------------------------------------------
BEFORE="$(snap)"
git -C "$D" add -A; git -C "$D" commit --quiet -m "committed by a reviewer"
changed "a commit moves the snapshot" "$BEFORE" "$(snap)"

# --- 7. ignored files are not the reviewer's doing ----------------------------------------------
mkdir -p "$D/build"
printf 'artifact\n' > "$D/build/out.js"
BEFORE="$(snap)"
printf 'rebuilt\n' > "$D/build/out.js"
printf 'more\n' > "$D/ignored"
same "ignored files do not move the snapshot" "$BEFORE" "$(snap)"

# --- 8. the intent-to-add step subagent-briefs.md tells the run to take ------------------------
#
# Two claims are made there about git's behaviour, and a claim about a tool is worth exactly as
# much as the run that proves it. First: `--intent-to-add` brings an untracked file into
# `git diff HEAD`, which is what lets the reviewers see new code at all. Second: it does not blind
# the snapshot — the file's content moves from the untracked component into the tracked one, and an
# edit still registers.
printf 'fresh\n' > "$D/created-in-phase-5.txt"
printf 'scratch\n' > "$D/not-in-scope.txt"          # an untracked file the plan never approved
git -C "$D" add --intent-to-add -- created-in-phase-5.txt
if git -C "$D" diff HEAD --name-only | grep -qx created-in-phase-5.txt; then
  pass "intent-to-add: the new file appears in git diff HEAD"
else
  fail "intent-to-add: the new file appears in git diff HEAD" "absent from the diff"
fi

if git -C "$D" diff HEAD --name-only | grep -qx not-in-scope.txt; then
  fail "intent-to-add: an unapproved file stays out of the review input" "not-in-scope.txt is in the diff"
else
  pass "intent-to-add: an unapproved file stays out of the review input"
fi

BEFORE="$(snap)"
printf 'edited by a reviewer\n' > "$D/created-in-phase-5.txt"
changed "intent-to-add: an edit to it still moves the snapshot" "$BEFORE" "$(snap)"

rm -rf "$D"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
