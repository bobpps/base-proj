# Writing the skills in this repository

Read before creating or editing anything under `.claude/skills/` or `.codex/skills/`.

## Progressive disclosure

Three levels, and the discipline is about which level a piece of content belongs to:

| Level | Loaded | Budget |
| --- | --- | --- |
| Name and description | always, for every installed skill | ~100 words |
| `SKILL.md` body | when the skill triggers | 1500–2000 words, hard ceiling 5000 |
| `references/`, `examples/`, `scripts/` | when the skill decides it needs them | no limit |

A `SKILL.md` that has grown past the ceiling is not a thorough skill, it is a skill whose
references were never split out. Move the detail and link to it explicitly — a resource the body
never mentions is a resource nothing will read.

## The description is the trigger

Third person, with concrete trigger phrases, and deliberately pushy. The failure mode in
practice is **under**-triggering: a model that could have used a skill and did not. List more
contexts rather than fewer, including casual phrasings and the languages the human actually
uses.

Say what the skill is *not* for when a neighbouring skill exists, so the two do not fight.

## Imperative, and explain why

Write instructions as commands — "read the configuration file", not "you should read the
configuration file". Second person costs words and reads as optional.

Prefer an explained reason to a bare prohibition. A rule that carries its reason survives contact
with a situation its author did not anticipate; a bare MUST gets rationalised around the first
time it is inconvenient, because nothing in it says what would break.

## A skill is a contract, not a decision tree

Fix what must be true at each checkpoint and which side effects belong to whom. Leave the agent
topology, the number of rounds, and the wording of each artifact open.

Prescriptions rot faster than principles. A threshold like "three or fewer tasks means one agent"
outlives everyone's memory of why the number was three, and then steers runs by an argument
nobody can reconstruct.

## Attach the incident to the rule

When a rule enters a skill because something went wrong, name the run or pull request it came
from. A rule whose incident is forgotten is a rule that gets deleted in the next cleanup, by
someone who can see its cost and not its reason.

## No facts a run could derive

Never bake into a skill a number, a count, or a claim about which files exist that the skill
could establish at run time. Every such value observed in practice had rotted within a month, and
each one steered a run wrong while looking authoritative.

Derive it in the skill's own first steps instead.

## Two editions, one contract

Where a skill exists for more than one harness, `.claude/skills/<name>/` and
`.codex/skills/<name>/` are **independent variants, not copies**. They express the same contract
in different tool vocabularies and can diverge by hundreds of lines starting at the frontmatter.

- **Never copy one over the other.** Re-express the change in each variant's own words and
  confirm each still reads as one document.
- A variant that already satisfies a change needs no edit. Say so rather than editing it into
  sameness.
- Shared rules live in `docs/engineering/`, read from the repository root by every edition. Change
  a shared rule **there**; forking it per edition is how the editions start demanding different
  things.

`.agents/skills/` is **generated** by `scripts/copy-skills-to-agents.mjs` and committed, so Codex
discovers skills without running anything. To propagate one edit, copy that one skill's directory
by hand from whichever source the script would pick. Do not run the generator to sync a single
change: it regenerates the whole tree against the local checkout, and in a checkout behind the
default branch that has meant a diff of a few hundred deletions over committed skills.

## Retire, do not delete

A skill replaced by a successor keeps its directory and gains `superseded-by: <successor>` in its
frontmatter. Presence on disk is not evidence a skill is alive; the marker is how the repository
remembers the decision instead of re-litigating it every time someone notices two similar skills.

## Repeated code belongs in `scripts/`

If several runs independently write the same helper, it is part of the skill. A deterministic task
done by a script is done identically every time and costs no reasoning.

## Evaluating a skill

Test prompts should be what a real user would actually type — with the mess, the paths, and the
half-remembered file names. Clean synthetic prompts pass skills that fail in practice.

- For a new skill, the baseline is the same prompt **without** it.
- For a change to an existing skill, the baseline is a **snapshot of the previous version**, not
  "no skill". Otherwise the comparison cannot show a regression.
- Generalise rather than fitting. A rule added to make one test case pass, in place of an explained
  principle, breaks the skill on every prompt the test suite does not contain.

## How the rules here actually change

Two halves of one loop, and both are needed:

1. **Every finished run writes a retrospective** mapping each finding to the earliest phase that
   could plausibly have caught it, with concrete proposed edits naming exact sections. It is
   non-blocking: a failure here is logged and swallowed, and never delays a pull request or the
   removal of a worktree.
2. **A separate pass applies the accumulated retrospectives** to the skills they indict. Without
   it, retrospectives are written and nobody reads them.

Rules for that second pass, each one paid for:

- **State lives in the reports themselves** — a line recording where each report's recommendations
  went and what of it remains. There is no external index, because an external index drifts from
  reality.
- **Frequency is the signal.** A point raised by three runs is a reproducible property of the
  pipeline; a single mention is one analyst's hypothesis. Where there is no frequency signal, say
  so rather than implying one.
- **Read the current text of the target before proposing any edit.** A recommendation is a diff
  against text that may have moved, already been satisfied, or been superseded by a later report.
- **Rejection is a real outcome**, and its reason is written down or it is gone. A pass where
  everything was applied deserves a second look.
- **Never mark a report as consumed before the edits land.** The reverse order manufactures exactly
  the loss the loop exists to prevent.
