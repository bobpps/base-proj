# Subagent briefs

Read before phase 2 (the requirements debate) and again before phase 7 (the review fan-out).

A subagent starts with an empty context. It cannot see this conversation, the task that was read,
the decisions a human made at a gate, or the mode the run was classified as. Whatever is left out
of the brief, it will either invent or go looking for — and an agent that reconstructs the task
from scratch usually reconstructs a slightly different task, which produces a debate about
nothing.

Everything here is English on purpose. These are engineering instructions, not user-facing text,
and the specialist reviewers they compose with are written in English. Translate only when
reporting the outcome to the human.

## The shape of a brief

Five parts, every time:

1. **Role and single question.** One role, one verifiable deliverable. Bundling "assess the
   architecture and also check the tests" produces an agent that does neither well.
2. **The task, verbatim.** Paste the issue title and body, or the plain description. Do not
   summarize — a summary already carries the conclusions the main session reached, and the entire
   value of a separate agent is that it has not reached them.
3. **What to read.** Concrete paths: `README.md`, `AGENTS.md`, the applicable `CLAUDE.md`, every
   file in `docs/decisions/`, and the implementation files already identified. Recorded decisions
   matter most — an agent that has not read them will "discover" questions the human answered
   months ago.
4. **Boundaries.** Read-only for every role in this pipeline: investigate, report, change nothing.
   State it explicitly. An agent with edit tools that finds a bug will fix it unless told not to.
5. **Return format.** Say what the final message must contain. Its final text *is* the return
   value, not a message to a human, so ask for the fields that will be pasted into the checkpoint.

## Phase 2 — the requirements debate

Launch all four in a single message so they run concurrently, and brief each **without telling it
what the others think**. Independence is the entire value: four sections written by one head would
agree with each other, and their agreement would mean nothing. Real disagreement between
independently briefed agents is evidence that the requirements are ambiguous, which is exactly
what the phase 3 gate needs to know.

Use `general-purpose` unless a role obviously matches an installed specialist.

### Shared preamble

```
You are reviewing a proposed task in the <project> repository before any code is written.

Task under discussion:
<issue title and body verbatim, or the plain task description>

Repository context to read first:
- README.md — what the product is, its current scope, and what is out of scope
- AGENTS.md — architecture boundaries, invariants, validation expectations, risk classification
- CLAUDE.md — harness-specific working rules
- docs/engineering/ — the engineering doctrine this project is judged against
- every file in docs/decisions/ — recorded decisions with their reasoning
- <implementation files relevant to the task>

This is a read-only analysis. Do not edit, create, stage, or commit any file.

Ground every claim in a quotation from the task, a file path with a line reference, or a clearly
labeled inference. An unsupported assertion is worse than no assertion — it will be treated as
evidence at a human decision gate.
```

### The four role questions

Append exactly one to the preamble. Each ends by naming what to return, because the return is what
gets pasted into the checkpoint.

- **Scope skeptic** — "Is this task necessary now, and is the proposed size right for this
  project's current stage? Name anything that is polish rather than function, anything that could
  be cut without losing an acceptance criterion, and anything the task asks for that the scope in
  `README.md` and `AGENTS.md` excludes. Return: a verdict on necessity, a list of cuttable items
  with reasons, and any scope conflict found."

- **Architect** — "Which layer owns this change, per the architecture boundaries in `AGENTS.md`?
  Check it against those boundaries and against the invariants listed there. Return: the owning
  layer, any boundary this would cross, any coupling it would introduce, and whether an existing
  pattern in the codebase already solves it."

- **Security reviewer** — "What are the security and privacy consequences? Cover secrets and
  credential storage, authentication, authorization and access policies, database schema and
  migrations, storage policies, public error surfaces, and the handling of user data. Return: each
  concern with its severity, the evidence for it, and whether it needs a human decision before
  implementation."

- **Implementation reviewer** — "What is the smallest sound implementation? Name the files that
  would change, the approach, and the specific proving commands and manual smoke test that would
  demonstrate it works. Note which checks can run on a development machine and which need CI, per
  the validation line in `AGENTS.md`. Return: the approach, the file list, the validation plan,
  and the risks in it."

## Assembling the review input

