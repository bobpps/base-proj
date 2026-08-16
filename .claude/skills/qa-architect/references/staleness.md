# Reviewing other tasks' cases for staleness

A change can break a case written months ago for a different task. Nobody notices until a tester
follows steps that no longer work, cannot tell a broken product from a broken document, and either
files a phantom defect or — worse — decides the case "always fails" and skips it from then on.

## Finding candidates cheaply

The naive version reads every manual document in full on every run. That is affordable at five
documents and ruinous at a hundred, and the cost arrives exactly when the corpus becomes valuable.

So the pass is ordered by cost: a mechanical sweep that finds a well-defined class of candidate,
then a narrower one that finds the class the first cannot, then judgement for the changes that
touch everything.

### 1 · Cases that name a changed path

```bash
git -C <worktree> diff <base>...HEAD --name-only > /tmp/qa-changed.txt
grep -rl -F -f /tmp/qa-changed.txt <worktree>/qa --include=manual.md
```

Read only the matching documents, and inside them only the cases whose `Code:` line contains one of
the changed paths. This is exhaustive for exactly one thing — **every case that names a changed
file** — and that is what the annotation buys, and the reason its label is never translated.

Where `qa/regression.md` carries the file-to-cases reverse map, start there instead: it answers the
same question as a table lookup, and it reaches the cases whose documents the grep would have had
to open.

Skip the current task's own document; its cases are current by construction.

### 2 · Cases that depend on a changed path without naming it

**A case not matched in step 1 is not proven unaffected.** A `Code:` line holds two or three paths —
the writing guide says so — and a case reaches far more code than that through whatever those files
call. Change a shared helper, a route table, a permission check, a formatter, a widely-used
component, and no annotation anywhere names it, so step 1 returns nothing and the corpus looks
clean. An earlier version of this file called that result "provably unaffected"; it proved only
that nobody had written the path down.

One bounded hop closes most of it. For each changed file, find what depends on it, and intersect
*that* set with the annotations:

```bash
# whatever the project's import syntax is — the module name is the searchable part
git -C <worktree> grep -l "<module-or-symbol-name>" \
  | grep -v '^$' | LC_ALL=C sort -u > /tmp/qa-dependents.txt
grep -rl -F -f /tmp/qa-dependents.txt <worktree>/qa --include=manual.md
```

**`git grep -l`, not `grep -rl <worktree>/src`.** A `Code:` line holds repository-relative paths —
`manual-plan.md` requires it — so every path fed to the fixed-string search has to be relative too.
A plain recursive grep over the worktree emits `/abs/path/to/worktree/src/foo.ts`, no annotation
contains that string, the search returns nothing, and step 2 reports a clean corpus having matched
against a prefix. Step 1 works for the same reason without anyone noticing: `git diff --name-only`
is repository-relative already.

Strip blank lines while you are there. A single empty line in a `-F -f` pattern file matches every
line of every document, which fails in the opposite direction — every case becomes a candidate and
the pass stops discriminating.

One hop, not the transitive closure. Two hops out, everything depends on everything and the pass
stops discriminating — which is the same as not running it, at much greater cost.

### 3 · Changes that are cross-cutting by nature

Some changes have no useful dependent list because the answer is "most of the product": routing,
authentication and permissions, session or state handling, layout and navigation, error surfaces,
a schema object several features read. For those, search the corpus by **feature vocabulary and
symbol name** rather than by path, the same way the older corpus below has to be searched.

Say in the report which of the three passes ran. A staleness review that ran only step 1 has looked
at a defined slice, and reporting it as "nothing was affected" is the failure this whole document
exists to prevent.

## Deleted and renamed files

A grep for new paths cannot find a case pointing at a path that no longer exists, and those are the
most certainly-stale cases of all:

```bash
git -C <worktree> diff <base>...HEAD --name-status --diff-filter=DR
```

For every deleted or renamed source, search the old path across `qa/`. A case whose `Code:` points
at a file that is gone is stale by definition — either the behaviour moved and the case needs
re-pointing, or it disappeared and the case needs deleting. Flag it either way; a human decides
which.

## Judging a candidate

A file appearing in both the diff and a `Code:` line means *possibly* affected, not stale. Read the
case and ask what the tester would actually experience now:

- **Does the described step still exist?** A renamed control, a moved menu item, a changed command
  — the step is now unfollowable.
- **Is the expected result still correct?** The step works and the outcome differs. This is the
  dangerous kind: the case fails, and the tester reports a defect against behaviour that was changed
  on purpose.
- **Did the precondition change?** A reset that no longer clears what it used to; seed data against
  a field a migration dropped.
- **Is it obsolete entirely?** The behaviour it protects no longer exists.

Most candidates will still hold. Leave those alone silently — a list of everything you looked at is
noise, and it buries the two entries that matter.

## How to mark

In the other task's document, add a line directly under the case heading and leave the case body
untouched:

```markdown
### T3. <existing case name>

> ⚠️ **Possibly stale after <task-id>.** Step 4 references a control that no longer exists —
> the choice moved into onboarding. Decide: rewrite the case for the new flow, or delete it.
```

State which task caused it, which specific step or expectation broke, and what the two options are.
A marker that only says "outdated" leaves the next reader with the same investigation you just did.

Mirror the same list in your own `manual.md`, with links. Otherwise the only trace of the edit is a
file in an unrelated folder, and a reviewer scanning the pull request by directory will miss it.

## Why not just fix it

Rewriting someone else's case is tempting and usually wrong. You are looking at it through the lens
of your own task, and you cannot see what its author was protecting — which production incident they
had hit, why the wording is oddly specific, what the case is really guarding.

A wrong rewrite is silent: coverage disappears while the document still looks healthy, and the next
regression run passes cheerfully. A marked case is loud and cheap to resolve. Prefer the loud
failure mode when working with incomplete information about someone else's intent.

The one exception is mechanical and unambiguous: a path in `Code:` that changed by pure rename with
identical behaviour. Re-point it and note it in the summary.

## Where else cases might live

Where the project keeps a second, older corpus of manual tests — engineer-facing, with its own id
scheme and no `Code:` annotations — it is read-only to this skill: review it for staleness,
cross-link it, and never write new documents into it or migrate cases between them. Corpora usually
coexist because they are split by **audience**, not by age, so neither supersedes the other.

Its cases have no annotations, so the cheap path above does not apply. Search it by source path,
symbol name, and feature vocabulary instead, starting from whatever registry it keeps. This is not
hypothetical diligence — in the project this skill was derived from, the first genuinely stale case
anyone found lived in the older corpus: it asserted that a message would *not* be sent, months after
the code had started sending one.
