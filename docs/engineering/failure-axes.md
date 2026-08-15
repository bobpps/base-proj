# Failure axes and safe defaults

Read while writing the plan of a task run, and again while briefing the review passes.

This file exists for one class of defect: the kind that survives ordinary planning and
ordinary review because the code **looks correct**. The happy path works, the tests pass,
and nothing draws attention to the path nobody thought about. Race conditions, a record
attributed to the wrong owner, a malformed provider response quietly coerced into a
plausible one — none of them announce themselves as an unknown while the code is being
written. They cannot be caught by asking "did I miss anything?", because the honest answer
at that moment is no.

## The obligation

For every read or write path the task introduces or touches, the plan states what happens
on each of the five axes below. Where an axis genuinely does not apply, one line saying so
is enough. Where it applies, the plan states the resulting behaviour **as a rule** — "a
provider timeout leaves the job claimable and increments the attempt counter", not "handle
errors appropriately".

The test of whether this was done rather than merely named:

> Could a reviewer read the plan and predict what the code does when the query returns
> nothing, when two attempts race, and when the provider throws?

If not, the axes were listed, not worked.

Write the rule even when a mechanism already prevents the failure. A mechanism protects one
line of code; a stated rule protects every path added to that file afterwards.

## The five axes

1. **Infra** — the store, the queue, or the provider throws or times out.
2. **Absent** — the call succeeds and there is nothing there: no row, no content, no result.
3. **Malformed** — the data arrives in a shape the code did not expect.
4. **Concurrency** — a second attempt runs in parallel with the first.
5. **Ownership** — entities that must belong to the same owner do not.

The bug is almost never "we did not handle errors". It is **collapsing two axes into one
signal**, so that no caller downstream can tell them apart. A step that returns an empty
result both when the provider failed and when there was genuinely nothing to return has
destroyed the only information the caller needed: the first case must be retried, the second
must be recorded as a terminal outcome and never retried. Both then get the same treatment,
and which treatment they get is decided by whichever case the author happened to be
thinking about.

Watch for a third state hiding inside "malformed": a field that is explicitly null on the
wire. For external payloads null is frequently a documented, legitimate value meaning "this
section is empty" — neither absent nor malformed. A rule of the form "not a list → reject"
refuses valid responses; a rule of the form "anything falsy → empty list" swallows real
corruption. Decide which of the three null means for that field, and write it down.

State the malformed rule **per field**, not per payload. A guard that rejects a response
which is not an object does not say what happens to a numeric field that arrives as a string
inside an object that passed. Write the rule for each field the code branches on, indexes
into, or iterates.

## The safe defaults

These five bind **every read or write path the task introduces or modifies**, whether or not
anything about the path felt uncertain. They are not tie-breakers for questions that came
up; the failure they prevent does not arrive as a question.

| Axis | The default — this holds on every path |
| --- | --- |
| Infra | A failure to act is never reported as an outcome of acting. |
| Absent | "There is nothing there" stays distinguishable from "we could not find out". |
| Malformed | A value that is not what it claims to be never becomes domain data. Keeping the payload verbatim as private evidence is the opposite of admitting it, and is encouraged. |
| Concurrency | Work attempted twice leaves the effects of having been done once. What the second attempt *returns* is the operation's business — the first attempt's result, a wait, or nothing at all — and only the absence of a second set of effects is universal. |
| Ownership | Data is touched only after ownership was established, and a failure to establish it is refused with a distinct, logged reason. |

**Each says what must be true, and none of them says how.** That separation is the point of
this table, and it was learned expensively: earlier versions of this rule stated the
*mechanism*, and every route that legitimately needed a different mechanism then looked like
a violation. A rule that turns a correct route into a finding teaches people to argue with
the rule instead of with the code.

Record a deliberate application in `implementation.md` as:

```
<path> — safety-default applied: <axis> → <choice>
```

The path is the point of the line. Five unattributed lines satisfy the file and prove
nothing: they read the same whether every path was considered or only the first one.

## Safety inverts the usual default

"Pick the narrowest reversible change" is the right instinct for the scope of a feature and
the wrong one for an invariant. The narrowest change is the one that skips the ownership
check. The most reversible change is the one that coerces the malformed input and moves on.

Telling the two apart:

- *"Which library should we use for this?"* — feature scope. Narrowest reversible wins.
- *"Should the cleanup be scoped to what this attempt wrote?"* — invariant. Safe default wins.

Misfiling the second as the first — concluding "no ownership check, that is the smallest
change" — is the exact antipattern this section exists to prevent.

