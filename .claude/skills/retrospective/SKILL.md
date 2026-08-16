---
name: retrospective
description: >
  Writes the retrospective for a finished task run: takes everything that went wrong during the
  run — review findings, gate questions, deviations from the plan, checks that could not be run,
  extra review rounds — and maps each one to the earliest pipeline phase that could plausibly have
  caught it, then proposes a concrete edit to the doctrine file, skill edition, or AGENTS.md
  section that would have caught it. Invoked from phase 12 of the task pipeline, and directly when
  a human says "напиши ретроспективу", "разбери этот прогон", "what should the pipeline have caught
  here", or asks why a run went badly. Non-blocking by construction. Not for applying accumulated
  retrospectives — that is the `lessons` skill.
user_invocable: true
argument-hint: "[task-id] [worktree-path]"
---

# retrospective

A run produces a change and a record of how the change was made. This skill reads the second one
and asks a single question of every issue that surfaced: **which phase should have caught this, and
what would have had to be written down for it to?**

`writing-skills.md` calls this the first half of a loop. The second half is the `lessons` skill,
which applies accumulated retrospectives to the files they indict. Without the first half there is
nothing to apply; without the second, this file is written and nobody reads it.

## Non-blocking, and that is structural

A missing retrospective must never delay a pull request, hold a worktree open, or turn a finished
run into a failed one. Everything here degrades:

- An artifact that is missing is noted and skipped, never reconstructed by guesswork.
- A source that cannot be read is named in the report as unread.
- A failure of this skill is reported to the caller in one line, and the caller finishes anyway.

Never raise into the caller. The pipeline's phase 12 has already reported; this runs after it.

## Inputs

- `<task-id>` — required. Derive it from the branch name when the branch matches the project's
  branch pattern in `AGENTS.md`, and say which id was derived. Otherwise ask.
- `<worktree-path>` — optional; defaults to the repository root of the working directory. Read and
  write everything under it, so the pipeline can commit the result onto the task branch before the
  worktree is removed.

Read, in this order, and stop reading a source that does not exist rather than substituting:

| Source | What it carries that nothing else does |
| --- | --- |
| `tasks/<task-id>/plan.md` | the gate's questions and answers, the per-path axis rules, what the run said it would do |
| `tasks/<task-id>/implementation.md` | what deviated from the plan and why, each applied safe default |
| `tasks/<task-id>/validation.md` | which checks ran, where, and which could not run at all |
| `tasks/<task-id>/review.md` | every finding, its id, its severity, its adjudication, one section per round |
| the branch history | what was actually done, in what order, and how often a fix was re-fixed |
| the pull request and its review rounds | findings that arrived after the run believed it was done |

## The one mapping this skill exists to produce

`checkpoints.md` fixes twelve phases, each with an exit condition. That makes "which phase should
have caught this" mechanical rather than a matter of taste:

> Find the **earliest phase whose exit condition would have been unmet** had the issue been visible
> at the time.

A wrong assumption about what the task asked for means phase 2 exited on an incomplete requirements
analysis. An unstated behaviour on a read path means phase 4 exited on a plan that did not state its
axes. A check reported as passing that never ran means phase 6 exited on a `validation.md` that was
not honest. A boundary decided quietly means phase 3 never opened a gate that was owed.

This is the same rule `checkpoints.md` applies inside a run — return to the earliest phase whose
output the finding invalidated — asked after the fact instead of during. Use it, rather than
inventing a severity-to-phase table; a table cannot cover the issues it never anticipated.

Where an issue genuinely could not have been caught earlier, say so. That is a real and useful
answer: it means the pipeline behaved correctly and the cost was irreducible.

## Every recommendation names its layer

This repository has two layers and a project sits in both. A recommendation that does not say which
one it targets cannot be applied, because the person applying it does not know who inherits it:

| Layer | Lives in | Who a change there reaches |
| --- | --- | --- |
| **Doctrine** | `docs/engineering/` | every project cloned from this template, forever |
| **Skill edition** | `.claude/skills/<name>/`, `.codex/skills/<name>/` | every run of that skill in this project — and the template's future clones, if the skill ships with it |
| **Embodiment** | `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/decisions/` | this project only |

Getting the layer wrong is expensive in one direction specifically. A project fact written into
doctrine — a command name, a directory layout, a framework's behaviour — is inherited by every
future project as a rule about a world it does not live in. When an issue could be answered at
either layer, prefer the narrower one and say what would have to be true for it to belong higher.

