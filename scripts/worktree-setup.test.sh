#!/usr/bin/env bash
#
# Runs worktree-setup.sh against real git repositories, one per case.
#
# Every assertion here is about what git actually did, not about what the script says it did:
# the whole reason this procedure became a script is that reasoning about git's behaviour in
# prose produced a defect in six consecutive review rounds.
#
# Plain bash and git, no test framework, because the template ships no stack and this has to run
# in a fresh clone of it.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/worktree-setup.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }

check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2], got [$3]"; fi
}

field() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p"; }

exists() { # exists <name> <path...>
  local name="$1"; shift
  local missing=""
  for f in "$@"; do [ -e "$f" ] || missing="$missing $f"; done
  if [ -z "$missing" ]; then pass "$name"; else fail "$name" "missing:$missing"; fi
}

# A bare "remote" plus a clone, with one commit on main. Echoes the temp directory.
new_fixture() {
  local dir; dir="$(mktemp -d)"
  git init --quiet --bare "$dir/remote.git"
  git -C "$dir/remote.git" symbolic-ref HEAD refs/heads/main
  git init --quiet -b main "$dir/seed"
  git -C "$dir/seed" config user.email t@t; git -C "$dir/seed" config user.name t
  echo base > "$dir/seed/base.txt"
  git -C "$dir/seed" add -A; git -C "$dir/seed" commit --quiet -m base
  git -C "$dir/seed" remote add origin "$dir/remote.git"
  git -C "$dir/seed" push --quiet -u origin main
  git clone --quiet "$dir/remote.git" "$dir/clone"
  git -C "$dir/clone" config user.email t@t; git -C "$dir/clone" config user.name t
  echo "$dir"
}

# Commits <file> on <branch> in the seed clone and pushes it.
push_commit() { # push_commit <dir> <branch> <file> <content>
  local d="$1/seed"
  if git -C "$d" show-ref --verify --quiet "refs/heads/$2"; then
    git -C "$d" switch --quiet "$2"
  else
    git -C "$d" switch --quiet -c "$2" origin/main
  fi
  echo "$4" > "$d/$3"
  git -C "$d" add -A
  git -C "$d" commit --quiet -m "$2: $3"
  git -C "$d" push --quiet -u origin "$2"
}

# Sets OUT and RC. Not a subshell — RC has to survive.
run() { # run <clone> [extra args...]
  local clone="$1"; shift
  OUT="$("$SCRIPT" --repo "$clone" --branch feat/x --base main --root .worktrees "$@" 2>&1)"
  RC=$?
}

echo "worktree-setup.sh"

# --- 1. no branch anywhere: created from the fetched base --------------------------------------
D="$(new_fixture)"
push_commit "$D" main newer.txt moved-on            # the base advanced after the clone
run "$D/clone"
check  "new branch: exit 0"  "0"           "$RC"
check  "new branch: case"    "created-new" "$(field case)"
exists "new branch: starts from the fetched base, not the stale local one" "$(field worktree)/newer.txt"
rm -rf "$D"

# --- 2. branch exists only on the remote -------------------------------------------------------
D="$(new_fixture)"
push_commit "$D" feat/x work.txt remote-work
push_commit "$D" main newer.txt base-moved
run "$D/clone"
check  "remote-only: exit 0"       "0"                   "$RC"
check  "remote-only: case"         "created-from-remote" "$(field case)"
check  "remote-only: base merged"  "yes"                 "$(field synced_base)"
exists "remote-only: carries the remote branch and the base" \
       "$(field worktree)/work.txt" "$(field worktree)/newer.txt"
rm -rf "$D"

