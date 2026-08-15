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
| 13 | The target path holds something that is not a registered worktree | **Gate.** Nothing was removed. Whether that directory is leftover garbage or unrelated work is exactly the question a human should answer |
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

- **One server per run, named rather than inferred.** `--remote` — or the sole remote where there
  is only one — is the single server this run reads and writes: it is fetched, the branch is
  created from it, both merges come from it, and phase 10 pushes to it. **A branch living on any
  other remote is outside this run by definition**, not by oversight. Where a repository has
  several remotes and none was named, the procedure refuses.

  That narrowness is deliberate, and it replaced an inference that cost four review rounds. Each
  round found a new place where "which server" was being guessed — from the name `origin`, from a
  fallback, from the branch configuration, then from the *absence* of branch configuration — and
  each fix was correct and closed only its own site. The reason it kept recurring is that the
  repository does not contain the answer: a task branch on `origin` with a base on `upstream` is a
  coherent fork workflow, and no rule reading the repository can tell whether this task belongs to
  one server or the other. An inference with no ground truth has no natural stopping point, so the
  procedure stops inferring and asks.

  The cost is real and worth stating: a project with several remotes must record the name in
  `AGENTS.md`, and if it records the wrong one the procedure will obey it. That is a mistake a
  human can see in one line of configuration, which is the trade — a visible wrong answer instead
  of a silent one.

## Afterwards

Leave the tree in place after the pull request unless asked to remove it: the review loop fixes
findings on it, and a removed tree has to be rebuilt before the first fix.

Stage only paths belonging to the approved scope — never `git add -A`, `git add .`, or any other
bulk stage. A sibling tree can hold someone else's work, and a bulk stage is how it silently ends
up in this pull request.

## Changing the procedure

Change `scripts/worktree-setup.sh`, add the case to `scripts/worktree-setup.test.sh`, and run the
test. A change proved by reading the diff is the thing this file exists to stop.
