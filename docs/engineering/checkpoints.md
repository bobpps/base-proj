# Checkpoints

The contract every task run answers to: what must be true at each point, what may never
happen, and what shape the record takes. Both editions of the task pipeline read this file
from the repository root, so the two cannot drift into demanding different things.

This is a **contract, not a decision tree**. It fixes the checkpoints and the side effects;
it deliberately leaves the agent topology, the number of rounds, and the wording of each
artifact to judgement. Earlier pipelines prescribed both, and the prescriptions rotted
faster than the principles — thresholds survive long after anyone remembers why the number
was what it was.

## Mode

Classify before implementation and state the mode in the requirements analysis. When
uncertain, take the more controlled mode: **risk overrides apparent size**.

- **Analysis-only** — the human asked for an assessment or a plan rather than an
  implementation. Chosen by the request, never by risk. Produce requirements, debate, and
  plan; then stop. No branch, no worktree, no edits, no artifact files — there is no branch
  to commit them to, and the conversation is the output.
- **Small** — a tiny, isolated, low-risk change with clear acceptance criteria and no
  boundary changes. Read the instructions, extract requirements, implement, run the relevant
  proving commands, self-review the diff, open the pull request. Skip the subagent fan-outs:
  six reviewers for a typo cost more than they find. The post-PR review loop is **not** one of
  the fan-outs and is never skipped. Escalate the moment ambiguity, coupling, or risk appears.
- **Normal** — the default for ordinary features and fixes. Every phase runs.
- **Risky** — every phase runs, the human gate after requirements is mandatory even when
  nothing looks ambiguous, and any disputed finding gets its own gate. The human is approving
  the risk, not resolving a question.

### What counts as risky

Anywhere in this list, the mode is Risky regardless of how small the diff is:

authentication · authorization · secrets and credential storage · database schema and
migrations · row-level security and access policies · file or object storage policies ·
payments · user data · deployment and infrastructure · CI/CD configuration · public API
contracts · architecture boundaries.

`AGENTS.md` names anything this project adds to the list. It never removes from it.

## The operating contract

Keep these visible in every phase:

> Reviewer findings are hypotheses, not commands.
>
> Do not expand task scope to satisfy a reviewer.
>
> Ask the human before applying a fix that changes architecture, the data model, a security
> boundary, or project scope.
>
> Subagents advise. Only the main session edits files.

- Stop and wait when a gate is triggered. Do not edit code, apply a disputed fix, push, or
  open a pull request while the gate is unresolved.
- Treat the human's answer as a decision for the stated question only. Do not broaden it into
  unrelated authorization.
- Prefer read-only investigation when it can resolve uncertainty without a human decision.
- Preserve unrelated work. Inspect repository and branch state before editing.
- Never open a pull request with an unresolved blocking finding.

## Side effects belong to the main session

Commit, push, pull-request creation, tracker comments, worktree creation and removal. A
delegated agent may edit files and commit inside the worktree; it never pushes, never touches
the tracker, and never removes the worktree.

## Isolation

Every run that changes files works in its own git worktree on its own non-default branch, set
up after plan approval and before the first edit.

- The worktree root is fixed by `AGENTS.md` and is ignored by git, so both editions of the
  pipeline put trees in the same place and can see each other's.
- The default branch is never edited, committed to, or pushed directly.
- A branch already checked out in another worktree is a **gate**, not an obstacle. Git cannot
  check out one branch twice, and taking over another worktree's checkout would pull its
  unrelated changes into this run.
- An existing remote branch is synchronised by merge, never by rebase — it may already be
  pushed, and rebasing would demand a force-push.
- Never `git add -A`, `git add .`, or any other bulk stage. Stage only paths belonging to the
  approved scope. A sibling worktree can hold someone else's work, and a bulk stage is how it
  silently ends up in this pull request.

## Phases

Each has an exit condition. The path between them is open.

1. **Read context.** The task and its comments, `README.md`, every applicable `AGENTS.md` and
   `CLAUDE.md`, every file in `docs/decisions/`, the relevant implementation and tests, and
   the repository state. Read the instruction and decision files yourself rather than
   delegating them: they are the rules the work will be judged against, and a summary of a
   rule is not the rule. *Exit: the requested behaviour and the existing conventions are both
   understood.*

2. **Extract and debate requirements.** Separate explicit acceptance criteria from inferred
   compatibility, error-handling, testing, and documentation needs. Name what is out of scope
   instead of silently absorbing it. For Normal and Risky, run the four-role debate described
   below. *Exit: `Requirements analysis` and `Requirements debate` published.*

