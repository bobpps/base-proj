# {{PROJECT_NAME}}

{{PROJECT_ONE_LINE}}

> This README is still the template. `/init-project` fills it in; see `TEMPLATE.md`.

## What this is

{{PROJECT_DESCRIPTION}}

## Scope

{{SCOPE}}

### Out of scope

{{OUT_OF_SCOPE}}

## Architecture

{{ARCHITECTURE_SUMMARY}}

The boundaries that changes must respect are in `AGENTS.md`; the reasoning behind each major
choice is in `docs/decisions/`.

## Getting started

```bash
{{SETUP_COMMANDS}}
```

## Proving it works

| What | Command |
| --- | --- |
| Type correctness | `{{CMD_TYPECHECK}}` |
| Lint | `{{CMD_LINT}}` |
| Format | `{{CMD_FORMAT}}` |
| Tests | `{{CMD_TEST}}` |
| Build | `{{CMD_BUILD}}` |

{{VALIDATION_LINE}}

## Working on this repository with an agent

The engineering rules live in three layers:

- `docs/engineering/` — doctrine. Identical in every project built from this template, and not
  negotiable per task: how work is proved, which failure axes every path answers to, what a task
  run's checkpoints are, how the review loop terminates, how to ask a human, how to write a skill.
- `AGENTS.md` — this project's specifics: architecture boundaries, scope, the proving commands,
  the risk list, branch and tracker conventions.
- `CLAUDE.md` — the part that is specific to Claude Code as a harness.

Start a task with the `task-pipeline` skill. It classifies the run by risk, debates the
requirements with independent reviewers, gates on the human where risk demands it, implements in
an isolated worktree, proves the result, reviews the diff through six lenses, adjudicates every
finding by id, and drives the pull request's review loop to a verdict.
