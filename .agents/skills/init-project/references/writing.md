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
| `.nvmrc` or `global.json` | 2 |
| `.claude/settings.json` | 3.1 (tracker plugin), 5 |
| `.mcp.json` | 3.1, when the tracker needs a server |
| `docs/decisions/<next>-stack-and-validation.md` | 2, 6, plus the base-template stamp |
| `docs/decisions/<next+1>-architecture-boundaries.md` | 8, when it was answered |
| `TEMPLATE.md` | deleted, last |

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

*The `Artifact smoke` step goes when question 2.3 says the project is a library.* `AGENTS.md`
records that role as `not applicable — library`, which is a sentence rather than a command: put it
in `run:` and the shell fails, leave the placeholder and the verification fails. There is no third
option, so the step is removed.

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
