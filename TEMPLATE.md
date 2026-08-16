# This repository is still the template

`base-proj` is the starting skeleton for a new project: the engineering doctrine, the task
pipeline, and the supporting skills, with every project-specific value left as a
`{{PLACEHOLDER}}`.

## Start here

```bash
git clone https://github.com/bobpps/base-proj.git <new-project>
cd <new-project>
git rev-parse HEAD > .base-proj-revision      # before the history goes, not after
rm -rf .git && git init
claude
```

**That third line is not optional bookkeeping.** The line after it replaces the history, and from
that moment nothing in the working tree knows which commit of `base-proj` this project came from.
The first decision record stamps it, and `/init-project` reads it from that file and then deletes
it. Skip the line and the stamp records that the revision was unknown — which is honest, and less
useful than the four seconds it costs.

Then run:

```
/init-project
```

The skill interviews you across eight blocks — identity, stack and proving commands, tracker and
branches, reviewer, optional contours, the local-versus-CI line, this project's risk additions,
and the architecture boundaries — and writes `AGENTS.md`, `CLAUDE.md`, `README.md`, the CI
workflow, the package manifest, the plugin settings, and the first decision record. Its last act
is to delete this file.

## What you get before answering anything

| Path | What it is |
| --- | --- |
| `docs/engineering/` | The doctrine. Nine files, no placeholders, identical in every project — `scripts/doctrine-checksum.sh` is what keeps that true. |
| `AGENTS.md` · `CLAUDE.md` | The rule files, as templates. |
| `.claude/skills/` | Seven skills: `init-project`, `task-pipeline`, and the five supporting ones — `retrospective`, `lessons`, `qa-architect`, `docs-audit`, `code-critic`. `CLAUDE.md` says what each is for and who may invoke it. |
| `.codex/skills/` | The Codex edition of the pipeline, same contract. |
| `scripts/copy-skills-to-agents.mjs` | Regenerates `.agents/skills/` so Codex can discover them. |
| `scripts/skills.test.sh` | Fails when the skill table and the disk disagree, a body outgrows its word ceiling, a reference file is unreachable from its `SKILL.md`, or `.agents/` was edited by hand. |
| `scripts/worktree-setup.sh` | The worktree procedure every task run uses, with `worktree-setup.test.sh` proving it. Needs only bash and git. |
| `scripts/review-snapshot.sh` | Fingerprints the tree around the review fan-out, so a reviewer that edited instead of advising is caught rather than trusted. `review-snapshot.test.sh` proves it. |
| `scripts/placeholders.sh` | Lists the template values still unfilled, without mistaking a GitHub Actions expression for one. `placeholders.test.sh` proves it. |
| `scripts/placeholder-coverage.test.sh` | Fails when the template carries a value the interview has no question for. Runs against the map in the `init-project` skill. |
| `scripts/doctrine-checksum.sh` | Checksums `docs/engineering/`, so the claim that `/init-project` never reaches the doctrine is measured rather than intended. `doctrine-checksum.test.sh` proves it. |
| `.github/workflows/ci.yml.template` | The structural half of CI — concurrency, permissions, the tracked-environment-file guard — with the commands left blank. Inert until `/init-project` renames it to `ci.yml`, because GitHub runs `*.yml` and would fail on the placeholders. |
| `docs/decisions/0000-template.md` | The decision-record format. |

## What it deliberately does not do

**Nothing synchronises this template with the projects made from it.** A clone is a starting
point, and from that moment the project owns its rules. The first decision record stamps which
commit of `base-proj` the project came from, so a comparison is possible by hand later; there is
no mechanism, and adding one is a decision to make deliberately rather than by drift.

The consequence is worth naming: an improvement discovered in one project does not reach the
others, and over time the rule sets diverge. That is the accepted cost.
