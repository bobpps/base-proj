---
name: qa-architect
description: >
  Turns a finished task into the QA package a human testing effort actually needs: a step-by-step
  manual test plan written for someone who has never seen this product, plus a companion document
  saying what is worth automating and what deliberately stays manual. Every case is tagged one-off
  or regression, carries a machine-readable link to the code it covers, and regression cases are
  registered centrally. Also flags cases in other tasks that this change made stale. Use whenever a
  feature is finished and a person will have to test it — "как это тестировать", "напиши тест-план",
  "нужны ручные тесты", "QA ticket", "acceptance checks", "regression cases" — even when nobody says
  "QA". Non-blocking; writes documents only, never runs a test.
user_invocable: true
argument-hint: "<task-id> [worktree-path]"
---

# qa-architect

Two documents per finished task: one for the person who will exercise the product by hand, one for
the developer deciding what to automate. Designing the first is what tells you what belongs in the
second, so they are written in that order.

**This skill only writes documents.** It never runs a test, applies a migration, executes SQL,
pushes, or touches the tracker. The caller owns commits and cleanup.

**It is non-blocking.** A missing QA document must never hold up a pull request or the removal of a
worktree. If something here fails, say so in one line and return.

## Inputs and outputs

`<task-id>` is required — derive it from the branch when the branch matches the project's pattern
in `AGENTS.md`, and say which id was derived. `<worktree-path>` defaults to the repository root;
everything is read and written under it.

**Whoever invokes this owns the commit.** No pipeline edition runs it automatically — a QA package
is worth writing when a change is user-observable, which most runs are not, so it is asked for
rather than produced by default. Say the paths back to the caller and say the files are
uncommitted. **When the invocation is inside a task worktree, say so explicitly**: that worktree is
removed at the end of the run, so documents nobody stages disappear with it, exactly as an
uncommitted retrospective would.

Two files belong to this task:

| File | Contents |
| --- | --- |
| `qa/<task-id>/manual.md` | Manual cases, written for a tester who has never seen this product |
| `qa/<task-id>/automated.md` | What to automate, where, and what stays manual on purpose |

Three are shared and long-lived — created on the first run, kept current afterwards:

| File | Contents |
| --- | --- |
| `qa/README.md` | What the product is, its domain vocabulary, its surfaces, its environments, how to get access and reset state. The onboarding a tester reads once |
| `qa/regression.md` | Every regression case across all tasks, plus a file-to-cases reverse map |
| `qa/automation-setup.md` | The state of the automated-test stack and what bootstrapping it involves |

The split exists so the same paragraph is not regenerated per task. A per-task document that
re-explains the whole product drifts from its siblings within a month, and a tester reading two of
them cannot tell which is true. Explain the product once in `qa/README.md`; in the task document,
explain this feature and link.

**Write the manual document in the language `AGENTS.md` names for human-facing documentation.** Its
reader is a person, frequently a contractor, not an agent — this is exactly the case the
`DOC_LANGUAGE_EXCEPTIONS` row exists for. Identifiers, file paths, and code stay in English inside
it.

## Who reads the manual document

It fails more often than the other one, and always for the same reason: it gets written by someone
holding the whole system in their head, for someone holding none of it.

Picture the reader. They started this week, on contract. They do not know the domain nouns, they
cannot tell one of the product's surfaces from another, and when a step says "confirm processing
started" they have no idea what that looks like on screen — or, worse, no way to tell a defect from
their own mistake.

So the standard is not "detailed". It is: **someone who knows nothing can execute this and be
certain whether it passed.** Name the surface, quote the literal input to give, and describe the
expected result as something visible. Where a step needs domain vocabulary, explain it inline in a
clause or send them to the glossary.

## Workflow

### 1 · Ground the task

Read what the change was *for* before reading how it was written — a diff shows edits, not intent.
Read whichever of these exist: `tasks/<task-id>/plan.md` for the acceptance criteria, the gate's
answers, and the per-path axis rules; `implementation.md` for what deviated and which safe defaults
were applied; `review.md` for deferred and documented findings — that last one is what a tester must
not re-discover as defects; and the task itself in the tracker `AGENTS.md` names.

Then the change:

```bash
git -C <worktree> diff <base>...HEAD --name-only
git -C <worktree> diff <base>...HEAD
```

**An empty diff does not mean nothing happened.** It usually means the task is already merged and
this skill was invoked after the fact. The two situations look identical from `<base>...HEAD` and
they mean opposite things, so recover the change rather than concluding there is nothing to test.

**Ask the platform first.** `AGENTS.md` names it and the command that talks to it, and a pull
request records the commits it merged whatever strategy was used to land them. That answer is
authoritative; everything below is what to do when the platform cannot be reached.

From history alone, the shape depends on how the branch landed, and one recovery does not fit all
three:

| Landed as | What to look for | What to diff |
| --- | --- | --- |
| a merge commit | a merge whose second parent is the task branch | `<merge>^1...<merge>` |
| a squash commit | one ordinary commit on the base branch carrying the task id | `<commit>^..<commit>` |
| a rebase | a run of ordinary commits, with nothing marking where it starts | the range, once its ends are identified |

**A squash or a rebase leaves no merge commit at all**, so a recovery that insists on finding one
concludes there is nothing to test for two of the three common strategies. Say which shape you
found; where none of them can be identified, ask rather than writing a document about nothing.

