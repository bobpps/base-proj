# Writing the answers into the repository

Which answer lands in which file, and the operations that are easy to get subtly wrong. Read this
before the first write.

Nothing here is written until the interview finishes and the human has accepted the diff.

## The map

| File | Filled from |
| --- | --- |
| `AGENTS.md` | every block |
| `CLAUDE.md` | 1.3, 5 (the skill table rows), 8 |
| `README.md` | 1, 2, 6, 8 |
| `.github/workflows/ci.yml` | 2, 3.2, 6 — **renamed** from `ci.yml.template` |
| package manifest — `package.json`, or `*.csproj` and `global.json` | 2 |
| `.nvmrc` or `global.json` | 2.5 |
| `.claude/settings.json` | 3.1 (tracker plugin), 5 |
| `.mcp.json` | 3.1, when the tracker needs a server |
| `.gitignore` | 3.6, whose value it carries too |
| `docs/decisions/<next>-stack-and-validation.md` | 2, 6, plus the base-template stamp |
| `docs/decisions/<next+1>-architecture-boundaries.md` | 8, when it was answered |
| `TEMPLATE.md` | deleted, before the verification |

## Every placeholder, and what answers it

**This table is checked mechanically.** `scripts/placeholder-coverage.test.sh` extracts every
`{{VALUE}}` the template carries and fails if one of them is not named here. That check exists
because five separate review rounds each found a different placeholder that no question produced —
`SETUP_COMMANDS`, `CMD_FORMAT`, `CMD_SUPPORTING`, `SCOPE`, the runtime version — and each was
fixed on its own while the next was still waiting. The question set was written from a
specification rather than from the values it has to answer, and one list checked against the other
closes the whole class.

Adding a placeholder to a template file therefore means adding a row here and a question that
fills it. The check will say so.

| Placeholder | Where | Answered by |
| --- | --- | --- |
| `PROJECT_NAME` | `AGENTS.md`, `README.md` | 1.1 |
| `PROJECT_ONE_LINE` | `AGENTS.md`, `README.md` | 1.2 |
| `PROJECT_DESCRIPTION` | `README.md` | 1.5 |
| `PROJECT_CONTEXT` | `AGENTS.md` | 1.5, condensed to what an agent needs before touching code |
| `USER_LANGUAGE` | `AGENTS.md` | 1.3 |
| `DOC_LANGUAGE_EXCEPTIONS` | `AGENTS.md` | 1.4 — empty **only when human-facing documents are English** |
| `CMD_TYPECHECK` `CMD_LINT` `CMD_FORMAT_CHECK` `CMD_TEST` `CMD_TEST_ONE` `CMD_INTEGRATION` | `AGENTS.md`, `README.md` | 2.4, the eight roles |
| `CMD_BUILD` `CMD_SMOKE` | `AGENTS.md`, `README.md` | 2.4, and 2.6 where the profile's default is a wrapper script with no body |
| `CMD_FORMAT` | `README.md` | 2.4 — formatting in **write** mode, not the check |
| `CMD_SUPPORTING` | `AGENTS.md` | 2.4 |
| `SETUP_COMMANDS` | `README.md` | 2.4 |
| `CI_SETUP_STEPS` | `ci.yml` | 2.1 and 2.5, from the profile — **both jobs** |
| `TRACKER` | `AGENTS.md` | 3.1 |
| `BASE_BRANCH` | `AGENTS.md`, `ci.yml` | 3.2 |
| `REMOTE` | `AGENTS.md` | 3.3, or `derived` |
| `BRANCH_PATTERN` | `AGENTS.md` | 3.4 |
| `COMMIT_CONVENTION` | `AGENTS.md` | 3.5 |
| `WORKTREE_ROOT` | `AGENTS.md`, `.gitignore` | 3.6 |
| `PR_COMMAND` | `AGENTS.md` | 3.1, from the platform |
| `REVIEWER` | `AGENTS.md` | 4.1 |
| `REVIEW_REQUEST` | `AGENTS.md` | 4.2 |
| `VALIDATION_LINE` | `AGENTS.md`, `README.md` | 6.1 |
| `CI_INTEGRATION_JOB_NAME` | `ci.yml` | 6.1 — the job is deleted when nothing is CI-only |
| `RISK_ADDITIONS` | `AGENTS.md` | 7.1 |
| `SECURITY_ADDITIONS` | `AGENTS.md` | 7.2 |
| `ARCHITECTURE_BOUNDARIES` | `AGENTS.md` | 8.2 |
| `ARCHITECTURE_INVARIANTS` | `AGENTS.md` | 8.3 |
| `ARCHITECTURE_SUMMARY` | `README.md` | 8.2, in prose for a human reader |
| `SCOPE` | `README.md` | 8.1 |
| `OUT_OF_SCOPE` | `AGENTS.md`, `README.md` | 8.4 |
| `WORKING_STYLE_ADDITIONS` | `CLAUDE.md` | 5, or empty |
| `PLACEHOLDER` | `AGENTS.md`, `CLAUDE.md` | **not a value** — see below |

