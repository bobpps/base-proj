# AGENTS.md

Shared instructions for every coding agent working in this repository. Tool-agnostic: Claude
Code, Codex, and anything else read this file. Harness-specific notes live in `CLAUDE.md` and
in the corresponding skill editions.

> **This file is still the template.** Every `{{PLACEHOLDER}}` below is filled in by the
> `init-project` skill. Run `/init-project` before doing any engineering work here — a run
> against unfilled placeholders will produce confident nonsense.

## Communication

Reply to the user in {{USER_LANGUAGE}}, in plain language, whatever language the question was
asked in. Switch only when asked.

Plain language means explaining the thing rather than naming it. Keep the technical terms that
have no honest equivalent and explain what they do the first time they matter. Do not reach
plainness by dropping a constraint, a trade-off, or a risk: shorter is not the goal,
understandable is.

Everything that lands in the repository or on the hosting platform stays in English: code,
identifiers, comments, commit messages, branch names, pull-request titles and bodies, issue
text, and repository documentation. {{DOC_LANGUAGE_EXCEPTIONS}}

Subagent briefs are English. They are engineering instructions rather than user-facing text,
and the reviewer agents they compose with are written in English.

This rule governs how an agent talks to the user. It is separate from whatever language the
**product** speaks to its own users, and the two must never be merged.

## Project

{{PROJECT_NAME}} — {{PROJECT_ONE_LINE}}

Read `README.md` first for the current product model, scope, architecture, and roadmap. Read the
active task before implementing anything.

{{PROJECT_CONTEXT}}

## Architecture boundaries

Every change has one clear owner among these layers. A change that cannot be placed is a design
question, not an implementation detail — raise it at a gate.

{{ARCHITECTURE_BOUNDARIES}}

### Invariants that hold regardless of layer

{{ARCHITECTURE_INVARIANTS}}

## Out of scope

Do not expand into the following unless the active task explicitly asks for it. An unrequested
feature is not a bonus; it is scope nobody reviewed.

{{OUT_OF_SCOPE}}

## Engineering doctrine

These files are **not negotiable and not project-specific**. They are read from the repository
root by every skill edition and by every agent doing engineering work here.

| File | Read it before |
| --- | --- |
| `docs/engineering/evidence.md` | claiming anything works, and before writing `validation.md` |
| `docs/engineering/failure-axes.md` | writing a plan, and again before briefing reviewers |
| `docs/engineering/checkpoints.md` | starting any task run |
| `docs/engineering/checkpoint-formats.md` | writing any checkpoint or artifact file |
| `docs/engineering/review-loop.md` | driving the post-pull-request review rounds |
| `docs/engineering/asking-questions.md` | putting any question to a human |
| `docs/engineering/subagent-briefs.md` | dispatching the requirements debate or the review fan-out |
| `docs/engineering/worktrees.md` | setting up or resuming a task run's isolated worktree |
| `docs/engineering/writing-skills.md` | creating or editing a skill |

Nothing in this file weakens anything in those. Where this file and the doctrine appear to
conflict, the doctrine wins and the conflict is a bug in this file.

## Proving commands

One command per role, per `docs/engineering/evidence.md`. A role with no command is a role this
project cannot prove — say so in those words rather than substituting a neighbour.

| Role | Command |
| --- | --- |
| Type correctness | `{{CMD_TYPECHECK}}` |
| Lint | `{{CMD_LINT}}` |
| Format check | `{{CMD_FORMAT_CHECK}}` |
| Unit tests | `{{CMD_TEST}}` |
| Single test or file | `{{CMD_TEST_ONE}}` |
| Build | `{{CMD_BUILD}}` |
| Artifact smoke | `{{CMD_SMOKE}}` |
| Integration / data layer | `{{CMD_INTEGRATION}}` |

Supporting commands: {{CMD_SUPPORTING}}

### Where each is proved

{{VALIDATION_LINE}}