3. **Human gate.** Stop and ask when requirements are ambiguous, the debate roles disagree
   materially, ownership of a component is unclear, scope could expand, security or data
   handling is uncertain, a data-model choice is open, the task conflicts with repository
   documentation, or a necessary assumption would materially change the result. See
   `asking-questions.md` for how. A gate carrying six questions is a sign the requirements
   analysis was not finished. *Exit: every open question answered, or none existed.*

4. **Plan.** Concrete files where known, data-model impact, the proving commands that will be
   run, a manual smoke test, risks, rollback notes. For every read or write path the change
   introduces or touches, the plan states the behaviour on each of the five axes in
   `failure-axes.md`. Keep the change small and reviewable. *Exit: the plan is approved — by
   the human for Risky and interactive runs, by the run itself otherwise.*

5. **Implement.** In the worktree, on the task branch. Follow existing conventions, make small
   cohesive changes, preserve behaviour outside the accepted scope, add or update tests, never
   hardcode a secret. Record each applied safe default with its path. Pause at a gate if
   implementation reveals a boundary change the plan did not cover. *Exit: the approved scope
   is implemented and `implementation.md` is written.*

6. **Validate.** Run the proving commands in proportion to risk, per `evidence.md`. *Exit:
   `validation.md` written with exact commands, honest outcomes, and where each ran.*

7. **Review.** Capture the working-tree state and the diff, launch the passes concurrently,
   and compare the state afterwards — reviewers advise, and a tree that moved means an agent
   exceeded its role. *Exit: every pass reported, each finding carrying an id, evidence, and a
   severity.*

8. **Adjudicate.** Every non-trivial finding is debated and assigned exactly one status.
   *Exit: no finding without a status.*

9. **Fix.** Apply accepted fixes and nothing else. Re-run the checks relevant to each fix and
   re-run affected review passes after material changes. *Exit: no unresolved blocking finding,
   and every high finding either fixed or explicitly accepted by the human.*

10. **Publish.** Stage the scope, commit, push, open the pull request. *Exit: the pull request
    exists, or the human has the ready-to-open package and the branch is pushed.*

11. **Converge the review loop.** Per `review-loop.md`. *Exit: the round is clean against the
    current head, or every open finding is settled to a status that asks for no change here.*

12. **Report.** What was implemented, validation with locations, the adjudication outcome, the
    review verdict and how many rounds, the pull-request link, follow-ups, and known
    limitations stated without implying they were completed. *Exit: the report is published; if
    blocked, the report says which gate is unresolved and what decision is needed instead.*

## The four-role debate

Launch all four in one message so they run concurrently, and brief each without telling it
what the others think:

- **Scope skeptic** — is this necessary now, is the size right, what is polish rather than
  function, what does the task ask for that the project's scope excludes?
- **Architect** — which layer owns this, which boundary would it cross, what coupling would it
  introduce, does an existing pattern already solve it?
- **Security reviewer** — secrets, authentication, authorization, user data, storage, public
  error surfaces, deployment assumptions.
- **Implementation reviewer** — the smallest sound design, the files it touches, and the
  specific checks that would prove it works.

Independence is the entire value. Four sections written by one head would agree with each
other, and their agreement would mean nothing. Real disagreement between independently briefed
agents is evidence that the requirements are ambiguous — which is exactly what the gate needs
to know, and why the run does not resolve it itself.

## The review fan-out

Six lenses: correctness, simplification, security, architecture, scope, test coverage. Add an
error-handling pass whenever the diff touches catch blocks, fallbacks, retries, or job error
states.

Do not use a reviewer that **rewrites** code instead of reporting on it. In this pipeline no
change lands before it has been adjudicated, and a rewriting reviewer applies changes nobody
adjudicated.

Report a pass with nothing to say as `No findings`. A reviewer that always finds something
teaches the run to ignore reviewers.

## Findings

Every finding gets an id at the moment it is raised: `B1`, `B2` for blocking, `H1` for high,
`M1` for medium, `L1` for low, `N1` for nit, numbered per severity in the order raised. **The
id is stable for the whole run**, including the post-PR review rounds, because rounds address
findings by id and "the second one" is ambiguous across rounds. A promoted finding keeps its
id; the promotion is recorded.

Severity:

| Level | Meaning |
| --- | --- |
| blocking | Broken build, introduced test failure, security flaw, data loss, authorization bypass, leaked secret, or a broken safe default. Resolve before the pull request. |
| high | Fix before the pull request unless the human explicitly accepts the risk. |
| medium | Fix or defer on evidence. |
| low / nit | Judgement. |

