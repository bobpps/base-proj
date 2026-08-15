---
name: task-pipeline
description: >
  Runs a task from a tracker issue or a plain description through to a reviewed, open pull
  request: reads context, extracts and debates requirements with independent subagents, stops at
  human gates where risk demands it, plans against the failure axes, implements in an isolated
  worktree, proves the result, reviews the diff through six lenses, adjudicates every finding by
  id, opens the pull request, and drives the review loop to a verdict. Use whenever asked to
  implement or work on an issue, take a task through to a pull request, pick up the next backlog
  item, analyze a task before implementing it, or continue an interrupted run. Do not use for a
  standalone review of an existing pull request, or for a question that changes no files.
---

# Task pipeline — Codex edition

The Claude Code edition lives in `.claude/skills/task-pipeline/` and answers to the same contract.
The two differ in how the workflow is driven, never in what it demands. Neither depends on the
other: both read the shared doctrine, and a rule that needs changing is changed there.

**The contract is `docs/engineering/checkpoints.md`, read from the repository root.** This file
does not restate it.

## Read before the first checkpoint

- `docs/engineering/checkpoints.md` — modes, phases, findings, adjudication, artifacts.
- `docs/engineering/checkpoint-formats.md` — the shape of every checkpoint and artifact file.
- `docs/engineering/failure-axes.md` — before writing the plan, and again before briefing reviewers.
- `docs/engineering/evidence.md` — before the validation checkpoint.
- `docs/engineering/asking-questions.md` — before any gate.
- `docs/engineering/subagent-briefs.md` — before phase 2 and again before phase 7.
- `docs/engineering/worktrees.md` — in phase 5, before the first git command.
- `docs/engineering/review-loop.md` — in phase 11.
- `README.md`, `AGENTS.md`, and every applicable `CLAUDE.md`.
- Every file in `docs/decisions/`.

Read `AGENTS.md` in full at the start of the run. **Every project-specific fact this pipeline
needs is in it** — where tasks live, the base branch, the branch pattern, the commit convention,
the worktree root, the automated reviewer and how to request a pass, the proving commands, which
of them only CI can run, what counts as Risky here, the architecture boundaries and invariants,
and what is out of scope. This skill hardcodes none of them.

A fact still reading `{{PLACEHOLDER}}` means the repository was never initialized. Stop and say so
rather than guessing: a run against unfilled placeholders produces confident nonsense slowly.

## What this edition has to supply by hand

The other edition gets three things from its harness that this one does not. Each is replaced by a
rule, and the rule is the weaker mechanism — so state it, and hold to it deliberately.

| Provided there by | Replaced here by |
| --- | --- |
| Plan mode, which makes phases 1–4 read-only by construction | A rule: **create nothing, edit nothing, and run no command that writes, until the plan is approved** — by the human where the mode requires it, by the run itself otherwise. Investigation is read-only. There is no mechanism enforcing this; it holds because it is followed. |
| A native question mechanism at gates | The printed `Human decision required` block from `checkpoint-formats.md`. End the turn after printing it and wait. Do not answer it yourself, and do not continue on an assumption about what the answer would be. |
| A task list showing which gate the run is stopped at | Say it in prose at the top of every message: which phase, and what is being waited on. A long run that goes quiet is indistinguishable from one that died. |

## Phases

Run the phases of the classified mode from `checkpoints.md`, publishing each checkpoint in the
shape `checkpoint-formats.md` fixes.

**Phases 1–4 — read-only.** Read context, extract requirements, print the gate if one is
triggered, then publish the implementation plan.

For **Normal and Risky**, run the four-role debate as concurrent subagents briefed from
`subagent-briefs.md`. **A Small run skips it** while it stays clearly isolated and low-risk —
four agents on a typo cost more than they find, which is what `checkpoints.md` defines the mode
for. Do the same analysis here, say in the checkpoint that the debate was skipped and why, and
escalate out of Small the moment ambiguity, coupling, or risk appears.

Who approves that plan depends on the run, per phase 4 of `checkpoints.md`:

- **Risky, or a run the human asked to be interactive** — print the approval block and wait. For
  Risky this holds even when nothing looks ambiguous: the human is approving the risk, not
  resolving a question.