A recommendation that cannot be placed in any layer is itself the finding: it means the run hit
something the structure has no home for. Write it as an open question rather than forcing it.

## What counts as an issue

Everything that cost the run something, whether or not anybody called it a problem at the time:

- Every finding in `review.md` that was **accepted** — the reviewer caught what an earlier phase did
  not. Findings that were rejected are evidence about the reviewers, not about the phases; note a
  pattern of them, but do not map each one.
- Every finding **promoted** for recurrence, and every round that carried blocking findings. A
  defect that survived its own fix is the highest-value entry in the whole report, because the fix
  reached a symptom.
- Every deviation in `implementation.md` — the plan was wrong, or the plan was thin.
- Every gate question in `plan.md`. A question that had to be asked is sometimes a requirement that
  could have been derived; a gate carrying six questions says the requirements analysis stopped
  early.
- Every check in `validation.md` recorded as **not run** or **checked by hand** where a command
  exists.
- Every round after the first in the review loop.
- Time visibly lost in the history — a fix reverted, a file rewritten twice, a rebase after a
  bulk stage.

**Never invent issues.** A clean run is a real outcome and it is the outcome the pipeline is for.
Padding it with hypotheticals teaches the next reader that this document is decoration, and the
`lessons` pass then spends real edits on imagined defects.

## Output

One file: `tasks/<task-id>/retrospective.md`. It is written by this skill and this skill only, and
it is the fifth file in a task folder whose other four belong to the run itself.

**Say the path back to the caller, and say the file is uncommitted.** This skill does not commit —
side effects belong to the session that owns the phase, per `checkpoints.md` — and phase 12 stages
and pushes it. That handover is worth stating out loud in the return, because the failure it
prevents is silent: by the time this runs, phase 10 has already published the branch, so a report
nobody commits stays in a worktree that is about to be removed. `lessons` finds reports by path and
orders them by commit date, which makes an uncommitted one invisible rather than merely late.

A human who invoked this directly gets the same sentence and decides what to do with the file.

```markdown
# Retrospective — <task-id>: <title>

**Pipeline:** <skill name and edition that ran>
**Mode:** <analysis-only | small | normal | risky>
**Rounds:** <review rounds before convergence>
**Sources read:** <artifacts that existed> — **not found:** <artifacts that did not>

## Overview

<Three to six sentences: what the task was, how the run went, and the one thing most worth
changing. Written for someone who was not there.>

## Issues by source

| # | Issue | Source | Earliest phase | Layer | Would have been caught by |
| --- | --- | --- | --- | --- | --- |
| 1 | <what went wrong, in one line> | `review.md` H2 | 4 — plan | doctrine | stating the malformed rule per field |

## Root causes

<Group the issues that share a cause. One paragraph each, naming the issues by number. A single
missing rule usually produces several issues that look unrelated in the table.>

## Recommendations

<One numbered entry per proposed edit. Each carries:>

**R1 · `<file>` § `<section>` — <layer>**
What to change, concretely enough that a later pass can apply it without re-deriving the reasoning.
Why: <the issue numbers it answers, and what the edit would have prevented>.

## Clean-run note

<Only when there is nothing to recommend. Say what the run did that worked, so a later pass can
tell a genuinely clean run from an unwritten one.>
```

Two rules about this file's shape, both of which the `lessons` pass depends on:

- **Inline nothing.** Reference `review.md` and the pull request rather than copying their contents.
  A retrospective that quotes its sources at length is unreadable in a batch of twenty, and the
  batch is how it will actually be read.
- **A recommendation names an exact location** — file and section — or it is not a recommendation.
  "Improve the review briefs" cannot be applied by anybody. Where no edit is warranted, write
  `no change proposed — process observation` and say why; the `lessons` pass reads that as a real
  answer and stops looking for a target.

## The `**Applied:**` line is not yours

`lessons` writes a line into this file recording where its recommendations went. Never write, edit,
or predict that line here. It is the only state that pass has, and a mark written by anything else
makes a report look consumed when nothing was applied.

## Frequency is not knowable from one run

Resist ranking recommendations by how important they feel. One run cannot tell a reproducible
property of the pipeline from a single analyst's hypothesis — that judgement needs the archive, and
it belongs to `lessons`. Write what this run saw, and let the count come from elsewhere.

## Boundaries

Does not commit, push, or touch the tracker. Does not edit skills, doctrine, `AGENTS.md`, or any
artifact of the run — a retrospective that edits its own evidence cannot be checked. Does not write
outside `tasks/<task-id>/`. Does not run proving commands: this is a reading pass, and the run
already reported what was proved.
