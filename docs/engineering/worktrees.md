# Worktrees

The git procedure every task run follows to get itself an isolated place to work. Both editions of
the pipeline read this file; how a session *moves into* the resulting tree is harness-specific and
stays in each edition.

`checkpoints.md` states the isolation contract this implements: every run that changes files works
in its own worktree on its own non-default branch, and the default branch is never edited,
committed to, or pushed directly. `AGENTS.md` names the root the trees live under and the branch
pattern.

This file exists as its own document because the procedure produced a defect in four consecutive
review rounds while it lived as prose inside the skills. Each round fixed the case that was named
and left the enumeration incomplete, and the two editions drifted in opposite directions in the
same paragraph — one too permissive about reusing a checkout, the other too strict to resume its
own interrupted run. An enumeration that both editions read is one enumeration.

## 1. Fetch before classifying anything

```sh
git fetch origin
```

Without it, a branch that exists only on the remote reads as absent, and the run creates a
same-named local branch off the base. That is a **different branch wearing the same name**: its
push is rejected as non-fast-forward, and the rejection arrives at the end of an otherwise
finished run, after implementation and validation have already been paid for.

## 2. Decide which case the run is in

The commands differ, and two of them fail outright in the wrong case.

| Case | What to do |
| --- | --- |
| No branch, locally or on the remote | `git worktree add <root>/<branch> -b <branch> <base-branch>` |
| On the remote only | `git worktree add <root>/<branch> -b <branch> origin/<branch>` |
| Local, with no tree under the configured root | `git worktree add <root>/<branch> <branch>`, then synchronise |
| Local, with a tree already under the configured root | The resume path — inspect before touching anything, per §4 |
| Checked out anywhere else, the caller's ordinary checkout included | Gate, per §5 |

`-b` means *create a new branch*. It fails on one that already exists, which is a live case
whenever the pipeline is handed an existing branch name.

Never `git switch` or `git checkout` in place to reach a task branch. The tree is the isolation.

## 3. Synchronise before the first edit

Wherever the branch already existed, **two refs matter, and they fail differently**:

```sh
git -C <root>/<branch> merge --ff-only origin/<branch>      # when the remote branch exists
git -C <root>/<branch> merge origin/<base-branch>
```

- The branch's **own remote head** carries commits this checkout does not have — from a previous
  run, another machine, or a collaborator. Omitting it leaves the push non-fast-forward however
  carefully the base was merged. This is the half that is easiest to leave undone, because
  merging the base *feels* like having synchronised.
- The **base** carries what the branch has to integrate with. Omitting it moves every conflict to
  after implementation and validation, where the same conflict costs the whole verification pass
  instead of a minute.

**Merge, never rebase.** The branch may already be pushed, and rebasing would demand a force-push.

A branch created fresh off the base, or off its own remote head, needs neither merge.

## 4. On the resume path, inspect before synchronising

An interrupted run leaves state behind, and that state decides what is safe.

- **Clean tree** — synchronise per §3 and continue.
- **Uncommitted changes present** — do not merge into them. The merge either aborts on overlapping
  paths, or succeeds and blends incoming changes into work nobody has reviewed. The second outcome
  is the worse one precisely because it looks like it worked.

  Read the artifacts first, establish which phase the run reached, then either commit that work as
  its own unit and synchronise, or gate on how to reconcile it. Which of the two depends on
  whether the uncommitted work is recognisably part of the approved plan.

Read `plan.md` rather than overwriting it, and re-enter at the first phase whose exit condition is
unmet. An interrupted run's plan is the only record of what its gates decided.

## 5. The gate

When the branch is checked out anywhere outside the configured root — including the caller's
ordinary checkout — stop and offer exactly two ways out:

- a different branch, or
- the human freeing that checkout.

**Do not offer to run in the caller's ordinary checkout.** It sits outside the configured root, so
working there breaks the isolation contract, and it can hold unrelated work that would be swept
into this run's commits. A confirmation that the tree "is clean" describes one moment rather than
a property of the tree.

Git will not check one branch out twice in any case; the gate exists so that the run says why
rather than failing with a git error the human has to interpret.

## 6. Afterwards

Leave the tree in place after the pull request unless asked to remove it. The review loop in phase
11 fixes findings on it, and a removed tree has to be rebuilt from §2 before the first fix.

Stage only paths belonging to the approved scope — never `git add -A`, `git add .`, or any other
bulk stage. A sibling tree can hold someone else's work, and a bulk stage is how it silently ends
up in this pull request.