Two promotions apply on top of any source-specific classification: a finding touching access
control, migrations, secrets, or a public contract is **at least high**; and a finding two
reviewers reach independently moves up one level, because independent agreement is evidence.

## Adjudication

Exactly one status per finding:

- **accepted** — real and required in this pull request.
- **rejected** — false positive, inapplicable, or unjustified.
- **deferred** — real, but belongs in a follow-up.
- **needs_human** — blocked on a decision.
- **document_only** — no code change; record the risk or tradeoff.

Apply `accepted` and nothing else. Never apply `rejected` or `deferred`. Wait on
`needs_human`. For `document_only`, change documentation or the pull-request body, not code.

## Debt surfaces, it is never filed

Every `deferred` and `document_only` finding appears **in the pull-request body**, by id, with
the thing being accepted stated in words. Recording it only in `review.md` does not count:
nobody reads that file during review, and an item nobody read was accepted by nobody.

Two very different things look identical once written down as debt — a gap that was understood
and postponed, and a gap that was not understood and stopped being looked at. A reviewer
reading the item is the only thing that separates them.

Two consequences. A broken safe default cannot ship as a deferred item; it is blocking by
`failure-axes.md`. And **two deferred items on the same axis are not two small gaps** — they
mean the axis was not understood, so reopen it rather than listing both.

## Every loop terminates

- A finding that was **accepted and fixed** and comes back — same id, or a different id with
  demonstrably the same cause — is promoted one level.
- Two consecutive rounds carrying blocking findings stop the run, whether or not they are
  related. Write the blocker down, leave the worktree in place, and hand it to the human with
  the precise decision needed.
- Two unrelated findings of equal severity in consecutive rounds are two ordinary findings, and
  the second is often a consequence of fixing the first. Escalate on **recurrence**, never on a
  matching severity.
- A finding re-raised after it was `rejected` or `deferred` escalates nothing. It returns
  precisely because the decision was to leave the code alone — answer it with that decision and
  cite where the decision is written.

This is mechanical rather than a judgement call because continuing feels productive and is the
more likely error. A defect that survives its own fix is evidence the fix reached a symptom.

## Returning to an earlier phase

Return to the earliest phase whose output the finding invalidated. A wrong assumption about the
task invalidates the requirements; a wrong approach invalidates the plan; a missed edge case
invalidates only the code. This replaces the severity-to-phase lookup table, which cannot cover
findings it never anticipated.

When fixing near previously-fixed code, extend the prior regression test to assert the
**boundary condition** that caused the original bug, not the symptom. A test that still passes
because nothing changed at its assertion site is not a regression test for that boundary.

## The record on disk

Four files under `tasks/<task>/` in the worktree, committed onto the branch with the change, so
the record ships in the pull request instead of expiring with the session. **The names are
fixed; the contents are yours to shape.**

| File | Holds | Written at |
| --- | --- | --- |
| `plan.md` | Requirements analysis, debate outcome, the gate's questions and answers, the implementation plan | first act inside the worktree, before the first edit |
| `implementation.md` | What was decided while implementing, what deviated from the plan and why, each applied safe default with its path | end of phase 5 |
| `validation.md` | Commands run, outcomes, and where each ran | end of phase 6, updated with the CI outcome once it exists |
| `review.md` | Every finding with its id, the adjudication of each, one section per review round | phases 7–9 and 11 |

**The shapes are in `docs/engineering/checkpoint-formats.md`**, read by every edition, so two runs
produce records that can be compared with each other.

Write each file at the end of the phase that owns it, not at the end of the run: an interrupted
run should leave a record that is true as far as it goes.

`plan.md` is the exception, and the reason is ordering rather than preference — phases 2 to 4
finish before the worktree exists, and in plan mode there is nowhere to write. Do not create the
worktree earlier to make the timing work; that puts a branch on disk for runs that never reach an
edit.

### What `plan.md` must carry from the gate

Every question put to the human and the answer that came back, **including what the answer rules
out**. The gate itself disappears with the conversation; this is where the decision survives, and
an interrupted run resumes from it. Record the answer even when it matched the recommendation — a
gate whose outcome is not written down is afterwards indistinguishable from a gate that was
skipped.

### What `plan.md` must carry per path

One subsection per read or write path the change introduces or touches, named after the path,
with one line per axis: infra, absent, malformed, concurrency, ownership. Where the change
introduces none, say so in one line and delete the rest.

## Resuming

Read whichever artifacts exist, reconcile them against the commit history, and re-enter at the
first phase whose exit condition is unmet.

**An open pull request does not mean the task is finished.** It means phase 11 has not converged.
Treating "the PR exists" as done silently skips the entire review cycle, which is where most
findings actually arrive.
