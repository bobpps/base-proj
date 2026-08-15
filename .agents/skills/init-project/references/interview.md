# The interview

Every question, its type, its default, and what makes it answerable. Read this before block 1.

`docs/engineering/asking-questions.md` is the rule this file implements. Where the two seem to
disagree, that file wins: it is doctrine, and this one is an application of it.

Four things every question carries, and they are not decoration:

- **Position** — which block, and what is already settled. A human three questions into an
  interview has forgotten how many are left.
- **What the answer settles**, in the option text itself, not in a preamble nobody re-reads.
- **What each option costs.** An option with no cost is a recommendation wearing a question's
  clothes.
- **What at least one option does not fix.** This is the one most often dropped, and it is the one
  that stops an answer being read as a guarantee.

Sizing: a question whose wrong answer costs a rename gets one line. A question whose wrong answer
puts a rule in the repository for a year gets the full card.

---

## Block 1 — Identity

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 1.1 | Project name | confirm a derived value | the directory name, kebab-case |
| 1.2 | One line describing what it is | free text | — required |
| 1.3 | Language the agent replies in | choice | Russian |
| 1.4 | Language of human-facing documents — README, QA package | choice: same as 1.3 · English | same as 1.3 |
| 1.5 | A paragraph: what this is, for whom, and what problem it removes | free text | — required |

1.5 is not 1.2 at greater length. The one line is what somebody reads in a list of repositories;
the paragraph is what an agent reads before touching code, and it goes into `README.md` in full and
into `AGENTS.md` condensed to the part that constrains a change.

1.2 has no default and cannot be skipped. It becomes the first line of `README.md` and the
one-line description in `AGENTS.md`, and it is the sentence every later agent reads first to decide
whether a change belongs to this project at all.

**Repository-facing text is not asked about.** Code, identifiers, commit messages, branch names,
pull-request titles and bodies, `AGENTS.md`, `CLAUDE.md`, and `docs/engineering/` are English. That
is fixed because the reviewer agents and subagent briefs this repository meets are English, and a
rule translated at that boundary loses precision. Say this once, in the block, rather than letting
the human discover it after answering.

---

## Block 2 — Stack and proving commands

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 2.1 | Stack profile | choice: TypeScript/Node · .NET · other | derived if a manifest exists, else asked |
| 2.2 | Layout | choice: single package · workspaces / solution with several projects | single |
| 2.3 | Does the project produce a runnable artifact? | yes/no | yes |
| 2.4 | The eight proving commands, plus setup, format-write, and supporting | confirm-or-edit, one screen | from the profile |
| 2.5 | Runtime version to pin | confirm a derived value | `node --version` or `dotnet --version` on this machine |

| 2.6 | What `build` and `smoke` actually run | free text, asked when 2.4 leaves a wrapper script | — |

2.6 exists because some of the profile's defaults are **wrapper scripts rather than commands**.
`npm run typecheck` has `tsc --noEmit` behind it and the profile says so; `npm run build` and
`npm run smoke` have nothing behind them, because what they run depends on the bundler and the
entry point, which no profile can know. Writing the manifest with a script name and no body gives
the project two proving commands that fail on their first use, and `evidence.md` calls that the
failure the whole doctrine exists to prevent.

Ask for the bodies, or record those roles as ones this project cannot prove yet. Do not invent a
bundler.

2.5 exists because the pin is a file — `.nvmrc`, `global.json` — and CI reads it through
`node-version-file` or `global-json-file` rather than a literal. There is nothing to derive it from
in a fresh project: no manifest exists yet. Asking with the machine's own version pre-filled is
honest; writing an empty pin, or inventing a version, gives CI a setup step that fails on a
repository nobody has run yet.

**2.4 shows all eight at once.** They are one decision — the project's proof surface — and
splitting them into eight prompts is how an interview becomes a form.

**Where the artifact is a library**, record the smoke role as `not applicable — library` rather
than leaving it blank. `evidence.md` distinguishes "cannot be proved" from "nothing to prove", and
so must the file it reads.

The commands, the manifest, and the CI setup steps for each profile are in `profiles.md`.

---

## Block 3 — Tracker, branches, pull requests

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 3.1 | Where tasks live | choice: GitHub Issues · Linear · files in `docs/tasks/` | GitHub Issues |
| 3.2 | Base branch | confirm a derived value | the repository's current default |
| 3.3 | Remote | **asked, and required, only when `git remote` lists more than one** | `derived` |
| 3.4 | Branch pattern | confirm-or-edit | `{author}/{task-id}` |
| 3.5 | Commit subject convention | confirm-or-edit | `{task-id}: <imperative subject>` |
| 3.6 | Worktree root | confirm-or-edit | `.worktrees/` |

**3.3 is asked precisely when the repository cannot answer it.** `scripts/worktree-setup.sh` works
with one server per run: where there is exactly one remote it uses that, and where there are
several it refuses until one is named. So a project with several remotes whose Remote row still
says `derived` cannot set up a worktree at all — the answer is required, not optional.

