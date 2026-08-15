# The review loop after the pull request

Read in phase 11 of a task run. Both editions of the pipeline read this file.

Opening the pull request is not the end of the review. Where the project has an automated
reviewer, its findings routinely need several rounds on real work. Handling those rounds
outside the pipeline is how an adjudication record that took ten phases to build gets
abandoned at the last step: findings arrive, they get fixed one by one in conversation, and
nothing records which were rejected or why.

`AGENTS.md` names this project's reviewer — its account, how a fresh pass is requested, and
which surfaces carry its findings — or records that there is none. Everything in this file is
written against those facts rather than against a particular product, because the reviewer is
the one part of this loop that changes per project. **Verify the shapes against the project's
own pull requests rather than assuming them, and re-verify when they stop matching.**

## The one invariant

**A failure to look must never be reported as having looked and found nothing.**

Three outcomes are distinct, and collapsing any two of them is the failure this file exists to
prevent:

| Outcome | What it means | What to do |
| --- | --- | --- |
| `clean` | The reviewer ran against the current head, raised nothing, and nothing anyone else said about that head is still waiting for an answer | Proceed to the final report |
| `pending` | The reviewer has not run against the current head yet | Wait, or hand back to the human saying so |
| `degraded` | A call failed, an API errored, or the result could not be read | Say the check did not happen. Never report it as clean |

`pending` is not approval. `degraded` is not approval. Only `clean` is approval, and only
against the commit that is actually at the head of the branch.

## Identity is checked on the full string

Compare the reviewer's account name exactly, for whichever API produced the value — some APIs
decorate bot accounts and some do not. **Never match on a prefix.** A prefix is not an identity:
a similar name is one anybody can register, and a thumbs-up from it after the request time would
read as the reviewer's verdict on a pass the reviewer never ran. The author check is the only
thing standing between an arbitrary account and a clean round.

## A verdict belongs to a commit, not to a timestamp

Record two things when a round opens: **the moment the review was requested, and the head it was
requested about.** Both halves are needed, because the signals that carry a clean verdict often
carry no commit of their own. Time alone says a verdict is recent, not what it is a verdict
about.

Re-read the remote head at the moment of deciding, rather than trusting the value from when the
round began. If anything was pushed between the request and the answer — by this run, by a
collaborator, by automation — an approval arrives that is newer than the reference time and
describes the head before that push. Taken as clean, it certifies a commit nobody reviewed. If
the head moved, the round is void: start a new one.

Where a surface states the commit it reviewed, prefer that statement over any inference from
timing. A direct claim about what was reviewed beats a deduction.

## Ask for every round after the first

Typically only the first pass is automatic, triggered by opening the pull request. **Pushing a
fix does not start another one.** Every later round is requested explicitly, in the way
`AGENTS.md` records.

Ask *after* the push, never before: the reviewer reads the head as it stands when asked, so a
request that overtakes the push produces a verdict about the previous commit that looks like a
verdict about this one.

This is the difference between a loop and a stall. Polling a reviewer that was never asked
returns `pending` for as long as the bound allows, and then reports "the reviewer has not run
yet" — which is true, permanently, and reads as though it might resolve on its own. Before
waiting at all, confirm the request actually happened. Silence from a reviewer nobody asked is a
skipped step, not a pending one.

## An acknowledgement is not a verdict

Many reviewers signal "I picked this up" the moment they are asked, and clear the signal when the
pass finishes. Treat it as `pending` and as positive confirmation that the request arrived. A
poller that accepts any fresh signal reports a clean verdict in the middle of a running review.

## Read every surface, and read all of it

Collect the reviewer's surfaces in one pass, keeping the fields that tie each one to a commit,
and collect the thread state in the same breath. Classification depends on whether a thread is
resolved, so fetching that only later — when it is time to resolve something — leaves the
decision to be made from data that does not contain it. A finding a human resolved between rounds
would come back as current.

Paginate. These endpoints return the whole history of the pull request, not what arrived since the
last push, and the round that matters is the newest one — the first to fall off the end of an
unpaginated page. A single-page read on a pull request with a few rounds behind it sees only old
surfaces, concludes `pending`, and waits out the whole bound while the verdict sits on page two.

Do not filter out the provenance fields. A filter that drops the original commit, the parent
review, or the creation time makes the round undecidable while still looking like a full read.

## The thread is the unit, not the comment

Anything said inside an unresolved thread is outstanding; a resolved thread holds nothing
outstanding, however many replies it has. Group replies back to the comment that started each
thread — without the grouping, a question added deep in a thread is invisible and one already
answered keeps counting.

Beware of any field the platform *advances* to the newest commit where an anchor still applies: a
finding raised two rounds ago and already fixed then presents itself as current. Provenance lives
in the field that never moves.

## A human review is read only in its latest form

A person writes prose, not boilerplate, so nothing in the body identifies what they reviewed — and
review lists keep every submission ever made, so a "changes requested" they later replaced with an
approval is still sitting there and would block the loop forever. Collapse to the current state per
author, and take the commit as well as the state: the state alone cannot say whether a question is
about this head or an abandoned one.