### The language exception is written whenever there is one

`AGENTS.md` says everything that lands in the repository stays in English, and then carries
`{{DOC_LANGUAGE_EXCEPTIONS}}` for what does not. Question 1.4 defaults to *the same language as the
agent replies in*, which defaults to Russian — so the common path writes a Russian `README.md` into
a repository whose own rules say documentation is English, and leaving the exception empty makes
the file contradict itself on the day it is generated.

Name the exception: which documents are in which language, and that the rest stays English. Empty
is correct only when the answer to 1.4 was English.

The QA package is the second document this covers. `qa-architect` writes a manual test plan for a
human tester — often a contractor rather than a developer — and reads the language from this row.
Where the QA contour is on and 1.4's answer is not English, name both the README and the QA
documents here; with the contour off, name the README alone.

### The Codex contour, turned off, is more than a deletion

Block 5 can remove the Codex edition and the generated `.agents/`. Deleting those directories and
the `CLAUDE.md` rows is half the job: `AGENTS.md` has a **Skills** section naming
`.codex/skills/task-pipeline/` and the generator that writes `.agents/skills/`, and it would go on
pointing every later agent at paths that are not there.

Rewrite that section to describe what remains. This is the same rule as the skill table — a listing
must match the disk — and it is easier to miss here because the section is prose rather than a
table, so nothing about its shape suggests it holds an inventory.

Afterwards `scripts/skills.test.sh` reports its generated-tree comparison as **skipped**, naming the
absent contour as the reason. That is the correct result and not something to repair: with no
`.codex/` and no `.agents/`, there is no generated tree to compare. Leave the check in place — the
project may turn the contour back on, and a deleted check does not come back with it.

**The same paragraph names every supporting skill**, so turning the QA contour off means editing it
too, not only deleting `.claude/skills/qa-architect/` and its `CLAUDE.md` row. `scripts/skills.test.sh`
checks the table against the disk; it cannot check a sentence, which is why this is written down.

### Removing a skill means removing every copy of it

State it as one rule rather than per contour, because the next contour that removes a skill will not
be the QA one:

> A contour that removes a skill removes **its source directory, its generated copy under
> `.agents/skills/`, its row in `CLAUDE.md`, and its name from the `AGENTS.md` paragraph.**

The generated copy is the one that gets left behind. `.agents/` exists so Codex can discover skills
without running anything first, so a copy that survives its source stays discoverable — the feature
is disabled everywhere a human looks and still live for one harness. `scripts/skills.test.sh`
reports it as `qa-architect(unexpected)`, which is how this was found.

**Delete that directory outright; do not regenerate the tree to achieve it.** Regeneration needs
Node, which a project on another stack has no reason to have installed, and it would rewrite every
other skill as a side effect of removing one.

### The template notes are deleted, not filled

`AGENTS.md`, `CLAUDE.md`, and `README.md` each open with a note saying the file is still the
template and that `/init-project` fills it in. Those notes are true of a template and false of a
configured project, and each carries a literal `{{PLACEHOLDER}}` into a file that is then supposed
to be free of them.

Delete all three, the same way the workflow's header comment goes at the rename. A stale
instruction is worse than no instruction: it describes a state the repository has left.

## The CI workflow is renamed, not just filled

`ci.yml.template` is inert **because of its name**: GitHub runs `.github/workflows/*.yml` and
nothing else. That is what stops a placeholder-carrying workflow failing on every pull request
against `base-proj` itself — which it did, once, at `Run {{CI_SETUP_STEPS}}` with exit 127, before
the rename existed.

So the write is: fill the placeholders, rename to `ci.yml`, and remove the `.template`. A filled
`ci.yml.template` still never runs, and it looks exactly like a working CI configuration.

**Delete the header comment while renaming.** The block at the top explaining `{{PLACEHOLDER}}`
values and why the `.template` suffix keeps the file inert describes a mechanism that stops
existing at the moment of the rename. Left in place it is a stale explanation carrying literal
placeholder examples, in a file that is now supposed to be free of them.

That is the only comment to remove. Everything below it explains a line that is still there.

Two structural pieces are already in the file and are not the interview's to decide — the
concurrency group, the read-only permissions, and the tracked-environment-file guard all carry
their reasoning in comments. Leave them and their comments intact. A configuration line whose
reason is not written down gets deleted by the first person who can see its cost and not its
purpose.

