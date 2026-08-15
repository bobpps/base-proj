# 0000 — Template

Copy this file to `NNNN-short-slug.md` with the next free number. Numbers are never reused,
and a superseded decision is not deleted — it gains a `Superseded by` line and stays, because
the reasoning behind a decision that was later reversed is exactly what stops the reversal
being reversed again.

A decision belongs here when it answers a question that would otherwise be re-litigated: an
architecture boundary, a dependency choice, a security posture, a scope line. Not every
implementation detail — a decision nobody would ever ask about again is noise here.

The pipeline reads this directory in its first phase, so a recorded decision answers a gate
question before it is asked, and is what a reviewer finding gets rejected against.

---

## Status

Proposed | Accepted | Superseded by NNNN

## Context

What was true when this came up, and what forced a decision. Include the constraints that were
real at the time — a decision read later without its constraints looks arbitrary.

## Decision

What was decided, in the active voice, as a rule rather than a description.

## Consequences

What follows from it, including the parts that are inconvenient. A decision recorded with only
its upside reads as free, and the next person reverses it without seeing what they are buying.

Name the non-obvious failure modes explicitly. A one-line summary elsewhere will omit them, and
this section is what the summary points at.

## Alternatives considered

What else was on the table and why it lost. This is what stops the same alternative being
re-proposed every quarter.
