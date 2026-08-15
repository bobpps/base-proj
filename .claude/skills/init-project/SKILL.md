---
name: init-project
description: >
  Turns a fresh clone of the base-proj template into a configured project: interviews the human
  about the product, the stack and its eight proving commands, the tracker, branch conventions,
  the automated reviewer, and the architecture boundaries — then fills AGENTS.md, CLAUDE.md,
  README.md, the CI workflow, the manifest, and the first decision records. Use it whenever the
  repository still holds TEMPLATE.md or {{PLACEHOLDER}} values, and whenever the human says "set
  up this project", "initialize the template", "настрой проект", "заполни AGENTS.md", or asks to
  redo part of an earlier setup — including when they never name the skill and simply start
  describing a new project in a repository that is still a template. Do not use for ordinary
  configuration changes in an initialized repository; edit the file directly.
user_invocable: true
disable-model-invocation: true
argument-hint: "[--block <n>] [--dry-run]"
---

# init-project

A clone of `base-proj` carries the full engineering doctrine and an unconfigured shell: rule files
full of `{{PLACEHOLDER}}`, a CI workflow with no commands in it, and no idea what the project is.
This skill interviews the human and writes every project-specific value into the files that need
it.

`disable-model-invocation` is deliberate. This skill rewrites the repository's rule files. It runs
when a human asks for it and at no other time.

## The property this skill exists to protect

Two layers, and this skill only ever touches one:

| Layer | Lives in | May this skill write it? |
| --- | --- | --- |
| **Doctrine** — how work is proved, the failure axes, the checkpoint contract, the review loop, how to ask a human, how to write a skill | `docs/engineering/` | **Never.** Not a word, not a placeholder, not an exception. |
| **Embodiment** — names, commands, conventions, boundaries, contours | `AGENTS.md`, `CLAUDE.md`, `README.md`, CI, manifests, settings, decision records | Yes. This is the whole job. |

The interview cannot weaken a rule because no question it asks is capable of reaching one.
`evidence.md` says a proving command must be green before any claim of completion; the interview
only decides what that command is called.

If a question would need a doctrine file edited to take effect, the question is wrong — or the
doctrine is, and that is a decision record, not an interview answer. Say so and stop rather than
resolving it quietly.

**Check it rather than intending it.** Record the checksum before the first question and compare
after the last write:

```sh
scripts/doctrine-checksum.sh
```

## Before the first question

**1. Confirm there is a git repository.** Without one there is no base branch, no branch
convention, and no commit to stamp. Say so and stop.

**2. Derive everything the repository can answer.** A question about something readable is not
thoroughness, it is unfinished research, and it teaches the human that their answers are being
collected rather than used:

| Derive | From |
| --- | --- |
| Project name | the directory name, kebab-cased |
| Base branch | the repository's current default |
| Remote | `git remote` — and only ask when it lists more than one |
| Stack profile | a `package.json`, a `*.csproj`, a `global.json` if present |
| Platform and reviewer candidates | the remote host, and whichever platform CLI is installed |

**3. Record the doctrine checksum**, per the section above.

**4. Publish the fork map before asking anything.** `docs/engineering/asking-questions.md` governs
every question here, and this skill is that doctrine's own showcase — a sloppy interview here
discredits the rule everywhere else. The map is the eight blocks, what each settles, and which are
skippable. A human who cannot see the shape of the interview cannot tell whether an answer they are
about to give is load-bearing.

## The interview

Eight blocks, walked in order. Blocks 1–4 are required; 5–8 are skippable with a recorded default.

| # | Block | Settles |
| --- | --- | --- |
| 1 | Identity | name, one-line description, the language the agent replies in |
| 2 | Stack and proving commands | the eight commands `evidence.md` reads |
| 3 | Tracker, branches, pull requests | where tasks live, base branch, remote, patterns |
| 4 | The automated reviewer | who reviews pull requests, and how a pass is requested |
| 5 | Contours | which optional parts of the template stay |
| 6 | The local-versus-CI line | which roles only CI can prove, and why |
| 7 | Risk additions | what counts as Risky here beyond the base list |
| 8 | Architecture boundaries and scope | layers, invariants, what is out of scope |

