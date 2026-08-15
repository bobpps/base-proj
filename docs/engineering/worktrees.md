# Worktrees

Every task run works in its own git worktree, on its own non-default branch. `checkpoints.md`
states that contract; this file is how it is met.

**The procedure is `scripts/worktree-setup.sh`, and `scripts/worktree-setup.test.sh` proves it
works.** Do not reimplement it in a skill, and do not run the individual git commands by hand —
call the script.

That is a deliberate reversal. This procedure lived as prose inside the two pipeline editions and
produced a defect in six consecutive review rounds: the wrong command form for an existing branch,
no synchronisation at all, synchronisation against the wrong ref, classification before fetching,
a hardcoded remote, overlapping cases, and an abort with no recovery. Every fix was reasoned about
rather than run. A script can be run, and the difference is the whole of `evidence.md` in one
example.

## Calling it

```sh
scripts/worktree-setup.sh \
  --branch <task-branch> \
  --base   <base-branch>      # from AGENTS.md
  --root   <worktree-root>    # from AGENTS.md, git-ignored
  [--remote <name>]           # derived from the repository when omitted
  [--repo   <dir>]            # defaults to the current directory
```

On success it prints key-value lines for the run to read:

```
status=ready
case=created-new | created-from-remote | added-existing | resumed
branch=…  worktree=…  remote=…  base_ref=…
synced_branch=yes|n/a   synced_base=yes|n/a
head=<sha>
```

`worktree=` is the path everything afterwards happens in. `case=` says which situation the run was
actually in, which belongs in `implementation.md` — a resumed run and a fresh one produce different
records and it should be possible to tell them apart later.

## The exit codes

| Code | Meaning | What the run does |
| --- | --- | --- |
| 0 | Ready | Continue: write `plan.md`, then implement |
| 10 | The branch is checked out outside the configured root | **Gate.** Offer a different branch, or ask the human to free that checkout |
| 11 | The resumed worktree has uncommitted changes | **Gate.** Read the artifacts, establish which phase the run reached, then either commit that work as its own unit or ask how to reconcile it |
| 12 | A merge conflicted; it was aborted and the tree restored | **Gate.** The conflict is a human decision, and the output names the ref it conflicted with |
| 2 | Bad arguments, or an unusable repository | Not a gate — a bug in the caller or a missing `AGENTS.md` value. Fix it and re-run |

**A gate is never worked around.** The script refuses precisely the operations that would need a
decision, and a run that reaches for the underlying git commands after a non-zero exit has
substituted its own judgement for the human's.

On exit 10, do **not** offer to run in the caller's ordinary checkout. It sits outside the
configured root, so working there breaks the isolation contract, and it can hold unrelated work
that a later stage would sweep into this run's commits. A human confirming the tree "is clean"
describes one moment rather than a property of the tree.

## Why the rules are what they are

The script implements these. They are written down because a rule whose reason is lost gets
deleted by whoever next finds it inconvenient.

- **Fetch before classifying.** A branch that exists only on the remote reads as absent otherwise,
  and the run creates a different branch wearing the same name. Its push is rejected as
  non-fast-forward at the end of an otherwise finished run.

- **A new branch starts at the fetched base, not the local one.** A stale local base puts the
  branch behind before a single edit and defers every base conflict past validation.

  And when the remote carries no such base, the procedure refuses rather than falling back to a
  local ref of that name. The local ref is not evidence about the server — it is a branch that
  happens to share a name, and it can be arbitrarily old. Substituting it is the same defect
  wearing the word "fallback", and it reports `status=ready` while doing it.

- **Synchronising means two refs, not one.** The branch's own remote head carries commits this
  checkout does not have — a previous run, another machine, a collaborator. The base carries what
  the branch has to integrate with. Merging only the base *feels* like having synchronised and
  still leaves the push non-fast-forward; that half is the one that was actually left undone here,
  twice.

- **Merge, never rebase.** The branch may already be pushed, and rebasing would demand a
  force-push.

- **An ordinary merge, not fast-forward-only.** The local branch and its remote can hold different
  commits at once, which the previous sentence names as expected. A fast-forward-only merge aborts
  on exactly that case, and a procedure that aborts on its own expected input has no recovery.

- **The cases are mutually exclusive, and "checked out elsewhere" is decided first.** A branch
  checked out in the caller's ordinary checkout would otherwise match two cases at once, and the
  wrong one fails with git's message instead of opening the gate the run needs.

- **Never `switch` or `checkout` in place to reach a task branch.** The tree is the isolation.

- **Inspect a resumed tree before merging into it.** A merge into uncommitted work either aborts
  on overlapping paths, or succeeds and blends incoming changes into work nobody has reviewed. The
  second outcome is worse because it looks like it worked.

- **The remote is read out of the authority that holds it, not out of a convention.** `origin` is a
  name `git clone` happens to write; it is not a statement that this repository's canonical server
  is origin, and a fork, a mirror, or a second push target all break that inference while leaving
  the name in place. So: an explicit `--remote` if given, the only remote if there is one, otherwise
  the server the base or task branch is configured to track. When the base and the task branch track
  *different* servers — a fork workflow — the script refuses instead of choosing, because one
  `--remote` cannot express two, and a silent choice there is the defect this rule removes.

  This is the same shape as the permissions rule in `AGENTS.md`: read the fact from whatever holds
  it, rather than from the change or the convention that suggests it.

## Afterwards

Leave the tree in place after the pull request unless asked to remove it: the review loop fixes
findings on it, and a removed tree has to be rebuilt before the first fix.

Stage only paths belonging to the approved scope — never `git add -A`, `git add .`, or any other
bulk stage. A sibling tree can hold someone else's work, and a bulk stage is how it silently ends
up in this pull request.

## Changing the procedure

Change `scripts/worktree-setup.sh`, add the case to `scripts/worktree-setup.test.sh`, and run the
test. A change proved by reading the diff is the thing this file exists to stop.
