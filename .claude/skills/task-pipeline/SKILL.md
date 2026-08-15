---
name: task-pipeline
description: >
  Runs a task from a tracker issue or a plain description through to a reviewed, open pull
  request: reads context, extracts and debates requirements with independent subagents, gates on
  the human where risk demands it, plans against the failure axes, implements in an isolated
  worktree, proves the result, reviews the diff through six lenses, adjudicates every finding by
  id, opens the pull request, and drives the review loop to a verdict. Use whenever asked to
  implement or work on an issue, take a task through to a pull request, pick up the next backlog
  item, analyze a task before implementing it, or continue an interrupted run — including casual
  phrasings like "let's do issue #7", "сделай задачу ABC-123", "возьми следующую", or a pasted
  issue URL. Do not use for a standalone review of an existing pull request or commit, and do not
  use for a question that changes no files.
argument-hint: "<task-id-or-url> [--interactive] [additional context]"
user_invocable: true
---

# Task pipeline

The Claude Code edition. `.codex/skills/task-pipeline/` is the Codex edition of the same
contract; the two differ only in how the workflow is driven, never in what it demands.

**The contract is `docs/engineering/checkpoints.md`, read from the repository root.** This file
does not restate it. What follows is how this edition drives that contract with Claude Code's own
mechanisms — plan mode, `AskUserQuestion`, the task list, worktree tools, and subagents — instead
of simulating them in prose.

## Read before the first checkpoint

Read these yourself. They are the rules the work will be judged against, and a summary of a rule
is not the rule.

- `docs/engineering/checkpoints.md` — modes, phases, findings, adjudication, artifacts.
- `docs/engineering/checkpoint-formats.md` — the shape of every checkpoint and artifact file.
- `docs/engineering/failure-axes.md` — before writing the plan, and again before briefing the
  reviewers.
- `docs/engineering/evidence.md` — before the validation checkpoint.
- `docs/engineering/asking-questions.md` — before any gate.
- `docs/engineering/review-loop.md` — in phase 11.
- `docs/engineering/subagent-briefs.md` — before phase 2 and again before phase 7. Both editions
  read this one, so a brief cannot drift between them.
- `docs/engineering/worktrees.md` — in phase 5, before the first git command.
- `AGENTS.md` and every applicable `CLAUDE.md` — the project's own facts.

## Every project fact comes from `AGENTS.md`

This skill hardcodes nothing about the project. Where it needs a fact, it reads one:

| Needed | Where it is written |
| --- | --- |
| Where tasks live, and how to read one | `AGENTS.md` → Tasks, branches, and pull requests |
| Base branch, branch pattern, commit convention, worktree root | same table |
| The automated reviewer and how to request a pass | same table |
| The proving commands, and which of them only CI can run | `AGENTS.md` → Proving commands |
| What counts as Risky here beyond the base list | `AGENTS.md` → Risk classification |
| Architecture boundaries, invariants, and what is out of scope | `AGENTS.md` |
| The language to talk to the human in | `AGENTS.md` → Communication |

A fact that is still a `{{PLACEHOLDER}}` means the repository was never initialized. Stop and say
so: run `/init-project` first. A pipeline run against unfilled placeholders produces confident
nonsense, and it produces it slowly.

## Resolve the task

Accept an issue URL, an identifier, a plain description, an existing branch name, or nothing at
all plus context in the conversation.

Derive the rest from the workspace rather than asking — the remote, the current branch, the
default branch, and the issue body through whatever CLI `AGENTS.md` names. Ask only when the
target genuinely cannot be identified.

Where an issue exists, its body, comments, labels, and acceptance criteria are task evidence.
Where only a plain description exists, that is the source of truth: do not invent an issue link
or a closing reference for an issue that does not exist.

## Track the run as a task list

Create one task per phase of the classified mode with `TaskCreate`, and move each through
`in_progress` and `completed`. The run is long and deliberately interrupted by gates; the task
list is how the human sees which gate it is stopped at without rereading the transcript.

**Add a task when a gate opens**, so a pending human decision appears as work rather than as
silence.

