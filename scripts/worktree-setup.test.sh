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

# --- 11. several remotes: refuse rather than infer ----------------------------------------------
#
# Every branch here is configured exactly as a normal clone leaves it, so a procedure willing to
# infer would find plenty to infer from. It must still refuse: the repository cannot say which of
# two servers this task belongs to, and four review rounds were spent discovering that no reading
# of it can.
D="$(new_fixture)"
git -C "$D/clone" remote add mirror "$D/remote.git"
run "$D/clone"
check "several remotes: exit 2" "2" "$RC"
if printf '%s\n' "$OUT" | grep -q -- --remote; then
  pass "several remotes: the message names the way out"
else
  fail "several remotes: the message names the way out" "no mention of --remote in [$OUT]"
fi
rm -rf "$D"

# --- 12. several remotes with the server named: works, and uses that one ------------------------
D="$(new_fixture)"
git -C "$D/clone" remote add mirror "$D/remote.git"
run "$D/clone" --remote mirror
check "named remote: exit 0"     "0"      "$RC"
check "named remote: is the one used" "mirror" "$(field remote)"
rm -rf "$D"

# --- 13. an explicit remote that does not exist ------------------------------------------------
D="$(new_fixture)"
run "$D/clone" --remote nope
check "unknown --remote: exit 2" "2" "$RC"
rm -rf "$D"

# --- 14. the round-11 blocker: the task branch lives on a remote the run was not told about -----
#
# The reported failure was silent: the branch was classified as absent, a fresh one of the same
# name was created from the base, and phase 10 pushed that unrelated history. Both halves of the
# narrowed promise are asserted here — the refusal when nothing named a server, and the defined
# behaviour when one was named. The second is not a bug: `--remote` means the one server this run
# reads and writes, so a branch on any other is outside the run by definition. It is pinned so
# that nobody later reads it as an oversight and re-opens the inference this cost four rounds.
D="$(new_fixture)"
git init --quiet --bare "$D/fork.git"
git -C "$D/fork.git" symbolic-ref HEAD refs/heads/main
git -C "$D/clone" remote add fork "$D/fork.git"
git -C "$D/seed" remote add fork "$D/fork.git"
git -C "$D/seed" switch --quiet -c feat/x origin/main
echo elsewhere > "$D/seed/elsewhere.txt"
git -C "$D/seed" add -A; git -C "$D/seed" commit --quiet -m "work on the fork"
git -C "$D/seed" push --quiet fork feat/x

run "$D/clone"
check "branch on an unnamed remote: refuses instead of creating a namesake" "2" "$RC"

run "$D/clone" --remote origin
check  "branch on another remote: exit 0"   "0"           "$RC"
check  "branch on another remote: case"     "created-new" "$(field case)"
if [ ! -e "$(field worktree)/elsewhere.txt" ]; then
  pass "branch on another remote: the fork's work is not silently adopted"
else
  fail "branch on another remote: the fork's work is not silently adopted" "elsewhere.txt present"
fi
rm -rf "$D"

# --- 15a. a tracking ref for a branch the server has deleted is not believed ---------------------
#
# `fetch --prune` only revalidates what the configured refspec covers, so in a restricted clone a
# ref this script fetched by name on an earlier run outlives the branch itself. Believing it
# restores the contents of a branch that no longer exists and lets phase 10 recreate it.
D="$(new_fixture)"
push_commit "$D" feat/x work.txt remote-work
rm -rf "$D/clone"
git clone --quiet --single-branch --branch main "$D/remote.git" "$D/clone"
git -C "$D/clone" config user.email t@t; git -C "$D/clone" config user.name t
run "$D/clone"
check "deleted branch: the first run finds it" "created-from-remote" "$(field case)"

git -C "$D/clone" worktree remove --force "$(field worktree)"
git -C "$D/clone" branch -D feat/x >/dev/null 2>&1
git -C "$D/seed" push --quiet origin --delete feat/x

run "$D/clone"
check  "deleted branch: exit 0"                        "0"           "$RC"
check  "deleted branch: not resurrected from the cache" "created-new" "$(field case)"
if [ ! -e "$(field worktree)/work.txt" ]; then
  pass "deleted branch: its contents are not restored"
else
  fail "deleted branch: its contents are not restored" "work.txt came back"
fi
rm -rf "$D"