**A path that breaks one of the five defaults is a blocking finding.** Not forbidden — a real
reason to give one up exists sometimes — but it has to be argued and adjudicated rather than
assumed, and it cannot be disposed of as an accepted low-severity item. That route is closed
deliberately: "minor, accepted" is exactly how an unargued rejection would otherwise reach
the default branch.

The finding is always that the **default** is broken, never that a particular mechanism was
not used. A path that meets the default by other means meets it.

## Further axes worth working

The five above bind every path. The six below apply when the task's shape calls for them, and
each one is here because it produced a real defect that ordinary review passed.

**Arity at external boundaries.** Every new or touched call site — a store query, a provider
call, a queue handler, an endpoint, anything taking a caller-supplied identifier — has
behaviour on inputs nobody intended: empty, blank, malformed, mismatched, arriving twice in
parallel. Pin what happens for each, and pin the cardinality assumption: does this boundary
assume exactly one result, at least one, at most one? Cardinality assumptions are invisible
until the day they are violated. "It will not be called with that" is an assumption about
callers you do not control.

**Precedence when one identifier arrives from two sources.** Ambient context and an explicit
parameter can both carry the same identifier, and deciding that one always wins is easy while
deciding correctly is not. Do not resolve it by which source you trust more. Resolve it by
**expressiveness**: what does the caller become unable to say? Ambient-wins means "act on
target B" cannot be expressed at all — every request is silently rewritten to whatever is
current, and no validation catches it, because the substituted identifier is real, correctly
owned, and passes every check. That is worse than a rejected request. The rule that survives:
the explicit identifier wins when present, validated and authorized like any untrusted input;
the ambient one is the fallback when it is absent; and a present-but-malformed explicit
identifier is an error, never a trigger for the fallback.

**Normalisation utilities.** Generic helpers — slugify, normalise, hash, canonicalize — are
written against generic inputs and then fed domain values. The question is not "does it work"
but **which real domain values collapse to the same output**. Two distinct entities
normalising to one key is a data-corruption bug wearing a formatting bug's clothes. Name three
plausible domain inputs the tests do not cover, and make them three *different kinds* of
input, not three instances of one kind. When the plan writes a pattern — a regex, a character
class, a length bound, an enum — the accepted values go **next to it** and each one is checked
against the pattern as written. A pattern and its input list separated by four hundred lines
stop constraining each other.

**Idempotency and partial commits.** If the operation runs twice, answer two things
concretely: how "already done" is determined, and what happens to the run that wrote three of
five records and then threw. The dangerous shape is compensating cleanup in an error handler
that deletes by parent identifier — it removes someone else's concurrent, successful work
along with this attempt's failure.

**Concurrency is per field, not per code path.** Idempotency asks what happens when one
operation runs twice. The harder question is which *other* operations write the same field.
List every mutable field the task touches and name every path that sets it; a field with two
writers is where the lost update lives. If both paths read it, compute a new value in
application code, and write it back, a guard on some status field does not save you — the
record is still in that status when the second writer commits, so its update matches and
silently overwrites. Three fixes, in order of preference: make one path the sole writer and
have the other delegate to it; move the merge into the statement itself; or put the value the
writer read into its own condition. And when you conclude a pair is safe, check **both**
directions.

**State machines.** Mandatory for any multi-step external-call loop: polling, retry with
backoff, queue consumers, trigger-then-fetch flows, multi-phase callbacks. "The polling loop"
is not one phase — trigger, loop top, per-fetch, timeout check, abort-on-deadline and
abort-on-per-fetch-timeout each fail differently. Two specific things go wrong when they are
collapsed: the wall-clock deadline gets checked only at the top of the loop, so one slow fetch
blows through it, when the check belongs at every stage transition; and the comparison at the
boundary is inclusive where it should be strict or the reverse, so a loop timed to make its
last attempt *at* the deadline exits one iteration early and reports a timeout it never
reached. Whenever a plan names a count and a deadline together, state which of the two governs
the final attempt. Separately: phases that share a status code do not share a handler — the
same code from two different calls means two unrelated things and needs two typed errors.

## The deferral trap

If the plan would leave a known gap behind a comment of the form "split this when a second
case appears", and **the second case already exists at planning time**, that comment is a
blocking finding rather than a judgement call. The gap itself was fine; writing a deferral
against a case you can already see is the violation.

The record of applied safe defaults exists for *unresolved unknowns*. The human gate exists
for *unknowns*. Neither is a place to get a known gap blessed.

## Where the rules came from

Keep the incident attached to the rule. A rule whose incident is forgotten is a rule that gets
deleted in the next refactor, by someone who can see the cost and not the reason. When this
file gains a rule, it gains a line saying which run produced it.
