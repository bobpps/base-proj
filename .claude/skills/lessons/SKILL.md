---
name: lessons
description: >
  Reads the accumulated task retrospectives and turns them into edits to the files they indict —
  the engineering doctrine, the skill editions, or this project's AGENTS.md — then marks each
  report with where its recommendations went. One invocation drains the reachable archive. Use when
  retrospectives have piled up and nobody has applied them, or when a human says "разбери
  ретроспективы", "примени накопленные уроки", "улучши пайплайн по ретроспективам", "what have the
  retrospectives been telling us". Invoked only by explicit human command — never automatically,
  and never from inside a running pipeline, because it edits the very skills a running pipeline is
  executing.
user_invocable: true
disable-model-invocation: true
argument-hint: "[lead-target] [--limit N]"
---

# lessons

`retrospective` writes a report at the end of every run, and nothing else ever reads it. This skill
is the reader. It is the second half of the loop `writing-skills.md` describes; read that file's
last section before starting, because the rules it fixes — frequency is the signal, read the
current text first, rejection is a real outcome, never mark before the edits land — are the rules
this pass is judged against, and they are stated there rather than here so both halves cannot
drift.

`disable-model-invocation` is deliberate. A pass that edits skills while a pipeline is running
changes the instructions mid-execution.

**State lives in the reports.** A processed report carries an `**Applied:**` line recording which
targets consumed it and which of its own recommendations are still waiting. There is no external
index — that line is the state, and it belongs to this skill alone.

**This file states no facts about the archive.** How many reports exist, which skills are alive,
which recommendations are interesting: all of it is derived at run time. Every count baked into an
earlier version of a skill like this had rotted within the month, and each one steered a run wrong
while looking authoritative.

## 1 · Discover

`N` is `--limit`'s value, default 20.

```bash
{ grep -L '^\*\*Applied:\*\*' tasks/*/retrospective.md
  grep -l '^\*\*Applied:\*\*.*remaining:' tasks/*/retrospective.md
} | sort -u > /tmp/lessons-candidates

while read -r f; do
  echo "$(git log -1 --format=%ct -- "$f") $f"
done < /tmp/lessons-candidates | sort -rn > /tmp/lessons-ordered
head -n "$N" /tmp/lessons-ordered            # selected
tail -n +"$((N+1))" /tmp/lessons-ordered     # cut — name these at the gate
```

Fresh reports plus partially consumed ones. A fully consumed report is never read — not one token.

**Order by commit date, not by task id and not by mtime.** Task ids are not chronological, and
mtime lies because a report is duplicated into every worktree that ever held the branch.

**Use the full committer timestamp — `%ct`, epoch seconds — rather than a calendar date.** Several
runs finishing on one day is the normal case, not an edge case, and it is exactly the case where a
`--limit` bites: with a date-only key every report from that day ties, the sort falls through to
comparing paths, and an older report gets selected while a newer one from the same day lands in the
cut. The ordering would then contradict the sentence above it while looking correct. Epoch seconds
also avoid the trap in a formatted timestamp, where two commits made in different timezones sort by
their text rather than by their moment.

**Say what the limit cut.** A report that falls off the bottom is invisible otherwise, and the
oldest reports are where the rare formats live. Name them at the gate so the human can raise
`--limit`.

## 2 · Resolve each recommendation to a target and a layer

An agent reads the reports; fan readers out over small batches of four or five, each returning the
recommendations it found with their stated targets. Twenty dense reports through one context
starves it. Brief them per `subagent-briefs.md`. **A regex cannot do this reading** — the report
format is a template, not a contract, and older reports predate whatever the template says today.

Every recommendation carries a file, a section, and a layer. Trust the file it names over the file
its explanation mentions: a recommendation whose body says "this also belongs in the plan phase"
while its head names `evidence.md` is a recommendation about `evidence.md`.

Two resolutions the report cannot make for you:

- **Resolve a skill by where its directory sits**, not by the name inside a path. A reference file
  under `task-pipeline/references/` belongs to `task-pipeline` whatever its own filename says.
- **A recommendation with no target is not a bucket.** `no change proposed — process observation`
  is a finished answer. Inventing a target for it sends this pass editing a file no run indicted,
  which is the single most expensive mistake available here.

Group by target. One report routinely lands in several groups; that is the normal case, not a
conflict.

Liveness has three states and only two are derivable:

| State | Test | Treatment |
| --- | --- | --- |
| absent | the file or skill directory is not there | dropped, and named at the gate |
| retired | `superseded-by:` in the skill's frontmatter | listed under its successor, out of scope by default |
| current | present, no marker | in scope by default |

A report already carrying a mark contributes **only** what its `remaining:` names. Everything else
in it was settled in an earlier pass, applied or rejected with reasons recorded there; re-proposing
it relitigates a decision that was already made.

## 3 · The layer gate

**A doctrine edit is a human decision.** `docs/engineering/` is inherited by every project cloned
from this template, including projects that do not exist yet and cannot object. A skill edit
changes how this repository works; a doctrine edit changes how every future repository works, and
it cannot be observed failing anywhere before it ships.

So the pass splits at the layer:

| Layer | Authority |
| --- | --- |
| `AGENTS.md`, `CLAUDE.md`, `README.md` | apply, and report |
| `.claude/skills/`, `.codex/skills/` | apply, and report |
| `docs/engineering/` | **propose at the gate; apply only on the human's answer**, and record the accepted change in `docs/decisions/` |
| `docs/decisions/` | never edited — a decision record is what was decided then. A decision that changed gets a new record superseding it |