## Phases 1–4: inside plan mode

Enter plan mode with `EnterPlanMode` before reading — **on every fresh run, in every mode.** An
Analysis-only run enters and never leaves.

Two things follow, and both are the point: the read-only phases become read-only **by
construction** rather than by intention, and phase 4 gets a native transition out of them.

The uniformity across modes is deliberate. Entering only for the larger modes leaves a Small run
reaching phase 4 with no plan-mode session to exit, and a mode-dependent branch is precisely the
thing that turns out to be wrong in the case nobody exercised. One extra tool call on a typo fix is
cheaper than that branch.

**A resume that re-enters at phase 5 or later does not enter plan mode at all.** This is not the
branch the paragraph above argues against: it does not turn on the mode, it turns on whether the
run will ever reach the phase 4 that calls `ExitPlanMode`. A resume into phase 11 never does, and
`ExitPlanMode` is the only way out — so entering would leave the session read-only for the whole
of a phase whose entire job is to push fixes, update artifacts, and drive the loop to a verdict.
Establish the first unmet phase first, per **Resuming** below, and enter only if it is 1–4.

- **Phase 1** — read context. Delegate the wide search to an `Explore` subagent when the relevant
  code could be anywhere; it reads excerpts and returns locations, which is the shape of that
  question. Do not delegate the instruction and decision files.
- **Phase 2** — publish the requirements analysis. For **Normal and Risky**, launch the four
  debate roles **in a single message** so they run concurrently and independently, briefed from
  `docs/engineering/subagent-briefs.md`.

  **A Small run skips the debate** while it stays clearly isolated and low-risk: four agents on a
  typo cost more than they find, which is what `checkpoints.md` defines the mode for. Do the same
  analysis in this session, say in the checkpoint that the debate was skipped and why, and
  escalate out of Small the moment ambiguity, coupling, or risk appears.
- **Phase 3** — the gate. Use `AskUserQuestion`, carrying what
  `docs/engineering/asking-questions.md` requires: the fork map, position and settled-so-far in
  each heading, two to four options that describe consequences and name what they do not fix,
  recommendation first.

  **Do not use `AskUserQuestion` to ask whether the plan is acceptable.** That is what
  `ExitPlanMode` does in phase 4, and asking twice trains the human to stop reading.

  Whatever comes back goes into `plan.md` when phase 5 writes it, together with what the answer
  rules out. This edition needs that reminder more than the Codex one: `AskUserQuestion` leaves
  nothing on the page, so an unrecorded decision survives only as long as the conversation.

- **Phase 4** — call `ExitPlanMode` with the plan. It is the only way out of plan mode, and in
  this harness it always surfaces the plan for approval. **Whether that approval needs a human
  depends on the session's permission mode, not on anything this skill says** — an interactive
  session prompts, an auto-accepting or headless one passes through.

  Do not claim otherwise. An earlier version of this file called the transition "not an open
  question" for autonomous runs, which relabelled the mechanism instead of changing it, and a
  relabelled mechanism behaves exactly as it did before.

  What this skill does control is the plan's content and what the run does once the call returns:

  - **Risky, or `--interactive`** — present the plan as a decision, with the alternatives that
    were considered, and treat the approval as a real gate: stop until it is answered. For Risky
    this holds even when nothing looks ambiguous, because the human is approving the risk rather
    than resolving a question.
  - **Normal and Small** — present the plan as a statement of what is about to happen, and
    proceed as soon as the call returns. Do not solicit a choice the contract does not ask for:
    per phase 4 of `checkpoints.md` the run approves its own plan in these modes.
  - **Analysis-only** — publish the plan and stop **without** exiting plan mode.

  The Codex edition has no equivalent interruption, having no plan mode to leave. That is a real
  difference between the editions and belongs in the open rather than smoothed over.

Nothing is written to `tasks/<task>/` in these phases. The worktree does not exist yet, and plan
mode is read-only.

## Phase 5: enter the worktree, then implement

After approval and before the first edit, derive the branch name from the pattern in `AGENTS.md`
and run the procedure. **Do not run the git commands by hand** — the script is the procedure, and
`docs/engineering/worktrees.md` explains why that is not a matter of convenience:

