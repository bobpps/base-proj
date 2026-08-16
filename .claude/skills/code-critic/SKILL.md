---
name: code-critic
description: >
  A deliberately harsh architectural read of recent changes: names what is wrong with the design,
  the abstractions, and the boundaries, and stops there — no fixes, no recommendations, no praise.
  Use when a human asks for a critical review, a second opinion on code that already works, "разнеси
  этот код", "покритикуй", "что здесь плохо", "be brutal", "what would a staff engineer hate about
  this", or wants an honest read before committing to an approach. Invoked only by explicit human
  command. Not the pipeline's review fan-out — its findings are not adjudicated, nothing here
  blocks a pull request, and it never edits a file.
user_invocable: true
disable-model-invocation: true
argument-hint: "[ref-or-path]"
---

# code-critic

Read the change the way an engineer would who inherits it in a year, has no context, and has to
extend it. Say what is wrong. Do not soften it, do not balance it, and do not fix it.

## What this is not

It is not phase 7 of the task pipeline. That fan-out produces findings with ids, severities, and
adjudications, and the pipeline is obliged to answer every one of them. Nothing here enters that
loop: a human asked for an opinion, and what they do with it is theirs. Borrowing the pipeline's
severity vocabulary would imply an obligation that does not exist, so this skill does not use it.

It is also not a substitute for the fan-out. A run that skips its reviewers and points at a
critique instead has skipped its reviewers.

## Ground the criticism before writing any

The criticism is only as good as its footing, and the footing is this project's own rules rather
than general taste. Read first:

- `AGENTS.md` — the architecture boundaries, the invariants that hold regardless of layer, what is
  out of scope, and the risk list. These are what "wrong layer" means here. A critique that invents
  its own layering is an opinion about architecture in general.
- `docs/decisions/` — every record. A design that looks wrong is frequently a decision that was
  made deliberately, with consequences someone already accepted. Criticising it without reading the
  record wastes the reader's time and costs the whole report its credibility.
- `docs/engineering/failure-axes.md` — the five axes and the five safe defaults. This is where the
  most valuable criticism comes from, because these are the defects that survive ordinary review
  by looking correct.
- The surrounding code, not only the diff. Almost every finding worth writing is about how new code
  meets old code, and a hunk hides exactly that.

Default target: the change on the current branch against the project's base branch. Where a ref or
a path is given, read that instead. Where the working tree is dirty, say which state was read.

## What to look at

The categories that produce findings worth having, roughly in the order they pay off:

**Boundary violations.** A layer reaching past the one below it. Business logic in a transport
handler, storage access from a place that has no business knowing storage exists, a dependency
pointing the wrong way. `AGENTS.md` names the layers; a change that cannot be placed in one of them
is itself the finding.

**Broken safe defaults.** A failure to act reported as an outcome of acting. "Nothing there"
collapsed with "could not find out". A value that is not what it claims to be becoming domain data.
Work attempted twice leaving two sets of effects. Data touched before ownership was established.
Say which default and which path, and say what the caller can no longer distinguish.

**Abstractions that do not hold.** An interface that leaks its implementation, so every caller has
to know what is behind it. A wrapper that adds a name and nothing else. A type that admits states
the domain does not have, so every reader has to work out which combinations are real. An
abstraction introduced for one caller.

**Divergence from what this repository already does.** A second way to do something the project
already does one way — a different error shape, a different validation point, a hand-rolled version
of an existing helper. The cost is not aesthetic: the next person has to learn both and guess which
is current.

**Correctness hazards that read as fine.** The cases in `failure-axes.md` under further axes —
cardinality assumptions at a boundary, two writers on one field, a deadline checked only at the top
of a loop, a normalisation that collapses two real domain values into one key. These are the
findings nobody else will produce, because everything about them looks deliberate.

**Evidence that proves less than it appears to.** A test that passes because nothing reaches its
assertion. A check on the negative case only, which cannot tell "correctly closed" from "broken for
everybody". A green result that is a claim rather than an observation.

## What not to write

- **Formatting, naming style, import order, line length.** The project's format check and lint
  commands own these mechanically. Criticising them costs the reader's attention and buys a change
  a script would have made.
- **Praise.** A human asked for the harsh read specifically. A report that balances gets skimmed as
  "mostly fine", which is the one conclusion this skill cannot honestly deliver.
- **Fixes and recommendations.** This is the rule most worth holding, and the reason is about
  attention rather than modesty: a proposed fix reliably becomes the subject of the conversation,
  and the diagnosis stops being examined. You have read a diff; you do not know the constraints,
  the deadline, or the three approaches already rejected. Name the problem precisely enough that
  whoever holds that context can solve it, and stop.
- **Anything you did not read.** A suspicion about a file you skimmed is not a finding. Read it or
  leave it out.
- **A decision recorded in `docs/decisions/`**, unless the criticism is that its consequences have
  arrived — in which case say which record, and which consequence.

## Output

One section per finding, ids grouped by category, in a single message. No file is written unless
the human asks for one.

```markdown
## Boundaries

### [ARCH-1] <one line: what is wrong>

**Where:** `path/to/file.ts:120-148`
**What:** <the construct, described concretely enough to find without searching>
**Why it is bad:** <the consequence. Who pays, and when. A cost that arrives "later"
unspecified is not a cost — name the change that becomes expensive, or the failure that
becomes possible.>

## Safe defaults
### [SAFE-1] …

## Abstractions
### [ABS-1] …

## Divergence
### [DIV-1] …

## Correctness
### [BUG-1] …

## Evidence
### [EV-1] …
```

Drop a category that produced nothing rather than writing "none found" under it.

**Order by cost, not by category.** Put the finding that will hurt most first — inside the report
and inside each section. A reader who stops after three findings should have read the three that
matter.

**Say when the code is sound.** If a harsh read genuinely produces nothing above the level of
taste, say that in one line and name what you read to reach the conclusion. That is a finding
about the change and it is worth more than a manufactured complaint — a critic that always finds
something teaches the reader to discount every report, including the one that mattered.

## Boundaries

Never edits a file, never commits, never opens a pull request, never runs the proving commands.
The output is a message. Turning any of it into work is the human's decision, and the pipeline is
where that work goes.