Put the doctrine proposals to the human per `asking-questions.md`, together with the scope of the
whole pass, in one gate rather than several: two to four concrete options each saying what it costs
and what it locks in, the recommendation first.

**Present the scope even when no doctrine edit is proposed**, whenever more than one live target
exists. A named lead argument pre-selects the order; it does not authorize the scope. Put four
things in the question, because you have just read twenty reports and the human has not: what
happens if nobody objects, what each target's recommendation count and dates would cost, why the
answer is theirs rather than derivable, and what each wrong answer costs — a retired target kept
means real edits to a skill nobody runs, a live target dropped means its recommendations wait for
the next pass, recorded but unapplied.

A dropped target is not a processed one. It goes into `remaining:` exactly like an unreached one.

## 4 · Work one target at a time

Lead first, then the rest **ascending by size**. Small groups finished early are banked; only the
largest is at risk when the pass is interrupted. Carry each group through applying, the protocol,
and the marks before opening the next — a pass that discusses everything first and applies at the
end loses all of it at once.

Within a group:

1. **Deduplicate, recording how many runs raised each point.** Frequency is the signal. Where a
   point appears once, say that it appeared once rather than implying a pattern.
2. Order by frequency, then by what the point cost the runs that raised it.
3. **Read the current text of the target before proposing any edit.** A recommendation is a diff
   against text that may have moved, already been satisfied, or been superseded by a later report
   contradicting it. Where two reports disagree, the later one usually wins — say why.
4. Decide per recommendation: **applied, rejected, or deferred.** A group where everything was
   applied deserves a second look.

**The report is the atomic unit.** Finish every recommendation a report contributes to the current
group before marking it — the mark has no half state.

Across groups, watch for **one defect wearing two hats**: a single failure often yields a
recommendation in the doctrine and another in a skill, the rule in one and the mechanism that
detects it in the other. Prevention and detection are different edits and they have to agree. Name
the pairing in both protocol sections; a pass that lands only one half leaves the class open.

## 5 · Apply

Edits follow `writing-skills.md`: the two skill editions are independent variants and are never
copied over each other, `.agents/` is generated and a single change is propagated by hand-copying
one directory rather than by running the generator, and a shared rule is changed in
`docs/engineering/` rather than forked per edition.

**When a rule enters a file because a run went wrong, name the run.** The retrospective knows which
one; the file will not, and a rule whose incident is forgotten is deleted in the next cleanup by
someone who can see its cost and not its reason.

**Where a rule states a checkable property, say so — and propose the check rather than writing it.**
This repository's own history is the argument for the first half: five separate review rounds each
found a different unfillable placeholder, and the class closed only when one list was compared
against another by a script. A rule that could be checked and is not gets rediscovered by whoever
next breaks it.

The second half is an ownership boundary rather than modesty. A check under `scripts/` is
executable code that runs in everyone's CI, and this is a bulk pass over a whole archive — no plan,
no proving commands, no review fan-out. Those are exactly what a code change in this repository goes
through, and a pass that skipped them could turn every build red on the strength of one report's
suggestion.

So write the proposal into the protocol precisely enough to act on without re-deriving it: the
property, the file it belongs beside, what a failure would have to say, and which reports asked for
it. A task run implements it. The cost is real and worth naming: the property stays unchecked until
somebody picks that task up. It is a delay, not a loss — and the proposal is on disk rather than in
one pass's memory.

Do not commit, and do not edit anything under `scripts/`. This project commits on an explicit
request.

## 6 · Write the protocol, then mark

One file for the whole pass: `tasks/lessons/<YYYY-MM-DD>-<lead>.md`, opening with the targets in
scope, any the human dropped, and anything `--limit` cut. Then one section per target as it
finishes, carrying:

- the **frequency table** — the point, and how many runs raised it. This is the pass's only durable
  evidence that a point was reproducible; the marks cannot hold it and the reports get consumed.
- what was applied, and into which section of which file, with its layer.
- what was rejected and why — including "already satisfied", quoting the current text that
  satisfies it.
- what was deferred, quoting the recommendation verbatim so a later pass can act without
  re-reading the report.
- **any check this pass proposed but did not write**, in the shape described above. It is the only
  record that the property was noticed, and it is the input a task run needs.
- any doctrine change the human approved, and the decision record it produced.
- any cross-group pairing.

One file per pass rather than per target, because the pass is the unit that has a story: which
recommendations were read together, which were traded against each other, which halves of one
defect went to different files.

The marks record only that a report was processed, so a rejected recommendation surfaces nowhere
else. If the reason is not in the protocol, it is gone.

**Read `references/marks.md` before writing a single mark.** It carries the exact line grammar, the
per-report semantics of `remaining:`, where the line goes in the file, and why marking before the
edits land manufactures exactly the loss this skill exists to prevent.

## Boundaries

Does not commit or push. Does not touch the tracker. Does not edit code, `scripts/` included — a
check it wants is proposed in the protocol and written by a task run. Does not edit
`docs/decisions/` except by adding a new record for an approved doctrine change. Does not edit
report content — only the `**Applied:**` lines it owns. Does not run during a pipeline. Does not
apply a doctrine edit without the human's answer.