`git diff HEAD` is not the change. Files created in phase 5 are untracked until phase 10 stages
them, and that command cannot see an untracked file at all — so a reviewer briefed with it alone
reviews every line the run **modified** and none of the lines it **wrote**. New code is exactly the
code most worth reviewing, and its absence looks like a clean diff rather than like a mistake.

Mark the additions first, then take the diff:

```sh
git -C <worktree> add --intent-to-add --all
git -C <worktree> diff HEAD
```

`--intent-to-add` records that the paths exist without staging their content, which is what brings
them into the diff. It stages nothing, so phase 10 still stages the approved paths explicitly and
the bulk-stage prohibition is untouched. It respects `.gitignore`, so build output stays out.

Do this **before** the first snapshot below, so both snapshots see the same tree — otherwise the
marking itself registers as a change and reads as a reviewer that edited.

## Phase 7 — the review fan-out

Run `scripts/review-snapshot.sh` before launching, launch the passes in one message, run it again
afterwards, and compare the `snapshot=` line. **Do not assemble the comparison by hand** — the
script is the procedure, and `scripts/review-snapshot.test.sh` proves it works.

That is not ceremony. This comparison was specified in prose twice and was wrong both times, in
ways that read as correct:

- Comparing `git status --porcelain` alone. A reviewer editing a file that was *already* modified
  leaves the porcelain line byte-identical — ` M path` before, ` M path` after — so the tree reads
  as untouched while its contents moved.
- Comparing a diff that omits untracked files. Most files created in phase 5 are untracked until
  phase 10 stages them, so the reviewers see none of their content and edits to them register
  nowhere.

Both are pinned as assertions now. The snapshot covers `HEAD` as well, because a reviewer that
commits takes its change out of both the status and the diff.

A moved snapshot means an agent exceeded its read-only role. Find what it changed before those
changes reach the commit: an unadjudicated reviewer fix is the one change nobody in this pipeline
ever decided to make.

**Coverage never depends on what is installed.** `checkpoints.md` requires six lenses on every
Normal and Risky run. A specialist that happens to be installed changes *who* runs a lens and how
well; it never changes *whether* one runs. Where the specialist is absent, brief the lens by hand
from the questions below and say in the checkpoint which passes ran with a specialist and which
were briefed — the two are not equally strong, and a reader deserves to know which they are
looking at.

This matters most in a fresh checkout of a project built from the template, where nothing is
installed yet and every pass is hand-briefed. That is a working configuration, not a degraded one.

**Every pass in the table below has a hand-briefed counterpart further down, including the
conditional error-handling one.** When a pass is added to either list, it is added to both in the
same edit — the first version of this file gave three lenses a fallback and left the fourth
without one, which was found only because a reviewer read both lists against each other.

### Passes with an installed specialist

| Pass | Agent | Notes |
| --- | --- | --- |
| Correctness | `pr-review-toolkit:code-reviewer` | Tell it which diff to focus on; by default it reviews unstaged changes, which is wrong here because the work may already be staged. |
| Error handling | `pr-review-toolkit:silent-failure-hunter` | Add to the correctness pass whenever the diff touches catch blocks, fallbacks, retries, or job error states. |
| Test coverage | `pr-review-toolkit:pr-test-analyzer` | Give it the diff and the proving commands from `AGENTS.md`. |
| Type design | `pr-review-toolkit:type-design-analyzer` | Optional. Worth running when the diff introduces domain types or contract shapes shared across package boundaries. |

**A confidence score is not a severity.** Where a reviewer reports how sure it is, keep that
separate and assign severity from the definitions in `checkpoints.md`. Confidence measures
evidentiary certainty; severity measures impact, and the two move independently — a highly
confident typo is still a nit, and an uncertain authorization bypass is still potentially
blocking. Confidence governs what happens *before* the finding is published: a low-confidence one
gets verified rather than demoted, and whatever survives verification takes the severity its
impact earns.

**Not used: any reviewer that rewrites code.** A simplifier that edits rather than reports applies
changes nobody adjudicated, and in this pipeline no change lands before its finding has been
accepted.

For a Risky run, use the `security-review` skill for the security pass where it is installed: it
reviews the pending changes on the branch, which is exactly the scope wanted, and it is maintained
outside this pipeline. Where it is not installed, brief the security lens by hand like any other —
a Risky run without a security pass is not a Risky run.

