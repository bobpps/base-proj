---
name: docs-audit
description: >
  Audits the project's documentation against the repository it describes: extracts every verifiable
  claim — file paths, symbol names, commands, environment variables, versions, schema objects —
  checks each against the authority that actually holds the fact, and applies surgical fixes to the
  claims that have gone stale. Use when documentation may have drifted from the code, after a
  refactor or a rename, before onboarding someone, or when a human says "проверь документацию",
  "документация устарела", "audit the docs", "are the docs still true". Invoked only by explicit
  human command. Reports every file it checked, including the ones that were already correct.
user_invocable: true
disable-model-invocation: true
argument-hint: "[path-or-glob]"
---

# docs-audit

Documentation makes claims about a repository. A claim is either checkable against something that
holds the fact, or it is prose. This skill finds the checkable ones, checks them, and repairs what
has gone stale — nothing else.

## The distinction the whole skill turns on

A document that **describes** gets fixed. A document that **prescribes** gets defended.

`README.md` naming the command that builds the project is a description: if the manifest names a
different one, the document is wrong and the fix is to update it. `AGENTS.md` saying storage access
never happens outside the data layer is a rule: if the code disagrees, the document is *right* and
the code is in violation.

Editing a rule to match the code that broke it is the worst outcome this skill can produce. It
looks like an audit passing, it removes the only record that the rule ever existed, and the
violation is now documented as the design. So when a mismatch touches an invariant, a boundary, a
security or access rule, or a scope limit — **report it as a finding about the code and change
nothing.** A human decides whether the rule moved or the code broke it.

When it is genuinely unclear which side is authoritative, that ambiguity is the finding. Say so.

## Scope

**Derive the document set; never carry a list of filenames in this file.** Any list here rots, and
a rotted list is worse than no list because it reads as complete:

```bash
git ls-files '*.md' | grep -v '^docs/engineering/\|^docs/decisions/\|^tasks/\|^\.agents/'
```

Then narrow by what the human asked for, and by what `AGENTS.md`'s **Documentation** section says
each file is for — a file's purpose decides which of its claims are even checkable.

Four paths are deliberately out of scope, each for a different reason:

| Excluded | Why |
| --- | --- |
| `docs/engineering/` | Doctrine. It describes how work is proved, not what this repository contains — there is nothing in it for the code to drift from, and it changes through the retrospective loop rather than through an audit. |
| `docs/decisions/` | Historical records. A record describing a decision that has since been reversed is **correct**: it says what was decided then. The repair for a changed decision is a new record superseding it, not an edit to the old one. |
| `tasks/` | Run artifacts. Each was true at its checkpoint, and `evidence.md` depends on that staying so. |
| `.agents/` | Generated. Editing it produces one of two outcomes and neither is a repair: the drift check fails, or the next regeneration silently reverts the fix. |

Everything else is in scope, `AGENTS.md` and `README.md` included. `AGENTS.md` in particular
carries the proving commands, the branch conventions, and the worktree root — all of them
verifiable, and all of them load-bearing for every future run.

**A generated path given as a target is redirected, not refused.** The stale claim is real; it just
lives in the source. Audit and repair the source, say in the report that the target was redirected
and to where, then propagate as `writing-skills.md` requires: copy that one skill's directory across
by hand rather than regenerating the whole tree.

**Find the source by comparing, not by guessing which one it should be.** The generated copy is
byte-identical to whichever source the generator selected, so the copy answers the question
directly:

```sh
for src in .codex/skills/<name> .claude/skills/<name>; do
  [ -d "$src" ] && diff -rq "$src" ".agents/skills/<name>" >/dev/null && echo "$src"
done
```

Do not reason it out from directory existence. The generator prefers `.codex`, skips a skill whose
frontmatter carries `superseded-by:`, and skips anything in its `IGNORE` map — so a retired `.codex`
edition sitting beside a live `.claude` one exists and is *not* the source, and copying the audit's
repair back from there would replace the active edition with the retired one and turn the drift
check red. Every restatement of those rules in a second file has diverged from the generator the
moment somebody used one of them; the comparison above cannot.

Two answers are not a redirect and are reported as they are:

- **No source matches** — the generated tree is already stale. Say so and stop; regenerating it is
  a separate act with its own reasons, and auditing a copy nobody has reconciled repairs the wrong
  text.
- **The name appears in `.agents/skills/.vendored`** — it came from outside this repository
  entirely, so there is no source here to repair. Name the stale claim in the report and leave it.