**Two steps are conditional on answers, and both are deletions rather than edits.**

*A step whose role has no command is deleted.* This covers the library case — question 2.3 says
there is no runnable artifact, so `AGENTS.md` records the smoke role as `not applicable — library` —
and it covers every role the Other profile left blank, recorded as one this project cannot prove.
The recorded text is a sentence rather than a command in both cases: put it in `run:` and the shell
fails, leave the placeholder and the verification fails. There is no third option, so the step goes.

State the rule that way rather than naming the smoke step, which is how this was written first. The
smoke step is simply the case that came up; the rule is that **a workflow step exists for a role
this project can prove, and for no other.** A step that runs an explanation is worse than an absent
step, because it fails in a way that looks like the code.

*The `integration` job* is guarded by `if: false`. Block 6 either enables it or the job is deleted
entirely — leaving a disabled job in place is a third state nobody reads correctly.

**Where block 6 enables it, fill its toolchain step as well as its command.** Both jobs carry
`{{CI_SETUP_STEPS}}` and both need the profile's setup and install. A job that only checks out runs
the integration command with nothing installed, which leaves the one role this project decided only
CI can prove as the one that never goes green — and the failure reads as the code rather than as
the workflow.

Two more things that job must do, learned expensively and already noted in the template's comments:

- **Hold no secret and never point at a production environment.** A local stack runs on the
  deterministic keys its CLI prints, which are published constants rather than credentials.
- **Assert that the suite was found and executed**, not merely that the runner exited zero. A
  renamed file otherwise leaves the step green having tested nothing.

## Decision records are numbered from the next free number

Not from `0001`. The template ships decisions of its own — the first is
`0001-one-remote-per-run.md` — and `docs/decisions/0000-template.md` requires the next free number
and forbids reuse. Read the directory and count; a hardcoded `0001` gives every initialized
repository two decisions wearing the same number.

The stack-and-validation record carries the **base-template stamp**: the `base-proj` commit this
project was created from, and the date. Nothing reads it automatically — the template deliberately
has no synchronisation mechanism — but a comparison by hand later is impossible without it.

**Read the commit from `.base-proj-revision`, then delete that file.** It is written by the setup
instructions in `TEMPLATE.md` before `rm -rf .git`, which is the only moment the commit is still
knowable: the line after it replaces the history, and `git rev-parse HEAD` afterwards answers about
the new empty repository instead. Once the value is in the decision record it has a home, and a
loose dotfile in the root would only rot.

Where the file is absent — the human ran the steps out of order, or cloned some other way — record
the stamp as *unknown; the history was replaced before the revision was captured*, and say so in
the final report. **Do not reconstruct it by asking the network what `base-proj`'s HEAD is now.**
That answers a different question: today's tip is not the commit this project was made from, and a
plausible wrong commit in a stamp is worse than a blank, because the whole purpose of the stamp is
to be trusted later by someone comparing two repositories.

Write each record in the shape `0000-template.md` fixes, including **Consequences** and
**Alternatives considered**. A decision recorded with only its upside reads as free, and the next
person reverses it without seeing what they are buying.

## `AGENTS.md` specifics

- The **Remote** row takes `derived` or a server name, per question 3.3.
- The **Worktree root** row takes question 3.6 — **and so does `.gitignore`.** The template ignores
  `.worktrees/` by name, so a human who changes the root gets task worktrees created as untracked
  content inside the main checkout, where they clutter every `git status` and sit one careless
  `git add` away from the commit. The value lives in two files and has to move in both.
- The **proving commands** table takes all eight. A role with no command says, in those words, that
  this project cannot prove it — never a neighbouring command.
- **Where each is proved** takes block 6, and its reasoning goes in the decision record rather than
  in the table.
- **Risk classification** keeps the base list intact and appends block 7.
- **Architecture boundaries**, **Invariants**, and **Out of scope** take block 8, or `{{TODO}}`
  markers pointing back at it.

## `CLAUDE.md` specifics

`CLAUDE.md` is a thin overlay on `AGENTS.md` and stays that way. It carries what is specific to
Claude Code and nothing that `AGENTS.md` already says — a fact in both files is a fact that will
disagree with itself within a month.

Its skill table must match what is actually on disk after block 5. A row for a contour that was
turned off points the next agent at a skill that is not there.

## What must not be touched

- `docs/engineering/` — any file, for any reason. The checksum in `SKILL.md` is the check.
- `scripts/` — the worktree procedure, the review snapshot, and the doctrine checksum are the same
  in every project, and their tests are what make them trustworthy.
- The structural half of the CI workflow, as above.
