@AGENTS.md

# Claude Code notes

Shared product, architecture, security, and validation instructions live in `AGENTS.md` and in
`docs/engineering/`. This file carries only what is specific to Claude Code.

> **Still the template.** `{{PLACEHOLDER}}` values are filled in by `/init-project`.

## Working style

- Use a short plan before large or multi-layer changes; prefer small reviewable changes over broad
  rewrites.
- Read the instruction and decision files yourself. Delegate the wide search for related
  implementation to an `Explore` subagent when the relevant code could be anywhere — that agent
  reads excerpts and returns locations, which is the shape of that question. Do not delegate the
  reading of a rule you will be judged against.
- Preserve unrelated work. Inspect repository and branch state before editing.
- {{WORKING_STYLE_ADDITIONS}}

## Which skill for which request

| Request | Skill | |
| --- | --- | --- |
| Set up or re-configure this repository from the template | `init-project` | on disk |
| Implement a task through to a reviewed pull request | `task-pipeline` | on disk |
| A finished run needs its retrospective | `retrospective` | **not yet built** |
| Accumulated retrospectives should improve the skills | `lessons` | **not yet built** |
| A finished feature needs a human test plan | `qa-architect` | **not yet built** |
| Documentation may have drifted from the code | `docs-audit` | **not yet built** |
| A harsh architectural read of recent changes | `code-critic` | **not yet built** |

The third column is not decoration. A skill named in this table but absent from disk is worse than
an absent skill: this table is what the next agent reads to decide what is available, and a missing
one fails at the moment it is needed rather than at the moment it is looked up. The column goes
away as the rows become real.

The pipeline is autonomous by default: it takes the task to an open pull request and drives the
review loop to a verdict. Human gates fire where risk requires them, not on every step. Pass
`--interactive` when the task's **intent** is genuinely ambiguous — not when the implementation is
merely hard.

## Mechanisms this edition uses

- **Plan mode** for the read-only phases, so they are read-only by construction rather than by
  intention, and so the plan gets a native approval gate.
- **`AskUserQuestion`** for every human gate, carrying the content described in
  `docs/engineering/asking-questions.md`: two to four concrete options, each saying what it costs
  and what it locks in, the recommendation first. Never use it to ask whether the plan is
  acceptable — that is what the plan-mode gate does, and asking twice trains the human to stop
  reading.
- **The task list** as the visible state of a long run. Add a task when a gate opens, so a pending
  human decision shows up as work rather than as silence.
- **Worktree tools** for isolation, per `docs/engineering/checkpoints.md`.
- **Subagents** for the requirements debate and the review fan-out. They advise; only this session
  edits files.

## Before finishing

Summarize: what changed; which architecture layer owns it; the exact checks run, their results,
and where each ran; anything that could not be verified anywhere, said plainly rather than left
implied; how to test it by hand; security, privacy, idempotency, or migration considerations; what
remains out of scope; and whether any documentation needs updating.
