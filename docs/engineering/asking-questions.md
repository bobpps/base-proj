# Asking the human

Read before any gate that puts a question to a human — a pipeline gate, an interview, a design
discussion. This file is about the shape of the question, not about when one is warranted;
`checkpoints.md` decides that.

## Why this file exists

By the time a question gets asked, the run has spent subagents and thousands of tokens
establishing ground truth. **The human has not.** A question that reads perfectly from inside
that context reaches someone who does not know what exists today, why this is even a fork, or on
which axis they are supposed to answer.

They then guess, or stop to ask what you meant. Either way the gate loses the thing it was for: a
decision the human actually stands behind.

The test to apply before sending any question:

> Could someone who has read **only the task** — not your research — answer this? If not, the
> missing piece belongs in the question, not in your head.

## Publish the fork map before the first question

One line per fork, in the order they will be asked:

```
Six forks, one question each:
  1. …
  2. …
```

This matters more than it looks. Without the map, every question arrives blind: the human cannot
tell whether a concern of theirs is coming up later as its own question, so they either cram it
into the current answer or stay silent about it. With the map they answer narrowly, and they can
see how much of the session is left.

Head each question with its position and what is already settled:

```
### Fork 3 of 6   (settled: 1 — …, 2 — …)
```

If a new fork surfaces mid-session — normal, that is what discussion is for — re-issue the map
with the addition and say plainly that it is new. Silently growing the list makes the progress
marker a lie. The same goes for merging two forks into one: say so.

## The question card

Four blocks, then the options:

- **How it is now** — the status quo in the area being touched, plain language first, with the
  file and line in parentheses. If the code does not exist yet, say so outright: that is itself
  the answer to "why are we designing this from scratch?".
- **The fork** — what is undecided, stated as observable behaviour or product outcome. A column
  name is not a fork; "how long after the call the user hears back" is.
- **Why you** — the axis the answer lives on: product tone, money, risk appetite, scope boundary,
  priorities, working habits. This is the highest-value block, because it tells the human which of
  their own preferences to consult. It also has a useful side effect — **if you cannot name that
  axis, the question is not theirs to answer.** Decide it yourself and record the decision.
- **Cost of being wrong** — reversibility. A configuration line, a rewrite, or a migration over
  live data? This lets the human calibrate how much thought to spend, and it is the block that
  most often makes them stop and think rather than nod along.

## Size the card to what a wrong answer costs

A wall of text in front of every question is just a different way of being unreadable.

**Full card** when the answer is expensive to undo: a schema, a public contract, a scope boundary,
anything touching shipped data or another open pull request.

**Two lines** — status quo plus why-you — when the fork is cheap to revisit.

Ceiling: roughly 200 words of card. Past that you are not sizing a card any more.

## When the fork needs a walkthrough instead of a card

Some forks cannot be compressed into a card honestly. The tell: **"how it is now" is a flow, not a
fact.** If explaining the status quo means tracing where a problem is born, what happens in
between, and where it is finally delivered, three sentences will not carry it — and options built
on top of a flow the human has not seen are unusable.

For those, spend a whole turn on the mechanism *before* any options exist:

1. Trace the flow end to end, in ordered steps with file and line — not just around the edit site.
   Say where the problem originates and where it lands.
2. Walk one concrete example through those steps: a real message, a real record, real values.
3. Say what you are considering doing about it, in prose, without asking yet.
4. Hand the floor over — "before choosing: ask whatever is unclear" — and answer follow-ups until
   the human signals they have it.
5. Only then ask, with the card and the options.

The extra turn is not politeness, it is how the answer gets better. Being asked to re-explain an
option in detail forces a re-read that has, in practice, revealed that the option would have broken
the happy path.

## Options describe the consequence, not the implementation

Option labels are severely space-limited, so the description is the only room there is — spend it
on **what changes for us**, and only then on how it is built. The human is choosing between
futures, not between diffs.

Weak — pure implementation, the reader has to derive the outcome themselves:

> Adds a status column and a worker that polls and claims with a conditional update.

Better — outcome first, mechanics second:

> The user hears back about half a minute after the call, and it survives a process restart.
> Built as a status column plus a worker. Costs one migration.

**Name what each option does not fix.** An option described only by its upside reads as free, and
it gets picked without its residue being seen — the case still unhandled, the second write path
still there, the migration still owed. One honest clause per option prevents a decision that has to
be reopened in code review.

Lead with the recommendation and keep its reason. Do not offer an option you would refuse to
implement.

## Always leave a way out

Say it explicitly under the card the first time: *"if something is unclear, say 'expand it', or
'you decide' and I will take the recommendation."* A human who cannot judge a fork should not have
to fake an opinion — an honest hand-back is better data than a guess.

## Do not ask what the code already answers

If the fork resolves by reading a file, read the file. Ambiguity you could have removed yourself is
not a question, it is unfinished research.

Likewise, a gate carrying six questions is a sign the analysis was not finished rather than a sign
the task is hard.

## Read pushback as signal

When the human pushes back, misreads a mechanism, or proposes something technically wrong, that is
information about your explanation, not about them.

- **Fix the explanation, not the human.** A misreading points at the step you skipped. Re-trace that
  step rather than restating the conclusion louder.
- **Mine the principle under a wrong proposal.** The mechanism they describe may be impossible while
  the instinct behind it is right — and it is often right about something every option missed. Ask
  what would have to be true for their idea to work, and whether the repository already has a
  precedent for it.

## Habits that quietly kill the context

- **Referencing earlier findings by index** — "covers requirement #4", "option (b) from the
  research". Six messages later that index means nothing. Restate the content in a clause.
- **Untranslated jargon.** Gloss on first use, inline, in a comma.
- **Mistaking the transition for the context.** "Settled: X. Second question — the trigger itself."
  is a good transition and zero context. Keep the confirmation line; it does not replace the card.
- **Assuming the research dump is still loaded.** It was delivered once, at the top. Restate the
  slice that matters inside the card. Repetition costs a few tokens; a misunderstood fork costs a
  rewrite.

## Record the answer, and what it rules out

The conversation disappears; the record does not. Write every question and its answer into the
run's `plan.md`, together with **what the answer closes off**, so a later phase does not reopen it.

Record it even when the answer matched the recommendation. A gate whose outcome is not written down
is afterwards indistinguishable from a gate that was skipped, and a resumed run reopens a question
the human already settled.