The reasoning behind that line is recorded in `docs/decisions/`. It is a decision with
consequences, not a convenience.

## Risk classification

Treat work touching any of these as **Risky** under `docs/engineering/checkpoints.md`:
authentication, authorization, secrets, database schema and migrations, access policies, storage
policies, payments, user data, deployment, CI/CD, public API contracts, architecture boundaries.

This project adds: {{RISK_ADDITIONS}}

Do not silently decide a material boundary, data-model, security, or scope question. Surface it
at the required human gate.

## Tasks, branches, and pull requests

| | |
| --- | --- |
| Task source | {{TRACKER}} |
| Base branch | `{{BASE_BRANCH}}` |
| Remote | {{REMOTE}} |
| Branch pattern | `{{BRANCH_PATTERN}}` |
| Commit subject | {{COMMIT_CONVENTION}} |
| Worktree root | `{{WORKTREE_ROOT}}` (git-ignored) |
| Pull request | {{PR_COMMAND}} |
| Automated reviewer | {{REVIEWER}} |
| Requesting a fresh review pass | {{REVIEW_REQUEST}} |

Commit messages are imperative and explain **why**, not just what. The first line stays short;
detail goes in the body as a list.

**Remote** is `derived` where the repository has exactly one remote, and **the name of a server**
where it has several. `scripts/worktree-setup.sh` works with one server per run and will not
choose between candidates: it fetches that server, creates the branch from it, merges from it, and
phase 10 pushes to it. Branches on other remotes are outside the run. Where several remotes exist
and this row does not name one, the procedure refuses rather than picking — see
`docs/engineering/worktrees.md` for why inference was removed rather than improved.

## Security and secrets

These hold in every project. Whether this project also separates privileged from unprivileged
processes is an architecture question, and its answer — if there is one — is under **Invariants**
above rather than here.

- Never hardcode a credential, token, or key in source.
- Restricting an object starts with revoking, never with granting. Granting is additive and cannot
  express "and nothing else", so a change that adds only the permission it wants leaves in place
  every permission it never asked for.
- Read the effective permissions out of the authority that holds them, not out of the change that
  requested them. Resolve group and role membership too: a permission reaching a principal through
  a group it belongs to does not appear against its own name.
- {{SECURITY_ADDITIONS}}

## Documentation

Update documentation when an architectural decision, a public contract, the data model, a security
boundary, or a scope assumption changes — rather than leaving the decision in code and chat
history.

- `README.md` is the human-facing description of the product.
- `AGENTS.md` carries agent constraints and architecture invariants, and nothing else.
- `docs/decisions/` records decisions with their context and consequences. A recorded decision
  answers a gate question before it is asked, and it is what a reviewer finding gets rejected
  against.
- `docs/engineering/` is the doctrine. It changes through the retrospective loop, not casually.
- `docs/specs/` holds dated specifications, and they are **historical like a decision record**: a
  spec says what was specified on its date, so a spec the implementation has since moved past is
  correct rather than stale. Supersede it with a newer one; never edit it to match today's code.

## Skills

The task pipeline lives in `.claude/skills/task-pipeline/` (Claude Code edition) and
`.codex/skills/task-pipeline/` (Codex edition). Both express the same contract from
`docs/engineering/checkpoints.md`; they differ only in how the workflow is driven.

The supporting skills — `init-project`, `retrospective`, `lessons`, `qa-architect`, `docs-audit`,
`code-critic` — ship as a Claude Code edition only. `CLAUDE.md` lists what each is for and who may
invoke it. None of them edits code: they configure the repository, write records, write test plans,
repair documentation, or return an opinion.

`.agents/skills/` is generated by `scripts/copy-skills-to-agents.mjs` and committed, so Codex
discovers skills without running anything first — including the ones that have no Codex-native
edition, which the generator copies from `.claude/`. Do not edit it by hand;
`scripts/skills.test.sh` compares it against its sources.