- **Normal and Small** — the run approves its own plan and proceeds. Waiting for an approval the
  contract does not ask for is what turns an autonomous pipeline into a supervised one.
- **Analysis-only** — publish the plan and stop.

**Phase 5 — the worktree.** After approval and before the first edit, derive the branch name from
the pattern in `AGENTS.md` and run the procedure. **Do not run the git commands by hand** — the
script is the procedure, and `docs/engineering/worktrees.md` explains why that is not a matter of
convenience:

```sh
scripts/worktree-setup.sh --branch <branch> --base <base> --root <worktree-root>
```

Add `--remote <name>` when the **Remote** row in `AGENTS.md` names one instead of saying `derived`.

Exit 0 prints `worktree=`, `case=`, and `remote=`; carry all three into `implementation.md`. The
remote matters past this phase: phase 10 pushes to it by name, and re-deriving it there would let
git answer the question by its own defaults instead. Exit 10, 11, or 12 is a gate: read
`worktrees.md` for what each means, print the `Human decision required` block, and do not reach for
the underlying git commands to get past it.

There is no session-level move into the tree in this edition, so run every subsequent command with
the printed worktree path explicitly. A forgotten path writes into the main workspace, which is
the failure the whole isolation contract exists to prevent.

Then write `plan.md` inside the tree, before the first edit, carrying what phases 2–4 concluded —
including the gate answers and what they ruled out. **Decide that by looking for the file, not by
reading `case=`.** A run interrupted between the script creating the tree and the plan being
written comes back as `case=resumed` with a clean tree and no plan, and a rule keyed on the case
skips the record entirely. Where a plan is already there it belongs to this branch: reconcile it
against what phases 2–4 just concluded rather than overwriting it.

**Phase 6 — prove it.** Run the proving commands from `AGENTS.md` in proportion to risk, and
report each with its outcome and where it ran. `evidence.md` governs what each result means.

**Phase 7 — review.** Run `scripts/review-snapshot.sh` before launching the passes, launch them
concurrently, run it again afterwards, and compare the `snapshot=` line. A moved snapshot means an
agent exceeded its role, and that needs to be known before those changes reach the diff. Do not
assemble the comparison by hand — `subagent-briefs.md` records the two ways doing so has already
been wrong.

**A Small run skips this fan-out**, for the reason it skips the debate. Self-review the diff
against the five axes in `failure-axes.md` and record that as the review, findings and all, in the
same shape. What a Small run never skips is the review loop in phase 11.

**Phases 8–9 — adjudicate, then apply only what was accepted.** The termination rule in
`checkpoints.md` is mechanical. Apply it rather than judging each round on how it felt.

**Phase 10 — publish.** Stage only the paths in the approved scope; never a bulk stage. Commit with
the convention from `AGENTS.md`, then push **by naming the remote phase 5 recorded** —
`git push -u <remote> <branch>`. A bare `git push` resolves through the branch's own upstream and
`remote.pushDefault`, either of which can name a different server than this run fetched and merged
against. Verify the head on that remote matches the local head, reading it back rather than taking
the push command's word for it, and open the pull request with every deferred and documented
finding in the body by id.

**Phase 11 — the review loop.** Follow `review-loop.md` against the reviewer `AGENTS.md` names.
Where it names none, say so and go to phase 12; an absent reviewer is not a clean round.

**Phase 12 — report** in the `Done` shape, then run the retrospective. It is non-blocking: if it
fails, say so in one line and finish anyway.

## What must never happen

- Editing, committing, or pushing the default branch.
- Writing anything before the plan is approved.
- A bulk stage.
- A pull request with an unresolved blocking finding.
- Applying a finding that was rejected, deferred, or is waiting on a human.
- Reporting a check that did not run, or a review round that could not be read, as a pass.
- Answering a printed gate on the human's behalf.
- Silently deciding a boundary, data-model, security, or scope question.

## Resuming

Read whichever artifacts exist, reconcile them against the commit history, and re-enter at the
first phase whose exit condition is unmet. An open pull request means phase 11 has not converged —
it does not mean the task is finished.

A `plan.md` in the tree **is** the approval the write rule above refers to. A resume into phase 5
or later is not held by that rule, and re-approving a plan that was already approved is not
caution — it is a second gate the contract never asked for.