**Zero remotes is not the same case as one.** It is the normal state right after the setup steps,
which replace the history and take the cloned `origin` with it. Do not ask 3.3 — there is nothing
to choose between — but do not let it pass silently either: the Remote row takes `derived`, and the
final report names the missing remote as an unmet prerequisite. `SKILL.md` has the table.

When it is asked, say in the option text what it settles: the named server is fetched, the branch
is created from it, merged from it, and pushed to it, and branches on the other remotes are outside
every run. `docs/decisions/0001-one-remote-per-run.md` carries the reasoning if the human wants it.

Everywhere else write `derived`. A name recorded by hand goes stale; the single-remote case has a
mechanism that stays current.

**Choosing Linear** adds a note to `AGENTS.md` that the pipeline needs the Linear MCP server, and
adds the tracker-comment etiquette: exactly two comments per run — one at the start, one at the end
— and a third only when the run stops on something a human must resolve. Review conversations
belong on the pull request; answering a reviewer in the tracker puts the answer where the reviewer
will never see it.

**Choosing files in `docs/tasks/`** removes every tracker call from the generated `AGENTS.md` and
says plainly that acceptance criteria come from the task file.

---

## Block 4 — The automated reviewer

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 4.1 | Automated reviewer on pull requests | choice: Codex connector · Copilot · none · other | none |
| 4.2 | How a fresh pass is requested | confirm-or-edit | per 4.1 |

Whatever is chosen, `AGENTS.md` records the reviewer's account name, the request mechanism, and
this sentence verbatim:

> The surfaces this reviewer uses have not been verified against this repository's own pull
> requests; verify them on the first real run and correct this section.

That is not hedging. `review-loop.md` builds a verdict out of which surface said what about which
commit — the account name, the submission state, the badge scale, whether findings arrive as
line-anchored comments — and every one of those is a property of a specific reviewer on a specific
platform at a specific time. A pipeline that assumes them reports a clean round it never observed.

**"None" is a real answer.** Record it as such: `review-loop.md` says an absent reviewer is not a
clean round, and the pipeline goes to its final phase instead of waiting for a verdict nobody will
give.

---

## Block 5 — Contours

One multiple-choice question. Defaults come from the template's own decisions and are pre-selected:

| Contour | Default | What turning it on costs |
| --- | --- | --- |
| Codex edition and generated `.agents/` | **on** | every rule expressed twice, in two harness vocabularies |
| QA package for a human tester | **on** | a `qa/` corpus, kept current per finished feature |
| Cursor rules | **unavailable** | — see below |
| Vendor plugin and user skills into `.agents/` | off | one machine's installed set committed to the repository, ageing unnoticed |

**Cursor rules cannot be turned on.** Nothing in the writing map creates them and no template
exists to create them from, so enabling a contour whose only defined operation is deletion asks the
agent to invent both the format and the rules — and the rules it would invent are this
repository's, restated from memory into a third file that then drifts from the two that are real.
Offer it again when there is something to write.

**The QA package is on by default and creates nothing at setup time.** `qa-architect` writes its
documents when a feature is finished, so what the contour decides is whether the skill and its
`CLAUDE.md` row stay. Turning it off deletes both.

It has one consequence elsewhere in this interview, and it is easy to miss because it lands in a
different block: question 1.4 offers the language of human-facing documents as covering the README
**and the QA package**. The manual test plan's reader is frequently a contractor rather than a
developer, so where 1.4's answer is not English, `{{DOC_LANGUAGE_EXCEPTIONS}}` names the QA
documents alongside the README. With the contour off, it names the README alone.

**Two things are not on this list, and both were considered for it.**

*Decision records in `docs/decisions/`* are not optional, because the doctrine already depends on
them: the pipeline reads every file in that directory in its first phase, a reviewer finding is
rejected against a recorded decision, and the base-template stamp lives in the first record. An
opt-out here would produce a repository whose pipeline reads a directory that was deliberately
deleted — an input with no valid output. If the human asks for it anyway, that is a change to
`checkpoints.md`, and therefore a decision record rather than an interview answer.

*The retrospective loop* is not asked about either. It costs one report per run, it is non-blocking
by construction, and without it the rules stop improving — which is the reason this template
exists.

**Turning a contour off deletes its files and removes its rows from the tables in `CLAUDE.md`.** A
skill listed in a table but absent from disk is worse than an absent skill: the table is what the
next agent reads to decide what is available.

---

## Block 6 — The line between this machine and CI

| # | Question | Type |
| --- | --- | --- |
| 6.1 | Which roles can only be proved in CI | multi-select over **seven** of the eight roles |
| 6.2 | Why — what the developer machine lacks | free text |

**`Single test or file` is not among the choices.** It is the command that serves the inner loop —
run this one test, now, while thinking about it — and CI has no use for it, because CI runs all of
them. There is no workflow step that could execute it, so offering it would let a project record a
role as proved in CI that no job invokes.

