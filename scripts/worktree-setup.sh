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
  --remote  remote name. Derived from the repository when omitted.
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
# Read out of the authority that holds the fact, never out of a convention. `origin` is a default
# that clone happens to write, not a statement that this repository's canonical server is origin —
# a fork, a mirror, or a second push target all break that inference while leaving the name in
# place. The wrong answer here poisons everything below it: the fetch, the ref the branch is
# created from, both merges, and the push the run has not made yet.
remotes="$(git -C "$REPO" remote)"
remote_count="$(printf '%s\n' "$remotes" | grep -c . || true)"
remote_list="${remotes//$'\n'/, }"

has_remote() { printf '%s\n' "$remotes" | grep -Fqx -- "$1"; }

# git records a branch's server in `branch.<name>.remote`, which is readable without checking the
# branch out. A value of `.` means it tracks a local branch and names no server; a value naming a
# remote that has since been removed names no server either.
remote_of_branch() {
  local configured
  configured="$(git -C "$REPO" config --get "branch.$1.remote" || true)"
  [ -n "$configured" ] && [ "$configured" != "." ] && has_remote "$configured" || return 0
  printf '%s' "$configured"
}

if [ -n "$REMOTE" ]; then
  has_remote "$REMOTE" || { echo "no such remote: $REMOTE. Remotes: $remote_list" >&2; exit 2; }
elif [ "$remote_count" = 0 ]; then
  echo "the repository has no remote, and this procedure needs one" >&2
  exit 2
elif [ "$remote_count" = 1 ]; then
  REMOTE="$remotes"
else
  base_remote="$(remote_of_branch "$BASE")"
  branch_remote="$(remote_of_branch "$BRANCH")"

  # A fork workflow — base tracking one server, the task branch another — is a real arrangement
  # that this procedure's single `--remote` cannot express. Refusing is the honest answer, and it
  # is deliberately stricter than picking either one: a silent choice here is the defect this
  # whole block exists to remove. Where both agree, or only one is configured, the order they are
  # read in decides nothing.
  if [ -n "$base_remote" ] && [ -n "$branch_remote" ] && [ "$base_remote" != "$branch_remote" ]; then
    echo "$BASE tracks $base_remote and $BRANCH tracks $branch_remote; pass --remote" >&2
    exit 2
  fi

  REMOTE="${base_remote:-$branch_remote}"
  [ -n "$REMOTE" ] || {
    echo "no branch names a remote to derive from; pass --remote. Remotes: $remote_list" >&2
    exit 2
  }
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
git -C "$REPO" fetch --prune "$REMOTE" >/dev/null 2>&1 || {
  echo "fetch from $REMOTE failed" >&2
  exit 2
}

ref_exists() { git -C "$REPO" show-ref --verify --quiet "$1"; }

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
