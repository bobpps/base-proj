#!/usr/bin/env bash
#
# Sets up the isolated worktree a task run works in, per docs/engineering/worktrees.md.
#
# This exists as a script rather than as prose because the procedure is deterministic and its
# edge cases are git's, not ours. Six review rounds of specifying it in English produced a
# finding every time; a script can be run, and `worktree-setup.test.sh` runs it.
#
# It does only what is safe without a human, and refuses the rest through distinct exit codes:
#
#   0   ready       — the worktree exists, is synchronised, and can be worked in
#   10  gate        — the branch is checked out outside the configured root
#   11  gate        — the resumed worktree has uncommitted changes
#   12  gate        — a merge conflicted; the merge was aborted and the tree restored
#   13  gate        — the target path is occupied by something that is not a worktree
#   2   usage       — bad arguments or an unusable repository
#
# On exit 0 it prints key=value lines for the caller to read. On a gate it prints the same
# `status=gate` and `gate=<reason>` pair plus whatever context the caller needs to ask a useful
# question — never a suggestion about what to do, which is the human's decision.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: worktree-setup.sh --branch <name> --base <name> --root <dir> [--remote <name>] [--repo <dir>]

  --branch  the task branch. Never the default branch.
  --base    the base branch to integrate with, e.g. main
  --root    directory the worktrees live under, from AGENTS.md, git-ignored
  --remote  the one server this run reads and writes. Required where the repository has more
            than one remote; derived where it has exactly one.
  --repo    repository to operate on. Defaults to the current directory.
USAGE
  exit 2
}

BRANCH="" BASE="" ROOT="" REMOTE="" REPO="."

while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="${2-}"; shift 2 ;;
    --base)   BASE="${2-}";   shift 2 ;;
    --root)   ROOT="${2-}";   shift 2 ;;
    --remote) REMOTE="${2-}"; shift 2 ;;
    --repo)   REPO="${2-}";   shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "$BRANCH" ] && [ -n "$BASE" ] && [ -n "$ROOT" ] || usage

git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "not a git repository: $REPO" >&2
  exit 2
}

