# Writing the automation companion

`qa/<task-id>/automated.md` answers one question for a developer: of everything the manual document
describes, what is worth turning into a test that runs by itself, and where does it go?

It is a recommendation document. This skill does not write tests, and it does not run them.

## Read the project's own answer first

Never propose a tool. `AGENTS.md` already names one command per proving role, and the project's
existing tests already establish the levels it works at. Read both before writing a line:

- The **unit test** and **single test** commands tell you the runner and how a developer will
  execute what you propose.
- The **integration / data layer** command, and the **Where each is proved** line, tell you which
  level is allowed to touch real infrastructure and where it is allowed to run. A recommendation
  that needs a database on a machine that has none is a recommendation nobody will act on.
- A role recorded as one this project cannot prove is a real constraint. Say so, rather than
  proposing tests at a level that does not exist yet — and if the missing level is the one this
  feature needs, that gap is the most useful thing this document can say.

Match the layering the repository already uses. A proposal that introduces a new level of testing
alongside three existing ones has proposed a project decision, not a test.

## Which surfaces the harness can actually reach

Most products have surfaces an automated driver reaches directly and surfaces it cannot: a
conversational interface, a third-party client, a scheduled job, a device. Name both groups
explicitly, because the split decides the entire shape of the document.

For a surface the harness cannot drive, there is usually still a seam behind it — the transport the
client speaks, the queue the job reads, the endpoint the device calls. Say which seam and what it
costs to drive: exercising the seam proves the logic and not the client, and the difference belongs
in the document rather than in the reader's assumptions.

Where no seam exists, the behaviour stays manual. Say so and point at the manual case, so the next
person does not re-derive the same conclusion.

## What to recommend, and what to leave alone

Automate the **regression** cases. That is what the tag is for: an invariant that must hold forever
is exactly what pays back the cost of a test, and a one-off acceptance check is true once and then
dead.

Two more filters, both about cost rather than principle:

- **A case whose setup is harder to keep true than the behaviour is to break.** Elaborate fixtures
  rot, and a test whose fixture is wrong fails for reasons nobody reads. Prefer testing the same
  invariant at a lower level, and say that is what you are doing.
- **A case that asserts something the type system or a proving command already establishes.** It
  will never fail independently, and every future change pays to keep it compiling.

Say what deliberately stays manual, and why. A document that recommends automating everything is
not a recommendation, and the reader stops distinguishing its entries.

## Shape

```markdown
# Automated coverage — <task-id>: <title>

## What the harness can reach here

<Surfaces the project's tooling drives directly; surfaces it cannot, and the seam behind
each — or the statement that there is none.>

## Recommended

### A1 — <invariant, in one line>
**Covers:** T2 (regression)
**Level:** <the level in this project's own layering>
**File:** `<create or extend this exact path>`
**Setup:** <fixtures, substitutes, and what must be real>
**Assert:** <the observable behaviour, not the implementation>
**Why here:** <why this level rather than the one above or below>

## Deliberately manual

| Case | Why it stays manual |
| --- | --- |
| T4 | Needs a human to judge the rendered output |

## Gaps this task revealed

<Anything the project cannot currently prove that this feature needed — a missing level, an
absent command, infrastructure that only exists in CI. One line each. This section is why a
reader who automates nothing still benefits from the document.>
```

**Name exact files.** "Add a test for the import worker" is a note to self. `Extend
src/import/worker.test.ts` is a recommendation somebody can act on in the time they have.

**Address cases by id.** The manual document and the registry both do, and a recommendation that
paraphrases a case instead of citing it drifts from it the first time the case is edited.
