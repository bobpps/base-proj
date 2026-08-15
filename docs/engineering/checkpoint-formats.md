# Checkpoint formats

The shapes the checkpoints take. `checkpoints.md` decides **what** must be true at each point and
**where** each file is written; this file fixes **how** each one looks, so that two runs — and two
editions of the pipeline — produce comparable records.

Replace the placeholders, delete bullets that do not apply, and keep the evidence concrete. Never
mark work complete that was not run or verified.

**The on-disk record is English in full** — headings and prose alike. These four files are
committed with the change and ship in the pull request, which makes them repository documentation
and puts them under the language rule in `AGENTS.md`. Translate the version shown to the human in
conversation, not the version written to disk. Where a project declares documentation-language
exceptions, it declares them in `AGENTS.md` and this yields to them.

The headings never change in any case. A record whose headings were translated cannot be compared
with one whose were not, which is the whole reason these shapes are fixed.

## Requirements analysis

Published in phase 2, and lands in `plan.md`.

```md
## Requirements analysis

### Mode
Analysis-only | Small | Normal | Risky

### Worktree and branch
`<root>/<branch>` on `<branch>`, or the current worktree for Analysis-only.

### Task summary
...

### Explicit requirements
- ...

### Acceptance criteria
- ...

### Implicit requirements
Compatibility, error handling, testing, documentation — what the task needs but did not say.
- ...

### Out of scope
- ...

### Affected components
- ...

### Risks
- ...

### Open questions
- None.
```

## Requirements debate

```md
## Requirements debate

### Scope skeptic
...

### Architect
...

### Security reviewer
...

### Implementation reviewer
...

### Debate outcome
Where they agreed, and where they did not. A material disagreement is a gate question, not
something to resolve here.

### Human decision required?
Yes | No
```

## Human decision required

For an edition with no native question mechanism. End the turn and wait after printing it.

```md
## Human decision required

### Question 1 of N — <what it is about>

**How it is now.** <status quo, plain language first, file:line in parentheses>

**The fork.** <what is undecided, as observable behaviour>

**Why you.** <the axis the answer lives on>

**Cost of being wrong.** <reversibility>

Options:

1. <consequence first, mechanics second> — does not fix: <what it leaves>
2. ...
3. ...

Recommendation: <which, and why>

If anything is unclear, say "expand it"; if this is not yours to decide, say "you decide" and I
will take the recommendation.
```

For a Risky run with no open design question, the gate is an approval rather than a question:

```md
## Human approval required

This is a Risky run because it touches <what>.

The requirements, debate outcome, and plan above are ready for approval.

Recommendation: proceed with the plan as published, because <why>.

Approve, or describe the changes you want before implementation begins.
```

## Human gate decisions

Written into `plan.md` between the debate and the plan, by every edition — including the ones
whose gate mechanism leaves nothing on the page.

```md
## Human gate decisions

### <the question, as it was asked>

**Chosen:** <the option picked, in the human's words where they gave any>

**Rules out:** <the alternatives now closed, so a later phase does not reopen them>

### Approval

<what was approved, and whether it was the plan as published or with named changes>
| Not required — no gate was triggered.
```

Record the answer even when it matched the recommendation. A gate whose outcome is not written
down is afterwards indistinguishable from a gate that was skipped.

## Implementation plan

```md
## Implementation plan

### Files to inspect
- ...

### Files to change
- ...

### New files
- None.

### Data model changes
- None.

### Read and write paths

One subsection per path the change introduces or touches, named after the path. Where the change
introduces none, write `None — the change adds no read or write path.` and delete the rest.

#### `<path — the endpoint, job step, or query>`

- infra: <what happens when the store or the provider throws>
- absent: <what happens when the call succeeds and there is nothing there>
- malformed: <per field the code branches on, indexes into, or iterates>
- concurrency: <what a second, parallel attempt does — and what it returns>
- ownership: <how ownership is established, and what a failure to establish it does>

State each as a rule about behaviour, not as a description of the code to be written. One line
saying an axis does not apply is enough where it genuinely does not.

### Proving commands to run
- ...

### Manual smoke test
- ...

### Risks
- ...

### Rollback notes
- ...
```

## Implementation notes

Written to `implementation.md` at the end of phase 5.

```md
## Implementation notes

### Decisions
- <what was decided while implementing, and why the alternative was not taken>

### Deviations from the plan
- <what changed against the approved plan, and what made it necessary> | None.

### Safety defaults applied
- `<path>` — safety-default applied: <infra | absent | malformed | concurrency | ownership> → <choice>
- None applied — the change introduces no read or write path.

### Delegation topology
- <what was delegated, to how many agents, and why that shape>

### Left for the review passes
- <noticed while implementing, belongs to phase 7 rather than here> | None.
```