That propagation is not optional bookkeeping. `scripts/skills.test.sh` compares the generated tree
against its sources, so a repaired skill whose copy was left behind turns a green audit into a red
build.

## Extract the claims

Read each file in full, then list what it asserts about the repository. The kinds worth extracting,
because each has an authority that can settle it:

| Claim | Authority that holds the fact |
| --- | --- |
| a file or directory path | the filesystem |
| a class, function, type, or module name | the code where the document says it lives |
| a command, script, or task name | the manifest or the script file — not another document |
| an environment variable | the code that **reads** it, not the example env file |
| a version or runtime pin | the pin file the toolchain actually reads |
| a schema object — table, column, index, policy, trigger | the live database where one is reachable, otherwise the migrations |
| a port, hostname, or service name | the deployment or container configuration |
| a documented workflow or setup sequence | each step's own authority, step by step |

**Read the fact out of the authority, never out of a neighbouring document.** Two documents that
agree with each other and disagree with the code are two stale documents, and checking one against
the other is how an audit reports a clean pass over a repository it never looked at.

## Configuration states intent; observation states fact

`evidence.md`'s rule applies directly here, and it decides which authority to use when there are
two. A migration records what was asked for; the database records what the schema now is. A
workflow file records what CI was meant to run; a run's log records what ran.

- Where the observing authority is reachable, use it, and say in the report that you did.
- Where it is not — no database, no credentials, no network — use the configuring authority, and
  **say which one you used**. A claim checked against intent is verified more weakly than one
  checked against fact, and a report that hides the difference is claiming more than it saw.
- Where a claim has no reachable authority at all, record it as **not verified** with the reason.
  `evidence.md` has four outcomes and the one that gets silently dropped is always this one.

Where the target schema is what the documentation is supposed to describe, reconcile the two
directions before comparing: migrations that exist locally and have not been applied are part of
what the document should say, and objects in the database with no migration behind them are a
finding in their own right.

## Fix, surgically

- **Edit only what is provably wrong.** Never regenerate a file. A regenerated document loses the
  explanations, caveats, and hard-won notes that are the only reason anyone reads it, and the loss
  is invisible in review because the result looks tidy.
- **Preserve the document's voice** — its language, its formatting conventions, its section order,
  its level of detail. A repaired paragraph that reads like a different author is a repair the next
  reader will distrust.
- **Verify before editing, never after.** "This looks outdated" is a hypothesis. Read the authority
  and confirm it, or leave the text alone and list it as unverified.
- **A rule that the code violates is not edited.** See the top of this file.
- **A claim that is merely incomplete is not a defect.** Documentation summarises on purpose.

Do not commit. This project commits on an explicit request.

## Running it

One file is one unit of work, and files are independent — so fan out with one agent per document
once there are more than a handful, briefed per `subagent-briefs.md`. Give each agent the file, the
authorities it may consult, the extraction table above, and the rule about prescriptive documents.
Keep anything needing a live connection in the session that holds the connection.

Two things stay in the main session regardless: the decision about what a mismatch means when a
rule is involved, and the final report.

## Report

Every file that was checked appears, including the ones that were already correct. A file missing
from the report is indistinguishable from a file nobody opened, and that is precisely the failure
an audit exists to rule out.

```markdown
## Documentation audit — <date>

| File | Verdict | What changed |
| --- | --- | --- |
| `README.md` | updated | build command, 2 moved paths |
| `AGENTS.md` | current | — |
| `docs/architecture.md` | findings only | 1 boundary violation reported, no edit |

### Findings about the code
<Mismatches where the document was right. One entry each: the rule, where it is written, the
code that disagrees, and what the human has to decide.>

### Not verified
<Every claim with no reachable authority, and why — no database connection, no credentials,
an external service. Never omitted.>

### Verified against configuration rather than observation
<Claims where only the intent was reachable. Say which authority answered.>
```

Keep the verdicts to a fixed small set — `current`, `updated`, `findings only`, `not verified` —
so a run can be compared with the one before it.

## Boundaries

Never edits code, only documentation. Never edits `docs/engineering/`, `docs/decisions/`, `tasks/`,
or anything under `.agents/` — a repair there is either reverted by the next regeneration or shows
up as drift. Never applies a migration, runs a mutation, or writes to any external system — every
authority here is read. Never commits or pushes. Never resolves a rule-versus-code mismatch on the
human's behalf.