# Absolute and physical, because every later comparison is a path comparison: `git worktree list`
# answers with resolved paths, and comparing those against a relative, logical, or unnormalised one
# compares the wrong strings while looking correct.
REPO="$(cd "$REPO" && pwd -P)"
case "$ROOT" in
  /*) ;;
  *) ROOT="$REPO/$ROOT" ;;
esac

# `.worktrees/` is how a directory is naturally written and is the initializer's own default value.
# Left as given, the trailing slash builds `<root>//<branch>` while git reports the single-slash
# path back, so the containment check below misses and every resume gates as checked-out-elsewhere.
while [ "$ROOT" != "/" ] && [ "${ROOT%/}" != "$ROOT" ]; do ROOT="${ROOT%/}"; done
if [ -d "$ROOT" ]; then ROOT="$(cd "$ROOT" && pwd -P)"; fi

if [ "$BRANCH" = "$BASE" ]; then
  echo "refusing to work on the base branch: $BRANCH" >&2
  exit 2
fi

# --- Which remote? ----------------------------------------------------------------------------
#
# **One server per run, and it is never guessed.** `--remote` — or the sole remote where there is
# only one — names the single server this run reads and writes: it is fetched, the branch is
# created from it, both merges come from it, and phase 10 pushes to it. Branches living on any
# other remote are outside this run by definition, not by oversight.
#
# The narrowness is the point, and it was bought expensively. Four review rounds each found a new
# place where "which server" was being inferred — from the name `origin`, from a fallback, from the
# branch configuration, from the absence of branch configuration — and each fix was correct and
# closed only the site it was about. Inference has no natural stopping point here, because the
# repository does not hold the answer: a branch on `origin` and a base on `upstream` is a coherent
# arrangement, and no rule reading the repository can tell which one this task belongs to. So the
# procedure stops asking, and requires the answer where several are possible.
remotes="$(git -C "$REPO" remote)"
remote_count="$(printf '%s\n' "$remotes" | grep -c . || true)"
remote_list="${remotes//$'\n'/, }"

has_remote() { printf '%s\n' "$remotes" | grep -Fqx -- "$1"; }

if [ -n "$REMOTE" ]; then
  has_remote "$REMOTE" || { echo "no such remote: $REMOTE. Remotes: $remote_list" >&2; exit 2; }
elif [ "$remote_count" = 0 ]; then
  echo "the repository has no remote, and this procedure needs one" >&2
  exit 2
elif [ "$remote_count" = 1 ]; then
  REMOTE="$remotes"
else
  echo "this repository has several remotes: $remote_list" >&2
  echo "This procedure works with one server per run and will not choose for you." >&2
  echo "Name it with --remote, from the Remote row in AGENTS.md." >&2
  exit 2
fi

WT="$ROOT/$BRANCH"

emit_gate() {
  echo "status=gate"
  echo "gate=$1"
  shift
  for line in "$@"; do echo "$line"; done
}

# --- Fetch first ------------------------------------------------------------------------------
#
# Everything below classifies against refs. Classifying before fetching reads a branch that exists
# only on the remote as absent, and the run then creates a different branch wearing the same name.
ref_exists() { git -C "$REPO" show-ref --verify --quiet "$1"; }

git -C "$REPO" fetch --prune "$REMOTE" >/dev/null 2>&1 || {
  echo "fetch from $REMOTE failed" >&2
  exit 2
}

# A configured refspec is not a promise about what exists on the server. `git clone --single-branch`
# leaves `remote.<name>.fetch` covering one branch, so the fetch above succeeds while creating no
# remote-tracking ref for the task branch — which then classifies as absent, the run implements
# against a fresh namesake, and the collision surfaces only when the push is rejected at the end of
# an otherwise finished run. So ask for the two refs this procedure needs, by name.
#
# Best-effort: either may legitimately be missing. A task branch usually does not exist yet, and a
# missing base is caught below with a message that says so. Connectivity was proved above, so a
# failure here means the ref is not there rather than that the server is unreachable.
for ref in "$BASE" "$BRANCH"; do
  if ! ref_exists "refs/remotes/$REMOTE/$ref"; then
    git -C "$REPO" fetch "$REMOTE" \
      "+refs/heads/$ref:refs/remotes/$REMOTE/$ref" >/dev/null 2>&1 || true
  fi
done

local_exists=false; ref_exists "refs/heads/$BRANCH" && local_exists=true
remote_exists=false; ref_exists "refs/remotes/$REMOTE/$BRANCH" && remote_exists=true

# No fallback to a local ref of the same name. That ref is not evidence about the server: it can be
# arbitrarily stale, and starting or synchronising a task branch from a stale base puts the branch
# behind before the first edit and defers every base conflict past validation — the exact failure
# the fetched-base rule exists to prevent. A base the remote does not have is a repository this
# procedure cannot set up, not an invitation to substitute.
remote_base="$REMOTE/$BASE"
ref_exists "refs/remotes/$REMOTE/$BASE" || {
  echo "$REMOTE has no branch $BASE, and it was fetched just now." >&2
  echo "Push the base branch, or pass the --base this remote actually carries." >&2
  exit 2
}

# --- Where is the branch checked out? ---------------------------------------------------------
#
# This question is asked first, and its answer wins, because the cases below must be mutually
# exclusive. A branch checked out in the caller's ordinary checkout would otherwise also match
# "exists locally, no tree under the root", and `git worktree add` would fail with git's own
# message instead of opening the gate this run needs.
checked_out_at=""
while IFS= read -r line; do
  case "$line" in
    worktree\ *) candidate="${line#worktree }" ;;
    branch\ refs/heads/*)
      if [ "${line#branch refs/heads/}" = "$BRANCH" ]; then checked_out_at="$candidate"; fi
      ;;
  esac
done < <(git -C "$REPO" worktree list --porcelain)

under_root=false
if [ -n "$checked_out_at" ]; then
  case "$checked_out_at/" in
    "$ROOT"/*) under_root=true ;;
  esac
fi

if [ -n "$checked_out_at" ] && [ "$under_root" = false ]; then
  emit_gate checked-out-elsewhere \
    "branch=$BRANCH" \
    "checked_out_at=$checked_out_at" \
    "root=$ROOT"
  exit 10
fi

# --- Is the target path free? -------------------------------------------------------------------
#
# A path that exists but is not a registered worktree — a failed cleanup, an interrupted setup, a
# stray directory — makes `git worktree add` fail with git's own status 128, which `set -e` turns
# into an exit code this procedure never documented and the pipeline has no meaning for. Whether
# that directory is leftover garbage or somebody's unrelated work is a human question, so it opens
# a gate instead of being removed here.
#
# An empty directory is left alone: `git worktree add` accepts one, and gating on it would refuse a
# state that works.
if [ -z "$checked_out_at" ] && [ -e "$WT" ]; then
  occupied=yes
  if [ -d "$WT" ] && [ -z "$(ls -A "$WT" 2>/dev/null)" ]; then occupied=no; fi
  if [ "$occupied" = yes ]; then
    emit_gate path-occupied \
      "branch=$BRANCH" \
      "path=$WT" \
      "registered_worktree=no"
    exit 13
  fi
fi

# --- Establish the worktree -------------------------------------------------------------------
if [ -n "$checked_out_at" ]; then
  CASE=resumed
  WT="$checked_out_at"
elif [ "$local_exists" = true ]; then
  CASE=added-existing
  mkdir -p "$(dirname "$WT")"
  git -C "$REPO" worktree add "$WT" "$BRANCH" >/dev/null
elif [ "$remote_exists" = true ]; then
  CASE=created-from-remote
  mkdir -p "$(dirname "$WT")"
  git -C "$REPO" worktree add "$WT" -b "$BRANCH" "$REMOTE/$BRANCH" >/dev/null
else
  # From the fetched base, never the local one: a stale local base would put the new branch
  # behind before a single edit, and defer every base conflict past validation.
  CASE=created-new
  mkdir -p "$(dirname "$WT")"
  git -C "$REPO" worktree add "$WT" -b "$BRANCH" "$remote_base" >/dev/null
fi

if [ "$CASE" = resumed ] && [ -n "$(git -C "$WT" status --porcelain)" ]; then
  emit_gate dirty-resume \
    "branch=$BRANCH" \
    "worktree=$WT" \
    "changed_paths=$(git -C "$WT" status --porcelain | wc -l | tr -d ' ')"
  exit 11
fi

# --- Synchronise ------------------------------------------------------------------------------
#
# An ordinary merge, not --ff-only: the local branch and its remote can hold different commits at
# once — a previous run here, a collaborator there — and --ff-only aborts on exactly that case
# while naming it as expected. Rebase is not an option: the branch may already be pushed.
merge_or_gate() {
  local ref="$1"
  if ! git -C "$WT" merge --no-edit "$ref" >/dev/null 2>&1; then
    git -C "$WT" merge --abort >/dev/null 2>&1 || true
    emit_gate merge-conflict \
      "branch=$BRANCH" \
      "worktree=$WT" \
      "conflicting_ref=$ref" \
      "tree_state=restored"
    exit 12
  fi
}

synced_branch=n/a
synced_base=n/a

case "$CASE" in
  created-new)
    : ;;                                     # created at the fetched base; nothing to integrate
  created-from-remote)
    merge_or_gate "$remote_base"; synced_base=yes ;;
  added-existing|resumed)
    if [ "$remote_exists" = true ]; then merge_or_gate "$REMOTE/$BRANCH"; synced_branch=yes; fi
    merge_or_gate "$remote_base"; synced_base=yes ;;
esac

echo "status=ready"
echo "case=$CASE"
echo "branch=$BRANCH"
echo "worktree=$WT"
echo "remote=$REMOTE"
echo "base_ref=$remote_base"
echo "synced_branch=$synced_branch"
echo "synced_base=$synced_base"
echo "head=$(git -C "$WT" rev-parse HEAD)"
