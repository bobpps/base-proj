# Specification — the `init-project` skill

Status: **ready for `skill-creator`**
Date: 2026-08-15

This is the build specification for the skill that turns a fresh clone of `base-proj` into a
configured project. It is written to be handed to `skill-creator`, which produces the skill
itself; it is not the skill.

## 1. What the skill is for

A clone of `base-proj` carries the full engineering doctrine and an unconfigured shell: rule
files full of `{{PLACEHOLDER}}`, a CI workflow with no commands in it, and no idea what the
project is. `init-project` interviews the human, then writes every project-specific value into
the files that need it.

### The layering it must never violate

Two layers, and the skill only ever touches one of them:

| Layer | Lives in | May the skill write it? |
| --- | --- | --- |
| **Doctrine** — how work is proved, the failure axes, the checkpoint contract, the review-loop contract, how to ask a human, how to write a skill | `docs/engineering/` | **Never.** Not a word, not a placeholder, not an exception. |
| **Embodiment** — names, commands, conventions, boundaries, contours | `AGENTS.md`, `CLAUDE.md`, `README.md`, CI, manifests, settings, first decision record | Yes. This is its whole job. |

This is the load-bearing property of the design. The interview cannot weaken a rule, because no
question it asks is capable of reaching one. `docs/engineering/evidence.md` says a proving command
must be green before any claim of completion; the interview only decides what that command is
called. If a future question would need to edit a doctrine file to take effect, the question is
wrong — or the doctrine is, and that is a decision record, not an interview answer.

## 2. Frontmatter

```yaml
name: init-project
description: >
  Configures a fresh clone of the base-proj template into a working project: interviews the
  user about the product, the technology stack and its proving commands, the task tracker,
  branch conventions, the automated reviewer, and the architecture boundaries, then fills in
  AGENTS.md, CLAUDE.md, README.md, the CI workflow, the package manifest, and the first
  decision record. Use when a repository still contains TEMPLATE.md or files carrying
  {{PLACEHOLDER}} values, when the user says "set up this project", "initialize the template",
  "настрой проект", "заполни AGENTS.md", or asks to re-run or change part of the earlier setup.
  Do not use for ordinary configuration changes in an already-initialized repository — edit
  the file directly instead.
user_invocable: true
disable-model-invocation: true
argument-hint: "[--block <n>] [--dry-run]"
```

`disable-model-invocation` is deliberate. This skill rewrites the repository's rule files; it
runs when a human asks for it and at no other time.

## 3. Invariants

1. **Never writes anything under `docs/engineering/`.** Section 1 says why.
2. **Never invents an answer.** A value nobody supplied stays a placeholder, and the final report
   names every placeholder still standing. A confidently wrong command is worse than a blank,
   because a blank is visible and a wrong command gets trusted.
3. **Shows the full diff before writing**, and writes only after the human accepts it. `--dry-run`
   stops after the diff.
4. **Never overwrites prose a human wrote.** On a re-run, a section whose content no longer matches
   what the skill previously generated is treated as human-owned: offer, do not replace.
5. **Deletes `TEMPLATE.md` as its last act**, and only on a complete first run.
6. **Every answer that carries reasoning becomes a decision record**, not just a filled placeholder.
   The stack choice, the local-versus-CI line, and the architecture boundaries all have reasoning
   worth keeping; a value in `AGENTS.md` cannot hold it.
7. **Follows `docs/engineering/asking-questions.md` exactly.** Fork map before the first question,
   position and settled-so-far in every heading, four-block card sized to the cost of a wrong
   answer, options describing consequences and naming what they do not fix, and an explicit way
   out. This skill is the doctrine's own showcase; a sloppy interview here discredits the rule
   everywhere else.
8. **Derives rather than asks whatever the repository can answer.** The directory name, the current
   branch, the remote, the presence of a manifest, the platform — all readable. Ambiguity the skill
   could remove itself is unfinished research, not a question.

## 4. The interview

Eight blocks. The skill publishes the map of all eight before the first question, then walks them
in order. Blocks 5 through 8 are skippable with a recorded default; blocks 1 through 4 are not.

### Block 1 — Identity

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 1.1 | Project name | confirm a derived value | the directory name, kebab-case |
| 1.2 | One line describing what it is | free text | — (required) |
| 1.3 | Language the agent replies in | choice | Russian |
| 1.4 | Language of human-facing documents — README, QA package | choice: same as 1.3 · English | same as 1.3 |

Repository-facing text (code, identifiers, commits, branches, pull requests, `AGENTS.md`,
`CLAUDE.md`, `docs/engineering/`) is English and is **not** asked about. It is fixed because the
reviewer agents and subagent briefs it meets are English, and a rule translated at that boundary
loses precision.