### Passes briefed by hand

```
You are reviewing a completed change in the <project> repository before a pull request opens.

Task the change implements:
<issue title and body verbatim, or the plain task description>

Scope of the change:
- Branch: <branch>
- Worktree: <path>
- Review this diff: <the command from "Assembling the review input" below, verbatim>

Read for context:
- AGENTS.md — architecture boundaries, invariants, validation expectations
- CLAUDE.md — harness working rules
- docs/engineering/failure-axes.md — the five axes and their safe defaults
- every file in docs/decisions/ — recorded decisions and their reasoning

This is a read-only review. Do not edit, create, stage, or commit any file.

Report only findings you can support with a file and line, a failing command, a violated
requirement from the task, or a concrete execution path. If you find nothing, say "No findings" —
that is a valid and useful result. Do not pad the report to look thorough.

For each finding return: what is wrong, the evidence, the severity
(blocking | high | medium | low | nit), and the smallest action that would resolve it.

Your specific question:
<one of the questions below>
```

- **Simplification** — "Is there a materially simpler implementation of the same behaviour, using
  something that already exists in this codebase? Ignore stylistic preference and speculative
  abstraction."
- **Architecture** — "Does this change respect the architecture boundaries and the invariants in
  `AGENTS.md`? Check each invariant listed there against the diff, and say which ones the diff
  does not touch rather than skipping them silently."
- **Scope** — "Does this change stay inside what the task authorized? Flag anything belonging to
  the out-of-scope list in `README.md` and `AGENTS.md`, and any unrelated refactoring or cleanup
  that arrived alongside the task."
- **Error handling**, where no specialist is installed and the diff touches catch blocks,
  fallbacks, retries, or job error states — "Where does this change swallow a failure? For every
  caught exception, default value, fallback branch, and empty-result path the diff introduces or
  touches, say what the caller can no longer distinguish. Check in particular whether a failure to
  act is reported as an outcome of acting, and whether 'there is nothing there' stays separable
  from 'we could not find out'. Cross-reference the five axes in
  `docs/engineering/failure-axes.md`."
- **Correctness**, where no specialist is installed — "Does this change do what the task asked,
  and does it do it correctly? Walk the execution paths the diff introduces or touches, including
  the ones no test exercises. Check every branch condition, boundary comparison, loop termination,
  and early return against what the surrounding code assumes. Report a defect only where you can
  name the input or state that produces the wrong result."
- **Test coverage**, where no specialist is installed — "Which behaviour introduced or changed by
  this diff is not covered by a test, and which of those gaps matter? Check that a bug fix carries
  a test that fails without it, that new branches are exercised, and that the assertions pin the
  invariant rather than an incidental value. Name the tests worth adding, in priority order, and
  say which gaps are acceptable and why."
- **Security**, where `security-review` is not used — "Does this change leak or
  weaken anything? Check for hardcoded secrets, a privileged credential reachable from code that
  should not hold one, cross-user data exposure, missing or bypassed access control, publicly
  reachable private data, internal errors surfacing through public error responses, and
  idempotency gaps that would let a retry duplicate or corrupt data."

### The failure-axes pass

Brief one agent with `docs/engineering/failure-axes.md` and the diff, asking a single question:
**for each read or write path this diff introduces or touches, does the code's behaviour on the
five axes match the rule the plan stated?** A path whose behaviour contradicts its own plan is a
finding; a path the plan never mentioned is a bigger one, because it means the plan's coverage was
incomplete and whatever the code does there is accidental rather than chosen.

## Turning returns into checkpoints

- **Deduplicate before publishing.** Independent reviewers frequently report one problem four
  times, and four finding blocks for one defect inflate the apparent severity of the change.
- **Keep the reviewer's evidence, not its prose.** A finding citing no file, line, command, or
  execution path is a hypothesis about a hypothesis. Check it before publishing, and drop it if it
  does not survive.
- **A returned `null` means the agent died or was skipped, not that it found nothing.** Say which
  passes did not complete rather than reporting a clean review that was never received.
- **Never paste a subagent's judgement into a gate question as established fact.** The gate exists
  precisely because the question is open.
