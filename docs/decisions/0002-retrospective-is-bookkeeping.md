# 0002 — The retrospective ships under the bookkeeping exemption

## Status

Accepted

## Context

Phase 12 of a task run writes `tasks/<task>/retrospective.md` and has to get it onto the branch.
Phase 10 has already committed and pushed, so a file nobody commits stays in a worktree that is
about to be removed — and it is not merely lost. The `lessons` pass locates reports by path and
orders them by commit date, so an uncommitted retrospective is invisible to the only pass that
reads it. The loop this template is built around would have no input.

That makes the commit necessary. The question this record answers is what happens next, because
committing moves the head **after** phase 11 has converged.

`review-loop.md` already exempted commits "whose entire content records events that already
happened", naming two: the round record, and the validation file updated with the CI outcome. The
first version of this change asserted in the pipeline skills that the retrospective was a third.
Review round 2 of pull request #4 rejected that placement, correctly: the exemption is doctrine,
the skills are editions of it, and an edition that grants itself an exemption the doctrine does not
name is how the two editions start demanding different things.

The substantive objection underneath it was sharper. A retrospective is not purely a record: it
carries root-cause analysis and recommendations, and `review-loop.md` said the exemption ends where
a commit makes "a documentation claim that asserts rather than records".

## Decision

Extend the exemption in `review-loop.md` to name the retrospective, and restate its criterion as a
property rather than a list: a commit is exempt when it contains nothing **a later reader is obliged
to follow**.

A retrospective's recommendations propose edits to files it does not touch. Nothing in the
repository behaves differently because one was written, and every recommendation passes through the
`lessons` pass — including a human gate on anything reaching `docs/engineering/` — before it becomes
a rule anybody follows. That gate is where a proposal is answerable.

A commit mixing exempt and non-exempt content is not exempt. Split it, or take the round.

## Consequences

- **A retrospective's reasoning is never seen by the automated reviewer.** It is read by the
  `lessons` pass and by whoever opens the pull request, and that is the whole of its review. This is
  the price of the decision and it is stated in `review-loop.md` rather than left to be discovered.
- Phase 12 owns the commit and the push. The `retrospective` skill stays free of side effects, which
  keeps `checkpoints.md`'s rule that side effects belong to the main session intact.
- The exemption is now stated as a property, so the next commit that needs deciding is decided by
  reading it rather than by checking whether it appears on a list of three.
- CI still runs on the push. The exemption is from the reviewer, not from CI, and that was already
  true.

## Alternatives considered

**Write the retrospective before phase 11 converges**, so it is inside the reviewed head. Rejected:
a retrospective analyses the review rounds — how many there were, which findings recurred, which
were promoted. Written before they finish, it cannot report the thing most worth reporting.

**Push it and take one more review round.** Rejected because it does not converge. A finding on the
retrospective is fixed by editing the retrospective, which changes the head, which needs another
round, which produces another verdict that the retrospective would then be wrong not to mention.
This is the same regress the exemption was written to stop, arriving one step later.

**Have the `retrospective` skill commit and push itself.** Rejected: `checkpoints.md` puts commit
and push with the session that owns the phase, and a skill that a human invokes directly on a merged
task has no business pushing anything.

**Leave the file uncommitted and have `lessons` read worktrees.** Rejected: worktrees are removed at
the end of a run, and `lessons` would be reading a location that exists only while the run it
describes is still open.
