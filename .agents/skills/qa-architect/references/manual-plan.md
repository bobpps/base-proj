# Writing the manual test plan

Everything here serves one goal: a tester who has never seen this product can execute the document
and be certain whether each case passed.

## Contents

- [The case template](#the-case-template)
- [Why each field exists](#why-each-field-exists)
- [Resetting state](#resetting-state)
- [Data setup for cases that need existing data](#data-setup-for-cases-that-need-existing-data)
- [Placeholders versus executability](#placeholders-versus-executability)
- [The regression registry](#the-regression-registry)
- [Document skeleton](#document-skeleton)

## The case template

```markdown
### T1. <short name of the case>

**Type:** regression
**What it checks:** one sentence — which behaviour of the product.
**Why it matters:** what breaks in a user's life if this stops working.
**Where:** <the surface, named the way the tester will recognise it>
**Precondition:** clean state (see "Resetting state")

**Steps:**
1. <one action per line, with the literal input to give>
2. …

**Expected result:**
<What appears on screen. Observable, not internal.>

**If the result differs:** attach <the specific evidence a defect report needs here —
screenshot, identifier, approximate time, which environment>.

**Code:** `path/to/file.ext`, `path/to/other.ext`
```

Render every label except one in the language the document is written in, and keep the wording
identical across all cases and all tasks — a tester scanning twenty cases reads by shape.

**`Code:` stays literally `Code:` in every language.** It is parsed by the staleness pass and by the
registry's reverse map. A translated label breaks both silently: the grep finds nothing, and finding
nothing is indistinguishable from having nothing to find.

## Why each field exists

**Type** — `one-off` or `regression`. Decides whether the case enters the registry and whether
automating it pays for itself.

**Why it matters** — the field that does the most work for an outside tester and the one most often
skipped. A tester who understands the purpose recognises a defect the steps never anticipated; a
tester following steps blindly reports only exact mismatches. It is also where domain vocabulary
gets introduced naturally, one clause at a time, instead of as a wall of glossary up front.

**Where** — never assume the surface is obvious. Most products have several, and "open the app" is
ambiguous across all of them.

**Expected result** — must be observable. "The record is created" is internal state the tester
cannot see. Where the only real evidence is in a data store, say so explicitly and give the exact
query — but prefer a visible consequence whenever one exists, because a query the tester cannot
interpret produces a defect report nobody can act on.

**If the result differs** — turns a confused tester into a useful defect report. Name what to
attach. Without it you get "doesn't work" and a lost afternoon.

**Code** — the machine-readable link that makes the staleness pass affordable. List the source files
this specific case would break with, repository-relative, comma-separated. Not every file in the
diff. Two or three paths is typical; ten means the case is too broad and should be split.

## Resetting state

Most cases are simplest to run from a clean slate, and a contract tester will not work out how on
their own. Explain it once, in its own section of the document, and state per case which reset the
case needs.

Before recommending a reset, **trace what it actually removes for this feature.** Two failures come
up repeatedly and both waste the tester's entire session:

- **It cascades further than its name suggests.** Deletions follow foreign keys, so clearing one
  entity can destroy everything hanging off it. Read the schema rather than the button label.
- **It can make the precondition unreachable.** A feature whose entry point needs an existing
  record cannot be started at all after a reset that removes it. There the honest advice is a second
  test account, not a reset.

A test plan whose first step destroys its own precondition reads as a broken product to the person
following it.

## Data setup for cases that need existing data

Some behaviour only appears against data that already exists. Embed the setup directly in the
manual document — no separate files, because a tester following one document should not have to
hunt for a second.

Provide both halves: a **seed** block creating the minimum required, and a **rollback** block
removing exactly what the seed added.

Two variants come up often enough to name:

- **Read-only verification.** Plenty of cases need no seed at all but do need the tester to confirm
  a stored value. That is not seed data and needs no rollback — put the query inline with the case
  it verifies, and title the section for what it holds. A document promising seed data and
  delivering a read makes the reader hunt for a part that never existed.
- **Mutating an existing record instead of creating one.** Where a record has several foreign keys
  and generated values, building one from scratch is fragile and drifts the moment the schema moves.
  Have the tester produce a real record through the product, then move it into the state under test.
  The rollback is then a matching move back, or the product's own delete.

Verify table and field names against the real schema first. Use obviously-fake test values so
rollback is unambiguous and nobody wonders whether a record was real. Never run any of it yourself.

## Placeholders versus executability

"Never invent environment specifics" and "a novice must be able to execute this" pull against each
other, and the tension is real rather than a rule you are applying badly. A document made entirely
of `<test account>`, `<app URL>`, `<session id>` is unexecutable by exactly the reader it was
written for.

Resolve it by source rather than by taste:

- Anything you would have to **guess** — hostnames, handles, tokens, credentials — stays a
  placeholder. A confidently wrong URL costs a tester an hour and teaches them to distrust the
  whole document.
- Anything you can **read out of the repository** — a route, a field name, a menu label, an error
  code — goes into the text verbatim. That is not invention, it is fact.

For the placeholders that remain, add a short "what to obtain before starting" block naming who to
ask for each one. And where a feature is only reachable through privileged access because no user
path exists, say that plainly at the top rather than letting the tester discover it at step four of
case one.

## The regression registry

`qa/regression.md` is an index, not a second copy of the cases. Keep it in two parts:

```markdown
# Regression cases

> Run before a release. The full text of each case lives in its task document.

| Case | What it protects | Where |
| --- | --- | --- |
| T2 | A failed import still reports a reason to the user | [ABC-401](ABC-401/manual.md) |

## File → cases

| File | Cases |
| --- | --- |
| `src/import/worker.ts` | ABC-401 · T1, T2 |
```

Reference the **file plus the case id as plain text**, never a heading anchor: case headings are
written in the document's own language, so generated anchors are unverifiable offline and usually
dead.

Build the reverse map from the `Code:` lines as you write them. It costs nothing at write time and
turns the next run's staleness pass into a table lookup.

## Document skeleton

````markdown
# Manual tests — <task-id>: <title>

> Task: <link>. Pull request: #<n>. Updated: <date>.
> New to the project: read [qa/README.md](../README.md) first — what the product is,
> what it consists of, and how to get access.

## What changed in this task

<Two to five sentences in plain language: what the product can do now that it could not
before. No file or class names — the reader is not a developer.>

## What you need

<Surfaces, environments, accounts, and access — each either read from the repository or
left as a named placeholder with who to ask.>

## Resetting state

<Which resets exist, what each removes, and which one this document's cases assume.>

## Cases

### T1. …
### T2. …

## Cases in other tasks affected by this change

<Only when the staleness pass found something: links plus one line of explanation each.
Omit the section entirely when it found nothing.>

## Data setup

Apply before the cases marked as needing seed data.

```sql
-- seed: <what it adds and why>
```

**Rollback** — run after testing:

```sql
-- rollback: removes exactly what the seed added
```
````