The path is the point of each safety-default line. Five unattributed lines satisfy the file and
prove nothing: they read identically whether every path was considered or only the first.

## Validation

Written to `validation.md` at the end of phase 6, and updated once CI has a verdict.

````md
## Validation

### Commands run

```text
<command>
```

### Results
- PASS: `<command>` — this machine | CI (`<run url>`)
- FAIL: `<command>` — this machine | CI (`<run url>`), and what it said
- Pre-existing failure: `<command>` — failing before this change, evidenced by <how>

### Manual checks
- ...

### Not run
- `<role>` — <why, and the reproducible manual alternative if one exists>
- None.
````

A file that still says "awaiting CI" after the run went green has lost the record that mattered
most. Update it, and let the update travel with the next push.

## Review finding

One block per finding.

```md
## Review finding

### Id
B1 | H1 | M1 | L1 | N1

### Reviewer
Correctness | Simplification | Security | Architecture | Scope | Test coverage | Failure axes
| Automated reviewer | Human reviewer

### Finding
...

### Evidence
A file and line, a failing command, a violated requirement, or a concrete execution path.

### Severity
blocking | high | medium | low | nit

### Suggested action
The smallest change that would resolve it.

### Requires human decision?
Yes | No
```

When a pass has nothing to report:

```md
### <Reviewer name>
No findings.
```

## Review finding adjudication

```md
## Review finding adjudication

### Finding
`<id>` — one-line restatement.

### Debate
#### Finding author
...
#### Implementation
...
#### Architecture / scope
...
#### Security
... | Not applicable.

### Decision
accepted | rejected | deferred | needs_human | document_only

### Reason
...

### Required action
...
```

## Pull request body

Use an accurate checklist. Leave an item unchecked when it did not pass or was not run.

```md
## Summary
...

## Linked task
Closes #...          <- only when a real issue exists and this should close it

## What changed
- ...

## Validation
| Check | Result |
| --- | --- |
| <role> | PASS — this machine \| CI (<run url>) \| not run, because ... |

## Review findings

### Accepted and fixed
- `<id>` ...

### Rejected
- `<id>` ... — why it does not apply.

### Deferred
- `<id>` ... — what ships without it, and why that is acceptable here.

### Documented tradeoffs
- `<id>` ... — what ships without it, and why that is acceptable here.

## Risks / notes
- ...

## Out of scope
- ...
```

Every deferred and documented finding appears here by id, with the accepted gap stated in words.
Recording it only in `review.md` does not count: nobody reads that file during review, and an item
nobody read was accepted by nobody. Use `None` under an empty category rather than inventing
content — an empty category says something.

## Review round

One block appended to `review.md` per round of phase 11. It reports what happened, including which
threads were resolved — and threads are resolved only after that round's fixes are pushed, so the
block travels with the **next** push.

```md
## Review round <n>

### Head commit
`<sha>` — the commit this round was decided against.

### Review requested
`<timestamp>` — the request that started this round, or `automatic` for the pass that opening the
pull request triggered.

### Outcome
clean | pending | degraded | findings

### Findings
- `<id>` `<signal>` `<path or check name>` — ...

### Adjudication
- `<id>` — accepted | rejected | deferred | needs_human | document_only, one line of reason.

### Threads resolved
- `<id>` `<thread>` — resolved after the fix was pushed.
- Left open: `<id>` — why, matching its adjudication.

### Loop state
Which findings recurred from an earlier round, by id or by cause, and whether the escalation rule
fired.

### Continue or stop
Another round | Stopped: reviewer clean | Stopped: every open finding settled as
rejected/deferred/document_only and listed in the pull-request body | Stopped: handed to the human
```

`<signal>` is whatever the source actually supplied — a priority badge, a failing check's name, a
review state, or `question` for a human comment. Do not invent a badge for a signal that carries
none: this field records where the finding came from, and the severity it was adjudicated to lives
in its id.

## Done

The final report of phase 12.

```md
## Done

### Implemented
- ...

### Validation
- ...

### Review outcome
- ...

### Review loop
<n> rounds. Ended clean | ended with settled findings left open, named in the pull-request body |
handed to the human. | Not applicable — no reviewer configured.

### Final CI
`<sha>` — the head after the closing bookkeeping commit, and how its run finished. This is the one
result `validation.md` does not carry. | Not applicable — nothing was pushed.

### Pull request
...

### Follow-up items
- None.

### Known limitations and out-of-scope work
- ...
```

If the run is blocked, do not use this format. State the unresolved gate, what has and has not
changed, and the precise decision needed.