### Block 2 — Stack and proving commands

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 2.1 | Stack profile | choice: TypeScript/Node · .NET · other | derived if a manifest exists, else asked |
| 2.2 | Layout | choice: single package · workspaces / solution with several projects | single |
| 2.3 | Does the project produce a runnable artifact? | yes/no | yes |
| 2.4 | The eight proving commands | confirm-or-edit, one screen | from the profile |

Question 2.4 shows all eight at once rather than as eight questions. They are one decision — the
project's proof surface — and splitting them into eight prompts is how an interview becomes a form.

**Where the artifact is a library**, the smoke role is recorded as `not applicable — library`
rather than left blank. `evidence.md` distinguishes "cannot be proved" from "nothing to prove", and
so must the file it reads.

#### Profile: TypeScript / Node

| Role | Default command |
| --- | --- |
| Type correctness | `npm run typecheck` → `tsc --noEmit` |
| Lint | `npm run lint` → `eslint .` |
| Format check | `npm run format:check` → `prettier --check .` |
| Unit tests | `npm test` → `vitest run` |
| Single test or file | `npm test -- <path>` |
| Build | `npm run build` |
| Artifact smoke | `npm run smoke` — a script that starts each built artifact |
| Integration / data layer | asked; commonly a database CLI's test command |

Supporting: `npm ci`, `npm run format`. Node version pinned in `.nvmrc`; CI reads it with
`node-version-file`. Manifest written as `package.json` with `"type": "module"` and, for the
workspace layout, a `workspaces` array.

Two traps this profile carries forward from the projects it was derived from, and which the
generated `AGENTS.md` should mention where they apply:

- In a workspace layout, installing dependencies does not build internal packages, so type errors
  in a dependent package are meaningless until the shared package has been built once. Whatever the
  build order is, it belongs in `AGENTS.md`.
- A bundler flag that leaves workspace packages external produces a bundle that builds cleanly and
  fails at process start. This is exactly the gap the smoke role exists to close.

#### Profile: .NET

**These defaults were derived from documentation, not from a live run in this repository.** The
skill states that in the question, shows the values pre-filled, and requires confirmation rather
than accepting silence. Per `evidence.md`, an unverified default presented as verified is the
failure the whole doctrine exists to prevent — and a profile is not exempt from the rule it ships.

| Role | Proposed default |
| --- | --- |
| Type correctness | `dotnet build --no-restore` — compilation is the type check |
| Lint | `dotnet format --verify-no-changes --severity warn` or the analyzer set the project uses |
| Format check | `dotnet format --verify-no-changes` |
| Unit tests | `dotnet test` |
| Single test or file | `dotnet test --filter FullyQualifiedName~<name>` |
| Build | `dotnet build -c Release` |
| Artifact smoke | `dotnet <path-to-dll> --version` or an equivalent that starts the produced binary |
| Integration / data layer | asked; commonly `dotnet test` over a category, with containers |

Supporting: `dotnet restore`. Version pinned in `global.json`; CI sets it up from that file.

Two role mappings need saying out loud in the generated `AGENTS.md`, because they differ from the
Node profile in ways that quietly weaken the doctrine if unstated:

- **Type correctness and build are the same command here.** Say so, rather than listing one command
  twice as though two independent checks ran. Two roles proved by one observation is one
  observation.
- **Migrations** are a framework command rather than a CLI's, and the file layout differs. Ask for
  the project's actual command instead of guessing between the available ones.

#### Profile: other

No defaults. The skill asks for all eight, and marks any the human leaves blank as roles this
project cannot prove — in those words, in `AGENTS.md`.

### Block 3 — Tracker, branches, pull requests

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 3.1 | Where tasks live | choice: GitHub Issues · Linear · files in `docs/tasks/` | GitHub Issues |
| 3.2 | Base branch | confirm a derived value | the repository's current default |
| 3.3 | Branch pattern | confirm-or-edit | `{author}/{task-id}` |
| 3.4 | Commit subject convention | confirm-or-edit | `{task-id}: <imperative subject>` |
| 3.5 | Worktree root | confirm-or-edit | `.worktrees/` |

Choosing Linear adds a note to `AGENTS.md` that the pipeline needs the Linear MCP server, and adds
the tracker-comment etiquette: exactly two comments per run — one at the start, one at the end — and
a third only when the run stops on something a human must resolve. Review conversations belong on
the pull request; answering a reviewer in the tracker puts the answer where the reviewer will never
see it.

Choosing files in `docs/tasks/` removes every tracker call from the generated `AGENTS.md` and says
plainly that acceptance criteria come from the task file.

### Block 4 — The automated reviewer

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 4.1 | Automated reviewer on pull requests | choice: Codex connector · Copilot · none · other | none |
| 4.2 | How a fresh pass is requested | confirm-or-edit | per 4.1 |