Searching history by task id matches commit bodies too, so a neighbouring task that merely mentions
yours comes back as a hit. Validate what you found before diffing it — a merge by its second
parent's branch name, a squash by its own subject naming this task and its diff touching what the
task described — or the test plan will describe someone else's feature.

**Where later work has landed on top, describe what the base branch does now**, not what the diff
did. The tester will exercise today's product; a document faithful to a three-week-old diff sends
them to report a defect against a deliberate change.

Read the changed files in full where the budget allows — behaviour lives in how new code meets old
code, and a hunk hides that. On a large change, read in full only the files carrying behaviour a
tester can observe, skim the rest, and lean on the artifacts. A finished document built on partial
reading beats a perfect understanding that never reached a file.

### 2 · Map changed paths to surfaces a tester can reach

A tester exercises screens, endpoints, and conversations — not modules. Build the translation from
`AGENTS.md`'s architecture boundaries, which is the only place this repository states which layer
owns what, and never from a table written into this file: a hardcoded path map is wrong for every
project but the one it was written in.

For each changed path, answer: which layer owns it, and which surface does a human reach that layer
through? A layer with no human-reachable surface — a shared library, a migration — is context that
explains the feature rather than something to test alone. Test the feature that uses it.

Give particular care to any surface the project's proving commands do not cover. Read the **Where
each is proved** line in `AGENTS.md`: a surface with no automated coverage is one where a manual
pass is the only thing between a defect and production, and it deserves the deepest cases in the
document.

**If nothing user-observable changed** — a refactor, infrastructure, documentation, CI — do not
invent cases. Open `qa/regression.md`, find the regression cases whose code links intersect this
diff, and write a short `manual.md` saying: behaviour should be unchanged, here is what to re-run
to confirm it, with links. That is the honest answer for a refactor and it is the moment the
registry earns its keep. Skip `automated.md`, and say why.

### 3 · Design the cases

**Anchor the set to the acceptance criteria — roughly one case per criterion** — plus a case for
each branch visible in the code that a tester could reach by another route: an error path, a
permission boundary, a state that only appears on a repeat. Scope then follows the task rather than
your appetite. A criterion that cannot be exercised by hand belongs in `automated.md` instead of
being padded into a manual case.

The plan's five-axis rules are the richest source of edge cases in the whole artifact set: each one
states what the code does when the store fails, when there is nothing there, when the shape is
wrong, when two attempts race, and when ownership does not match. Those are the cases nobody thinks
to write from a feature description. Take the ones a tester can actually reach.

Tag every case, because the tag decides whether it enters the registry and whether automating it
pays for itself:

- **one-off** — an acceptance check. True once, then dead. Nobody re-runs it.
- **regression** — an invariant that must hold forever.

When torn, ask whether you would want to hear about it breaking in six months.

Give each case a stable id (`T1`, `T2`, …). The registry and the staleness pass both address cases
by id, so renumbering an existing document silently breaks links elsewhere — append, never
resequence.

**Read `references/manual-plan.md` before writing**: the case template, why each field exists, state
reset, seed data, and the rule that resolves placeholders against executability.

### 4 · Write the two documents

`manual.md` first, then `automated.md` — which reads as recommendations against this repository:
which file to create or extend, at which level of the project's own test layering, what to
substitute, what fixtures are needed. **Read `references/automation.md`** for its shape and for how
to decide what not to automate.

Where the files already exist, keep **one current set of cases** rather than appending a section per
run: update what changed, delete what no longer exists, add what is new. A document that grows by
accretion stops being a test plan and becomes a changelog nobody trusts.

### 5 · Update the shared files

- `qa/README.md` — create on the first run; afterwards extend it only when this task introduces a
  concept, surface, or environment a tester would otherwise not understand.
- `qa/regression.md` — one line per regression case pointing at its full text, plus the file-to-cases
  reverse map. The registry is an index, not a second copy; the full case lives in the task document
  so the two cannot disagree about wording.
- `qa/automation-setup.md` — create on the first run to record what the stack is and what
  bootstrapping it involves; afterwards update it only when the stack actually changes. Repeating
  the same setup advice in every task trains the reader to skip it.

### 6 · Review other tasks' cases for staleness

A change can invalidate a case written months ago for a different task, and nobody notices until a
tester follows steps that no longer work and files a defect against reality. **Read
`references/staleness.md`** for the procedure — including deleted and renamed files, which are the
most certainly-stale cases of all.

Skip this entirely on the first run, when `qa/` does not exist yet, and say in one line that you
did.

When a case is stale, **mark it and explain — never rewrite it.** You are looking at it through the
lens of your own task and cannot see what its author was protecting. A wrong rewrite silently
removes coverage while the document still looks healthy; a marked case makes a human decide.

### 7 · Report

At most ten lines: the files written, case counts split by one-off and regression, whether seed data
is required, and any cases marked stale elsewhere. If a document was skipped, say which and why.

## Rules worth being strict about

1. **Never execute anything.** Seed data lives inline in the document as a seed block and a matching
   rollback block, for a human to run against a development environment.
2. **Never invent environment specifics.** A hostname, credential, or handle you would have to guess
   stays a placeholder — a confidently wrong URL costs a tester an hour and teaches them to distrust
   the document.
3. **Verify names against the real schema before writing any data setup.** Setup that fails to run
   is worse than none.
4. **Degrade gracefully.** An unreachable tracker or database is noted in the document and the run
   continues with what the repository can answer. Only a missing task id genuinely blocks you.