```sh
scripts/worktree-setup.sh --branch <branch> --base <base> --root <worktree-root>
```

Add `--remote <name>` when the **Remote** row in `AGENTS.md` names one instead of saying `derived`.

Exit 0 prints `worktree=`, `case=`, and `remote=`; carry all three into `implementation.md`. The
remote matters past this phase: phase 10 pushes to it by name, and re-deriving it there would let
git answer the question by its own defaults instead. Exit 10, 11, 12, or 13 is
a **gate**: read `worktrees.md` for what each one means, ask through `AskUserQuestion`, and do not
reach for the underlying git commands to get past it.

Then move the session into the tree with `EnterWorktree`, passing `path:` — the path the script
printed — so every later command runs there without it being threaded through by hand. **Never
let `EnterWorktree` create the tree by `name`:** that form puts it somewhere the repository does
not ignore and the Codex edition does not know about, which breaks the property that lets the two
editions see each other's trees.

Then write `plan.md` inside the tree, before the first edit, carrying what phases 2–4 concluded —
including the gate answers and what each one ruled out. **Decide that by looking for the file, not
by reading `case=`.** A run interrupted between the script creating the tree and the plan being
written comes back as `case=resumed` with a clean tree and no plan, and a rule keyed on the case
skips the record entirely — the requirements, the gate answers, and the plan the rest of the run
is judged against. Where a plan is already there it belongs to this branch: reconcile it against
what phases 2–4 just concluded rather than overwriting it.

Then implement the approved scope, recording each applied safe default with its path as
`failure-axes.md` requires. Pause at a gate if implementation reveals a boundary change the plan
did not cover.

Leave the worktree in place after the pull request unless asked to remove it. `ExitWorktree` will
not remove a tree entered by path — use `action: "keep"` to return to the original directory.

## Phase 6: prove it

Run the proving commands named in `AGENTS.md`, in proportion to risk, and follow
`docs/engineering/evidence.md` on what each result means.

**Run them yourself, in this session.** Not because delegation is impossible, but because this
session owns the gate that opens `git push`, and a delegated agent returns a claim where a gate
needs evidence. If verification is delegated anyway, require the raw tail of the output back and
treat that as the evidence.

After pushing in phase 10, watch CI to a verdict rather than predicting it.

## Phase 7: the review fan-out

Run `scripts/review-snapshot.sh` **before** launching, run it again afterwards, and compare the
`snapshot=` line. Reviewers advise; if it moved, an agent exceeded its role, and that needs to be
known before those changes reach the diff. Do not assemble the comparison by hand —
`subagent-briefs.md` records the two ways doing so has already been wrong.

For **Normal and Risky**, launch the passes in one message.
`docs/engineering/subagent-briefs.md` has which specialist fits which pass and how to brief the
rest.

**A Small run skips this fan-out too**, for the reason it skips the debate. Self-review the diff
instead — against the five axes in `failure-axes.md` — and record that as the review, findings and
all, in the same shape. What a Small run never skips is the review loop in phase 11: a small change
is reviewed by the same reviewer as a large one, and its findings need the same adjudication.

## Phases 8–9: adjudicate, then fix only what was accepted

Run the adjudication debate yourself. By this point the evidence from both the reviewers and the
implementation is in hand, and the independence that mattered in phase 2 has already been spent.

Open an `AskUserQuestion` gate when reviewers materially disagree, a security issue is disputed,
or a proposed fix would expand scope or alter architecture, data, or access control. Offer the
four real choices — fix now, defer to a follow-up, document the tradeoff, reject as not
applicable — recommendation first.

The termination rule in `checkpoints.md` is mechanical, not a judgement call. Apply it.

## Phase 10: publish

Stage only the paths belonging to the approved scope — never a bulk stage. Commit with the
convention from `AGENTS.md`.