Whatever is chosen, `AGENTS.md` records the reviewer's account name, the request mechanism, and
this sentence: *the surfaces this reviewer uses have not been verified against this repository's own
pull requests; verify them on the first real run and correct this section.*

That is not hedging. `review-loop.md` builds a verdict out of which surface said what about which
commit, and every one of those shapes is a property of a specific reviewer on a specific platform at
a specific time. A pipeline that assumes them reports a clean round it never observed.

### Block 5 — Contours

One multiple-choice question. Defaults come from the template's own decisions and are pre-selected:

| Contour | Default | What turning it on costs |
| --- | --- | --- |
| Decision records in `docs/decisions/` | **on** | almost nothing; it is a directory and a habit |
| Codex edition + generated `.agents/` | **on** | every rule expressed twice, in two harness vocabularies |
| QA package for a human tester | **on** | documents that only pay off if somebody reads them |
| Cursor rules | off | a third copy of the same rules, which then drifts |
| Vendor plugin and user skills into `.agents/` | off | one machine's installed set committed to the repository, ageing unnoticed |

The retrospective loop is **not** asked about. It costs one report per run, it is non-blocking by
construction, and without it the rules stop improving — which is the reason the template exists.

Turning a contour off means its files are deleted and its rows removed from the tables in
`CLAUDE.md`. A skill listed in a table but absent from disk is worse than an absent skill.

### Block 6 — The line between this machine and CI

| # | Question | Type |
| --- | --- | --- |
| 6.1 | Which roles can only be proved in CI | multi-select over the eight roles |
| 6.2 | Why — what the developer machine lacks | free text |

Both answers go into `AGENTS.md`, and 6.2 also becomes a decision record. A line drawn without its
reason gets crossed by the first person in a hurry.

Choosing "none" is a valid answer and is recorded as such: it means every role is provable locally,
which is a real property of small projects and should not be dressed up as an omission.

### Block 7 — This project's risk additions

One free-text question, prefilled with the base list from `checkpoints.md` shown read-only. The
human adds; they cannot remove. Removing an item from that list is a change to the doctrine, which
is not something an interview does.

### Block 8 — Architecture boundaries and scope

| # | Question | Type |
| --- | --- | --- |
| 8.1 | The layers a change can belong to, and what each owns | free text, or "not yet" |
| 8.2 | Invariants that hold regardless of layer | free text, prefilled with the defaults below |
| 8.3 | What is explicitly out of scope | free text, or "not yet" |

This block is the one the skill cannot help with, and it says so: the boundaries come from
understanding a product that does not exist yet at the moment the question is asked. "Not yet" is an
honest answer and is recorded as a `{{TODO}}` marker with a pointer to this block, so the next run
can fill it.

The defaults offered under 8.2 are below. They were chosen deliberately rather than harvested:
each one was put to the repository owner as its own fork, with what it costs and what it fails to
cover, and each was accepted or refused on that basis.

Each is stated as a **property**, never as a mechanism. A route that satisfies the property by
other means satisfies it — `failure-axes.md` explains at length why the alternative teaches people
to argue with the rule instead of with the code. Each also carries what it does **not** cover, so
that the gap is a known one rather than an assumed one.

The list is offered pre-selected. The human deselects what does not apply to the project, and
`init-project` writes only what survives into `AGENTS.md`. An invariant nobody intends to enforce
is worse than an absent one: it trains reviewers to skim the section.

1. **Exactly one layer knows how data is stored.** Everything else asks that layer. Reaching the
   store from outside it is a blocking finding, not a style note.
   *Does not cover:* that layer leaking storage-shaped types outward through its own signatures,
   which erodes the boundary while satisfying the rule.

2. **The domain core does not know which channel it is serving.** It does not know how a request
   arrived or how the response will leave. Channel-specific data stays optional and namespaced
   rather than being promoted into the domain model.
   *Does not cover:* the core knowing a specific external provider. That is a separate boundary,
   deliberately left to each project.

3. **Work whose duration another system decides does not run inside a synchronous request.** The
   test is not "is this slow" — which is a judgement and therefore useless in review — but "who
   decides when this finishes".
   *Does not cover:* a normally fast external call that is occasionally slow. That needs a timeout
   budget, which is a design decision rather than an invariant.

4. **Derived data never overwrites its source.** Source and derived are stored separately and stay
   distinguishable; each derived value records what produced it and when; and the input to a later
   step is chosen **by role, never by recency**.
   *Does not cover:* which of two derivations of the same role wins.
   The recency half is the expensive one and the reason this invariant is worded in three parts: a
   pipeline that takes "the newest" input will one day take a cleaned-up derivative as though it
   were the original, and report confidently about something that never happened.