# --- 3. local branch behind its own remote and behind the base ---------------------------------
D="$(new_fixture)"
git -C "$D/clone" switch --quiet -c feat/x
git -C "$D/clone" switch --quiet main
push_commit "$D" feat/x ahead.txt pushed-elsewhere
push_commit "$D" main newer.txt base-moved
run "$D/clone"
check  "local behind: exit 0"        "0"              "$RC"
check  "local behind: case"          "added-existing" "$(field case)"
check  "local behind: branch merged" "yes"            "$(field synced_branch)"
exists "local behind: picks up its own remote head and the base" \
       "$(field worktree)/ahead.txt" "$(field worktree)/newer.txt"
rm -rf "$D"

# --- 4. running twice resumes the same tree ----------------------------------------------------
D="$(new_fixture)"
run "$D/clone"; FIRST="$(field worktree)"
run "$D/clone"
check "resume: exit 0"    "0"       "$RC"
check "resume: case"      "resumed" "$(field case)"
check "resume: same tree" "$FIRST"  "$(field worktree)"
rm -rf "$D"

# --- 5. resuming a dirty tree gates ------------------------------------------------------------
D="$(new_fixture)"
run "$D/clone"; WT="$(field worktree)"
echo half-finished > "$WT/wip.txt"
push_commit "$D" main newer.txt base-moved
run "$D/clone"
check  "dirty resume: exit 11" "11"           "$RC"
check  "dirty resume: gate"    "dirty-resume" "$(field gate)"
exists "dirty resume: leaves the uncommitted work alone" "$WT/wip.txt"
rm -rf "$D"

# --- 6. branch checked out in the caller's ordinary checkout gates ------------------------------
D="$(new_fixture)"
git -C "$D/clone" switch --quiet -c feat/x
run "$D/clone"
check "checked out elsewhere: exit 10" "10"                    "$RC"
check "checked out elsewhere: gate"    "checked-out-elsewhere" "$(field gate)"
rm -rf "$D"

# --- 7. divergent histories merge instead of aborting ------------------------------------------
D="$(new_fixture)"
push_commit "$D" feat/x theirs.txt collaborator
git -C "$D/clone" fetch --quiet origin
git -C "$D/clone" switch --quiet -c feat/x origin/main       # unrelated local commits
echo mine > "$D/clone/mine.txt"
git -C "$D/clone" add -A; git -C "$D/clone" commit --quiet -m mine
git -C "$D/clone" switch --quiet main
run "$D/clone"
check  "divergent: exit 0"        "0"   "$RC"
check  "divergent: branch merged" "yes" "$(field synced_branch)"
exists "divergent: both sides survive the merge" \
       "$(field worktree)/mine.txt" "$(field worktree)/theirs.txt"
rm -rf "$D"

# --- 8. a conflicting merge gates and restores the tree ----------------------------------------
D="$(new_fixture)"
push_commit "$D" feat/x clash.txt theirs
git -C "$D/clone" fetch --quiet origin
git -C "$D/clone" switch --quiet -c feat/x origin/main
echo mine > "$D/clone/clash.txt"
git -C "$D/clone" add -A; git -C "$D/clone" commit --quiet -m mine
git -C "$D/clone" switch --quiet main
run "$D/clone"
check "conflict: exit 12" "12"             "$RC"
check "conflict: gate"    "merge-conflict" "$(field gate)"
WT="$(field worktree)"
if [ -n "$WT" ] && ! git -C "$WT" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  pass "conflict: no merge left in progress"
else
  fail "conflict: no merge left in progress" "MERGE_HEAD still present in [$WT]"
fi
rm -rf "$D"

# --- 9. a non-origin remote is derived rather than assumed -------------------------------------
D="$(new_fixture)"
git -C "$D/clone" remote rename origin upstream
run "$D/clone"
check "derived remote: exit 0" "0"        "$RC"
check "derived remote: used"   "upstream" "$(field remote)"
rm -rf "$D"

# --- 10. the base branch is refused ------------------------------------------------------------
D="$(new_fixture)"
OUT="$("$SCRIPT" --repo "$D/clone" --branch main --base main --root .worktrees 2>&1)"; RC=$?
check "base branch refused: exit 2" "2" "$RC"
rm -rf "$D"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