If someone says this project genuinely cannot run a single test locally, that is not a
configuration answer. It means the project has no local inner loop, which is worth writing down
plainly in `AGENTS.md` rather than encoding as a CI line that nothing executes.

Both answers go into `AGENTS.md`, and 6.2 also becomes a decision record. A line drawn without its
reason gets crossed by the first person in a hurry.

**"None" is a valid answer** and is recorded as such: it means every role is provable locally,
which is a real property of small projects and should not be dressed up as an omission.

---

## Block 7 — This project's risk and security additions

| # | Question | Type | Default |
| --- | --- | --- | --- |
| 7.1 | What else counts as Risky here | free text, base list shown read-only | none |
| 7.2 | Security rules this project adds | free text | none |

**The human adds; they cannot remove.** Removing an item from either base list is a change to the
doctrine, and an interview does not make those. If the human wants something off a list, that is a
decision record and a change to `checkpoints.md` — say so and leave the list alone.

**7.2 is its own question, not a re-reading of 7.1.** They fill different sections of `AGENTS.md`
and they answer different things: 7.1 says which work needs a human gate, 7.2 says what must never
happen regardless of who approved it. An answer about model changes being risky is not an answer
about credentials, and copying one into the other writes a security rule nobody stated.

**"None" is a real answer to either**, recorded as such. The base lists already carry the rules
that hold everywhere; a project with nothing to add is a project whose additions are genuinely
empty rather than one that was never asked.

---

## Block 8 — Architecture boundaries and scope

| # | Question | Type |
| --- | --- | --- |
| 8.1 | What this project **does** — the scope it commits to | free text, or "not yet" |
| 8.2 | The layers a change can belong to, and what each owns | free text, or "not yet" |
| 8.3 | Invariants that hold regardless of layer | multi-select, prefilled with the defaults below |
| 8.4 | What is explicitly **out** of scope | free text, or "not yet" |

8.1 and 8.4 are one pair and are asked together. `README.md` carries both, and out-of-scope read
without in-scope is a list of refusals with nothing to refuse against.

**This is the block the skill cannot help with, and it should say so.** The boundaries come from
understanding a product that, at the moment this question is asked, does not exist yet. **"Not yet"
is an honest answer** and is recorded as a `{{TODO}}` marker pointing back at this block, so a
later run can fill it.

### The default invariants

Offered pre-selected. The human deselects what does not apply, and only what survives is written.
An invariant nobody intends to enforce is worse than an absent one: it trains reviewers to skim the
section.

Each is stated as a **property, never as a mechanism** — a route that satisfies the property by
other means satisfies it. `failure-axes.md` explains why the alternative teaches people to argue
with the rule instead of with the code. Each also carries what it does **not** cover, so the gap is
known rather than assumed.

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
   test is not "is this slow" — a judgement, and therefore useless in review — but "who decides
   when this finishes".
   *Does not cover:* a normally fast external call that is occasionally slow. That needs a timeout
   budget, which is a design decision rather than an invariant.

4. **Derived data never overwrites its source.** Source and derived are stored separately and stay
   distinguishable; each derived value records what produced it and when; and the input to a later
   step is chosen **by role, never by recency**.
   *Does not cover:* which of two derivations of the same role wins.
   The recency half is the expensive one, and the reason this is worded in three parts: a pipeline
   that takes "the newest" input will one day take a cleaned-up derivative as though it were the
   original, and report confidently about something that never happened.

5. **A boundary becomes a public contract the moment code on the other side cannot be updated in
   the same commit.** From then on a breaking change is a new version. Before then there is nothing
   to version.
   *Does not cover:* the honesty of that judgement, which is where it will actually fail.

6. **Any unit of work can be traced from input to result.** What processed it, how many attempts it
   took, and how its state changed are recorded.
   *Does not cover:* log format, retention, or where the records are read from.

7. **The environment is parsed by a schema at startup, and the process fails immediately and
   entirely.** Not an hour later, on the first request that needed the missing value.
   *Does not cover:* values that are present and become invalid only at the moment of use.

8. **One source of truth for the shape of data across layers.** Described once and reused, not
   re-described at each boundary.
   *Does not cover:* a deliberate projection at a boundary, which is a different shape on purpose
   and not a second description of the same one.

### What was deliberately refused

Recorded because a list read later without its exclusions looks like an oversight. Do not propose
these; if the human raises one, this is the reasoning.

- **A default boundary for privileged credentials.** Refused: it presumes a privileged/unprivileged
  split that not every project has. Block 8 asks, and proposes nothing.
- **Ownership checks and idempotent retries.** Not refused, but not duplicated — both are already
  safe defaults in `failure-axes.md`, where they already block. Restating them here would put one
  rule in two places, and two copies of a rule diverge.
- **Log format and code style.** Not invariants. Their violations are caught by a linter, and a
  rule a tool already enforces does not need a reviewer.