5. **A boundary becomes a public contract the moment code on the other side cannot be updated in
   the same commit.** From then on, a breaking change is a new version. Before then there is
   nothing to version.
   *Does not cover:* the honesty of that judgement, which is where it will actually fail.

6. **Any unit of work can be traced from input to result.** What processed it, how many attempts
   it took, and how its state changed are recorded.
   *Does not cover:* log format, retention, or where the records are read from.

7. **The environment is parsed by a schema at startup, and the process fails immediately and
   entirely.** Not an hour later, on the first request that needed the missing value.
   *Does not cover:* values that are present and become invalid only at the moment of use.

8. **One source of truth for the shape of data across layers.** Described once and reused, not
   re-described at each boundary.
   *Does not cover:* a deliberate projection at a boundary, which is a different shape on purpose
   and not a second description of the same one.

### What was deliberately refused

Recorded because a list read later without its exclusions looks like an oversight.

- **A default boundary for privileged credentials.** Refused: it presumes a privileged/unprivileged
  split that not every project has. `init-project` asks about it in block 8 and proposes nothing.
- **Ownership checks and idempotent retries.** Not refused but not duplicated — both are already
  safe defaults in `failure-axes.md`, where they already block. Restating them here would put one
  rule in two places, and two copies of a rule diverge.
- **Log format and code style.** Not invariants. Their violations are caught by a linter, and a
  rule a tool already enforces does not need a reviewer.

## 5. What gets written

| File | From |
| --- | --- |
| `AGENTS.md` | every block |
| `CLAUDE.md` | 1.3, 5 (skill table rows), 8 |
| `README.md` | 1, 2, 6, 8 |
| `.github/workflows/ci.yml` | 2, 3.2, 6 |
| package manifest — `package.json` or `*.csproj` / `global.json` | 2 |
| `.nvmrc` or `global.json` | 2 |
| `.claude/settings.json` | 3.1 (tracker plugin), 5 |
| `.mcp.json` | 3.1, when the tracker needs a server |
| `docs/decisions/0001-stack-and-validation.md` | 2, 6, plus the base-template stamp |
| `docs/decisions/0002-architecture-boundaries.md` | 8, when it was answered |
| `TEMPLATE.md` | deleted |

The stamp in `0001` records the `base-proj` commit and the date this project was created from it.
Nothing reads it automatically — the template deliberately has no synchronisation mechanism — but a
hand comparison later is impossible without it.

## 6. Re-running

`/init-project` in an already-initialized repository — no `TEMPLATE.md`, no placeholders — enters
reconfiguration mode:

- Ask which block to revisit, or accept `--block <n>`.
- Show what that block currently produces and what would change.
- **Treat any section whose current content differs from what the skill would have generated as
  human-owned.** Show the difference, ask, and never replace without the answer. The most valuable
  content in `AGENTS.md` after six months is the part somebody edited by hand.

## 7. Degrading

- The platform CLI is unavailable → derive what can be derived from `git remote`, ask for the rest,
  and say which values were asked rather than derived.
- No git repository → say so and stop. Branch conventions, the base branch, and the stamp all
  require one.
- The human abandons the interview midway → write nothing. A half-configured `AGENTS.md` is worse
  than an untouched template, because the placeholders are what make the template's state obvious.

## 8. Acceptance criteria

Mechanically checkable, on a fresh clone:

1. `grep -rn '{{' --include='*.md' --include='*.yml' --include='*.json' .` returns nothing except
   `{{TODO}}` markers explicitly recorded in the final report.
2. `TEMPLATE.md` does not exist.
3. The CI workflow parses as YAML, and every `run:` step contains a command rather than a
   placeholder.
4. Each of the eight proving commands either runs successfully or is recorded in `AGENTS.md` as
   not applicable, with a reason.
5. `docs/decisions/0001-*.md` exists and names the base commit.
6. `docs/engineering/` is byte-identical to the template. **This is the acceptance test that
   matters most** — it is the mechanical proof that the interview cannot reach the doctrine.
7. The final report lists every value that was asked rather than derived, and every placeholder
   left standing.

Behavioural, judged by reading the transcript:

8. The fork map appeared before the first question.
9. Every question carried its position and what was already settled.
10. No question asked something the repository could answer.
11. Every option said what it costs, and at least one said what it does not fix.
12. The .NET profile stated that its defaults are unverified.

## 9. Out of scope

- Any synchronisation between the template and projects made from it. Decided against; see
  `TEMPLATE.md`.
- Creating the remote repository, configuring the platform, or installing plugins. The skill writes
  files and says what else needs doing.
- Scaffolding application code. The template ships an engineering process, not an application.
- A third stack profile. Added when a real project needs one, with commands taken from that
  project's actual runs.