**Push by naming the remote phase 5 recorded** — `git push -u <remote> <branch>`, taking `<remote>`
from the script's `remote=` line. A bare `git push` resolves through the branch's own upstream and
`remote.pushDefault`, either of which can name a different server than the one this run fetched and
merged against; on a repository with several remotes that delivers the work somewhere nothing in
this run ever looked. The answer was derived once, under a rule that refuses to guess — carry it
rather than letting git re-answer the question by its own defaults.

Then verify that no in-scope change is left uncommitted, and that the head on **that** remote
matches the local head — read it back with `git rev-parse <remote>/<branch>` after a fetch, rather
than taking the push command's word for where its work landed.

Then open the pull request, with every deferred and documented finding in the body by id, in
words.

## Phase 11: the review loop

Follow `docs/engineering/review-loop.md` against the reviewer `AGENTS.md` names. Where it names
none, say so and go to phase 12 — an absent reviewer is not a clean round.

Wait out a polling interval with a backgrounded `Bash` call running an `until` loop that exits
once the reviewer has spoken about the current head, so the round lands as one notification. A
foreground `sleep` is blocked in this harness, and a tight loop of API calls with no wait between
them looks like waiting while hammering the API.

## Delegation

Nested dispatch works: a subagent can call `Agent` and `Skill`, and can write files. Three points
are worth delegating, because each needs a large working context whose conclusion compresses to
something small — the wide search in phase 1, the debate in phase 2, and the review passes in
phase 7.

How to run each is open. Fan out when subtasks are genuinely independent; follow up on a live agent
when a finding needs clarifying and its context is still warm; keep it in this session when the raw
output needs looking at. Record the choice in `implementation.md` so retrospectives can compare
runs.

**A follow-up asks; it never applies.** `checkpoints.md` puts it in four words — *subagents advise,
only the main session edits files* — and a warm context makes breaking that rule attractive rather
than acceptable: the agent that found the problem is the cheapest one to fix it, and its fix would
land before this session adjudicated the finding at all. That is precisely the change phase 7's
snapshot exists to catch, arriving through the door the snapshot does not watch.

Delegation is not free. Nesting buys isolation and costs visibility: every layer converts detail
into someone's summary.

## Resuming

A resume has two steps, and omitting the second is the defect this section has already produced
twice: the phases being skipped did not only write artifacts, they also **put the session
somewhere**. Re-entering at a later phase inherits none of that.

**1. Establish the first unmet phase**, from whichever artifacts exist, reconciled against the
commit history:

| What is missing | First unmet phase |
| --- | --- |
| `plan.md` | 5 — unfinished, whether or not a worktree exists |
| `implementation.md` | 5 — its exit condition needs the implemented scope *and* the record |
| `validation.md` | 6 |
| nothing, but the pull request is open | 11, **not** done |

`plan.md` marks phase 5 *started*; `implementation.md` marks it *finished*. Reading only the first
resumes at phase 6 with the implementation half-written, and phase 6 then proves something nobody
finished.

**2. Reconstitute the session** for that phase, before doing anything in it:

- **Plan mode** — enter only if the phase is 1–4. A later phase never reaches the `ExitPlanMode`
  in phase 4, so entering would hold the session read-only through the whole of a phase whose job
  is to write.
- **The worktree** — for phase 5 and later, run `scripts/worktree-setup.sh` and `EnterWorktree`
  the path it prints, exactly as phase 5 does. The script is idempotent: on a resume it returns
  `case=resumed` with the existing tree, and it gates on a dirty one rather than merging into it.
  **Without this the session stays in the caller's checkout**, and every fix, artifact write, and
  commit for the rest of the run lands on whatever branch is checked out there — possibly the
  default branch, which is the one thing this pipeline must never touch.

## What must never happen

- Editing, committing, or pushing the default branch.
- A bulk stage.
- A pull request with an unresolved blocking finding.
- Applying a finding that was rejected, deferred, or is waiting on a human.
- Reporting a check that did not run, or a review round that could not be read, as a pass.
- Silently deciding a boundary, data-model, security, or scope question.

## When the run finishes

Report per phase 12 of `checkpoints.md`, and then invoke the `retrospective` skill. It is
non-blocking: if it fails, say so in one line and finish anyway.