# --- 15b. a merge that fails without conflicting is not reported as a conflict -------------------
#
# Git fails here for reasons that have nothing to do with content: no configured identity in a
# fresh environment, a signing program that is missing or refuses. Signing is used to reproduce it
# because it fails the same way everywhere, where identity detection does not.
D="$(new_fixture)"
push_commit "$D" feat/x theirs.txt collaborator
git -C "$D/clone" fetch --quiet origin
git -C "$D/clone" switch --quiet -c feat/x origin/main
echo mine > "$D/clone/mine.txt"
git -C "$D/clone" add -A; git -C "$D/clone" commit --quiet -m mine
git -C "$D/clone" switch --quiet main
git -C "$D/clone" config commit.gpgsign true
git -C "$D/clone" config gpg.program /nonexistent-signing-program
run "$D/clone"
check "merge failure: exit 2, not the conflict gate" "2" "$RC"
if printf '%s\n' "$OUT" | grep -q "no conflict to resolve"; then
  pass "merge failure: says what actually happened"
else
  fail "merge failure: says what actually happened" "got [$OUT]"
fi
rm -rf "$D"

# --- 15. the target path occupied by something that is not a worktree ---------------------------
D="$(new_fixture)"
mkdir -p "$D/clone/.worktrees/feat/x"
echo leftover > "$D/clone/.worktrees/feat/x/stale.txt"
run "$D/clone"
check  "occupied path: exit 13" "13"            "$RC"
check  "occupied path: gate"    "path-occupied" "$(field gate)"
exists "occupied path: nothing was removed" "$D/clone/.worktrees/feat/x/stale.txt"
rm -rf "$D"

# --- 16. an empty directory at the target is not an obstruction ---------------------------------
D="$(new_fixture)"
mkdir -p "$D/clone/.worktrees/feat/x"
run "$D/clone"
check "empty target directory: exit 0" "0" "$RC"
rm -rf "$D"

# --- 17. a single-branch clone still sees the task branch ---------------------------------------
#
# `git clone --single-branch` leaves a refspec covering only the base, so a plain fetch succeeds
# and creates no remote-tracking ref for the task branch. Classified on that, the branch reads as
# absent and the run builds a namesake — a collision that surfaces only when the push is rejected.
D="$(new_fixture)"
push_commit "$D" feat/x work.txt remote-work
rm -rf "$D/clone"
git clone --quiet --single-branch --branch main "$D/remote.git" "$D/clone"
git -C "$D/clone" config user.email t@t; git -C "$D/clone" config user.name t
run "$D/clone"
check  "single-branch clone: exit 0" "0"                   "$RC"
check  "single-branch clone: finds the branch on the server" "created-from-remote" "$(field case)"
exists "single-branch clone: carries the remote work" "$(field worktree)/work.txt"
rm -rf "$D"

# --- 16. a root written with a trailing slash still resumes -------------------------------------
#
# `.worktrees/` is how a directory is naturally written and is the initializer's own default. An
# unnormalised root builds `<root>//<branch>` while `git worktree list` reports the single-slash
# path, so the containment check misses and every resume gates as checked-out-elsewhere.
D="$(new_fixture)"
OUT="$("$SCRIPT" --repo "$D/clone" --branch feat/x --base main --root .worktrees/ 2>&1)"; RC=$?
check "trailing slash: first run exit 0" "0" "$RC"
OUT="$("$SCRIPT" --repo "$D/clone" --branch feat/x --base main --root .worktrees/ 2>&1)"; RC=$?
check "trailing slash: second run exit 0" "0"         "$RC"
check "trailing slash: resumes its own tree" "resumed" "$(field case)"
rm -rf "$D"

# --- 16. a base the remote does not have is refused, not silently taken from local --------------
D="$(new_fixture)"
git -C "$D/clone" branch legacy main                 # exists locally, never pushed
OUT="$("$SCRIPT" --repo "$D/clone" --branch feat/x --base legacy --root .worktrees 2>&1)"; RC=$?
check "unfetched base: exit 2" "2" "$RC"
rm -rf "$D"

# --- 10. the base branch is refused ------------------------------------------------------------
D="$(new_fixture)"
OUT="$("$SCRIPT" --repo "$D/clone" --branch main --base main --root .worktrees 2>&1)"; RC=$?
check "base branch refused: exit 2" "2" "$RC"
rm -rf "$D"

# --- 18. a flag whose value is missing ------------------------------------------------------------
#
# `shift 2` with one argument left fails, and the consequence depended only on the `set` line: this
# script exited 1 silently, and its sibling looped forever. Neither is the documented status.
OUT="$(timeout 10 "$SCRIPT" --branch 2>&1)"; RC=$?
check "missing flag value: exit 2, not a hang or a silent 1" "2" "$RC"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
