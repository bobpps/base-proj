# Marking the reports

The mark is the entire state of this loop. Read this before writing one.

A report's `**Applied:**` line answers two questions for the next pass: has this been read, and is
anything in it still waiting. Getting the second half wrong is silent — the next discovery sweep
skips the file, and the recommendations nobody applied are gone: unread, unrejected, unrecorded.

## The four forms

```
mid-pass    **Applied:** 2026-08-15 → task-pipeline (tasks/lessons/2026-08-15-task-pipeline.md); remaining: evidence.md
completed   **Applied:** 2026-08-15 → task-pipeline, AGENTS.md (tasks/lessons/2026-08-15-task-pipeline.md)
no targets  **Applied:** 2026-08-15 → none — report proposes no edits (tasks/lessons/2026-08-15-task-pipeline.md)
retired     **Applied:** 2026-08-15 → none — all targets retired, superseded by task-pipeline (tasks/lessons/2026-08-15-task-pipeline.md)
```

The date is the pass's date. The arrow list names what was **processed**, not what was applied — a
target whose every recommendation was rejected still processed the report, and the reasons live in
the protocol the line points at.

## `remaining:` is per report, not per pass

Only the targets *this* report contributes to that this pass did not process: unreached, dropped at
the gate, or abandoned mid-group. A report contributing to a single target never carries a
remainder, whatever else the pass left undone elsewhere. Omit the field when nothing is left.

This is the field that gets written wrong, and it is worth being deliberate about, because the two
mistakes fail in opposite directions:

- **A remainder that should not be there** buys a re-read forever: the next pass opens a report that
  has nothing left to give.
- **A missing remainder consumes the file.** The next sweep skips it and the other target's
  recommendations disappear. This is the failure the whole loop exists to prevent, and it is
  invisible: nothing looks wrong afterwards.

## A retired target never enters `remaining:`

It is not waiting for a later pass; it is out of the pipeline's life. Note it in the protocol
instead. Where every one of a report's targets is retired, use the `retired` form so discovery
stops paying to re-read it.

State the cost plainly rather than hiding it: un-retiring that skill later leaves those reports
already consumed. That is exactly why the mark names the reason and the protocol lists every report
marked this way — recovery is then a grep rather than an archaeology dig.

## One line is one state

A report that already carries a mark gets **the same line rewritten**: add the finished target to
the arrow list, delete it from `remaining:`, and update the date and protocol path to this pass.
A second `**Applied:**` line, or a stale remainder left beside a new one, and discovery misreads
that file from then on.

Keep the earlier protocol path only when the line would otherwise lose the only pointer to a
decision made in that pass — put both, oldest first, rather than dropping one.

## Placement

On its own line, **after the report's header block** — after the run of `**Key:** value` lines,
before the first `##`. Never inside the header block and never between a table's rows: splitting a
header is how the next reader's parse breaks, and the next reader is a batch of subagents reading
twenty files at once.

## Never mark before the edits land

Write a group's marks **as soon as that group's edits are on disk**, and not before, and not at the
end of the pass. This is what makes the one-group-at-a-time rule pay: the state on disk is true
whenever the pass stops.

Interrupted mid-discussion means no mark and the report stays fresh, which costs one re-read. The
reverse order costs the change: the report reads as consumed and the edits were never made.

## Counting for the gate

When tallying recommendations per target for the scope question, do not write

```sh
n=$(grep -c '…' "$f" || echo 0)
```

A zero match makes `grep` exit non-zero *and* print `0`, so the fallback appends a second line, the
arithmetic that follows throws, and the tally stops silently at the first file. Use

```sh
n=$(grep -c '…' "$f"); n=${n:-0}
```

or count in one pass with `awk`. A tally that stops at the first file still prints a table, and the
table is what the human answers the gate from.