**Read `references/interview.md` before block 1.** It carries every question, its type, its
default, and the option text that makes each one answerable — including which questions must not be
asked because the repository already answers them.

**Read `references/profiles.md` when block 2 reaches the stack**, for the proving commands, the
manifest, and the CI setup steps of each profile.

Two rules hold across every block, and both come from the doctrine rather than from convenience:

- **Never invent an answer.** A value nobody supplied stays a placeholder, and the final report
  names every placeholder still standing. A confidently wrong command is worse than a blank: a
  blank is visible, and a wrong command gets trusted and then quietly proves nothing.
- **Every answer carrying reasoning becomes a decision record**, not just a filled placeholder. The
  stack choice, the local-versus-CI line, and the architecture boundaries all have reasoning worth
  keeping, and a value in a table cannot hold it.

## Writing

**Show the full diff before writing anything, and write only after the human accepts it.**
`--dry-run` stops after the diff.

Nothing is written until the interview finishes. If the human abandons it midway, write nothing at
all — a half-configured `AGENTS.md` is worse than an untouched template, because the placeholders
are exactly what make the template's state obvious.

**Read `references/writing.md` before the first write.** It maps every answer to the file and the
placeholder it fills, and it carries the two operations that are easy to get subtly wrong: renaming
`ci.yml.template` to `ci.yml`, and numbering the decision records from the next free number rather
than from `0001`.

## Verify, then report

Run these and report each result. They are cheap, and every one of them has a failure mode that
looks like success:

```sh
scripts/doctrine-checksum.sh                                    # must equal the recorded value
grep -rn '{{' --include='*.md' --include='*.yml' --include='*.json' .
ls .github/workflows/                                           # ci.yml present, no .template
```

| Check | What a pass means |
| --- | --- |
| The doctrine checksum is unchanged | The interview never reached the layer it must not touch |
| No `{{` remains | Except `{{TODO}}` markers, each of which the report names |
| `ci.yml` exists, `ci.yml.template` does not, and it parses as YAML | CI will actually run — a `.template` never does |
| Every `run:` step holds a command | A placeholder in a `run:` step fails at exit 127, observed |
| Each of the eight proving commands runs, or is recorded as not applicable with a reason | `evidence.md` distinguishes "cannot be proved" from "nothing to prove" |
| A stack-and-validation decision exists, numbered above every decision the template shipped | The base commit is recorded while it is still knowable |

Then delete `TEMPLATE.md`. That is the last act, and only on a complete first run.

The final report says, in the language block 1 chose:

- Every value that was **asked** rather than derived.
- Every `{{TODO}}` still standing, with the block that would fill it.
- Every proving command that could not be run here, and why.
- The doctrine checksum, before and after.

## Re-running

`/init-project` in an already-initialized repository — no `TEMPLATE.md`, no placeholders — is
reconfiguration, not setup:

- Ask which block to revisit, or accept `--block <n>`.
- Show what that block currently produces and what would change.
- **Treat any section whose content differs from what this skill would have generated as
  human-owned.** Show the difference, ask, and never replace without the answer.

That last rule matters more than it looks. The most valuable content in `AGENTS.md` after six
months is the part somebody edited by hand, and a regenerating skill is exactly the mechanism that
silently reverts it.

`TEMPLATE.md` is not deleted again — it is already gone — and the base-commit stamp is not
rewritten, because it records where the project came from rather than when it was last configured.

## When something is missing

- **The platform CLI is unavailable** → derive what can be derived from `git remote`, ask for the
  rest, and say in the report which values were asked rather than derived.
- **No git repository** → say so and stop.
- **The human abandons the interview** → write nothing, and say that nothing was written.