**Anything a person said about this head and has not had answered keeps the round out of `clean`,**
whichever surface carried it. Write the rule this way round rather than listing the surfaces — the
enumeration is what makes it possible to forget one. An outstanding "changes requested" is
blocking, and no automated verdict overrides it.

## Severity from what the source supplied

Classify each finding before adjudicating it, using the signal the reviewer already gives.

| Signal | Severity |
| --- | --- |
| Failing CI check | blocking |
| Human review requesting changes | blocking until that human resolves it |
| The reviewer's highest priority badge | blocking |
| Its second level | high |
| Its third level | medium |
| Its lowest level | low |
| **A badge the project's table does not list** | at least medium, adjudicated on what the finding says |
| Human comment asking a question | adjudicate as a finding; `document_only` is a valid answer |

The last two rows matter most. An unrecognised badge is a finding whose severity is unknown, which
is not the same as a finding that does not exist — read it and place it, never drop it. A scale is
not defined by the values that happened to arrive so far.

Then apply the two promotions from `checkpoints.md`, and remember that a broken safe default from
`failure-axes.md` is blocking regardless of what badge it arrived with.

## What happens to the findings

Exactly what happened to the phase 7 findings: each is adjudicated to one status, gets an id, and
lands in `review.md`. The operating contract does not weaken because the finding came from a bot on
a hosting platform rather than from a reviewer in this session. A plausible-sounding finding that
contradicts a recorded decision in `docs/decisions/` is rejected **with that decision cited**.

Apply accepted fixes, push, resolve the threads those fixes closed, then start the next round
against the new head.

**Resolve only what was accepted and fixed, and only after it is pushed.** A thread carrying a
rejected, deferred, or still-disputed finding stays open — it is the reviewer's copy of a question
that has not been answered, and closing it converts an open question into a silent one. Resolving on
the strength of an edit in the working tree tells the reviewer a fix landed that is not on the
branch.

Not every surface can be resolved: a pull-request-level comment has no thread to close, a failing
check closes when the next push produces a passing run, and a review submission closes when a newer
one arrives.

Three external actions, separated by what each asserts. **Asking for the review** and **resolving a
thread** are both part of the loop and need no separate permission: the first says a new head is
ready to look at, the second says a named finding was accepted and fixed on the branch. Both are
facts the run has already established. **Replying to the reviewer in a thread** is an opinion
addressed to whoever reads it next — write one only when the human asked for it. Pushing the fix and
resolving the thread is the normal answer.

## Where the round's record goes

A round's record reports what happened, including which threads were resolved — and threads are only
resolved after that round's fixes are pushed. So the record travels with the **next** push: the
following round's fixes, or the bookkeeping commit that closes the loop. Writing it into the same
commit as its own fixes would have it assert a resolution nobody had attempted yet, and leave the
file lying if the attempt failed.

## The bookkeeping exemption

**A commit whose entire content records events that already happened does not reopen the loop.**
Waiting for a verdict on it could never terminate: every verdict needs recording, and every recording
would need a verdict.

The exemption covers the round record and the validation file updated with the CI outcome — a reviewer
has no opinion to offer about either, because they report the past and the past is not up for review.
It ends where a commit says something new: code, a rule, or a documentation claim that asserts rather
than records is a change like any other, and the loop continues on the new head even if the diff is
one line.

Exempt from the reviewer, not from CI. Every push starts a run, including this one, so wait for it on
the new head before reporting. **That last result is reported, not filed** — writing it into the
validation file would need one more commit, whose run would need recording, and so on without end. A
chain of records has to stop at a link nobody records, and the final report is that link because
nothing follows it into the repository.

## When the loop ends

There is no cap on the number of rounds. Run until one of two things is true:

- **The round is clean against the current head** — nothing outstanding on it from anyone. This is the
  default and what to aim for.
- **Every finding still open has been settled to a status that asks for no change in this pull
  request** — `rejected`, `deferred`, or `document_only`, none of them blocking, and every `high` one
  among them explicitly accepted by the human.

What ends the loop is that nothing is left waiting for a decision, not that the leftovers are small: a
medium finding deliberately deferred settles it exactly as a nit does, and a finding still marked
`accepted` keeps it open however trivial. Those findings cannot stay `accepted` — that status means
fixed in this pull request, so leaving them there would have the pull request claim a fix that was
never made. Adjudicate each `deferred` or `document_only`, which puts it under a heading that already
demands the sentence saying what ships without it.

The human acceptance in the second exit is not a formality. Without it, this would be the one route by
which a real high-severity issue reaches the default branch on nobody's authority but the run's own.

**"Only nits are left" is a conclusion produced by adjudication against evidence, never an impression
of the round.** The failure this wording exists to prevent is the tempting one: several rounds in, the
findings start to feel like pestering, and relabelling a real one as a nit ends the loop immediately.
