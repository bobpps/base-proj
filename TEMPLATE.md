# This repository is still the template

`base-proj` is the starting skeleton for a new project: the engineering doctrine, the task
pipeline, and the supporting skills, with every project-specific value left as a
`{{PLACEHOLDER}}`.

## Start here

```bash
git clone https://github.com/bobpps/base-proj.git <new-project>
cd <new-project>
rm -rf .git && git init
claude
```

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
| `docs/engineering/` | The doctrine. Six files, no placeholders, identical in every project. |
| `AGENTS.md` · `CLAUDE.md` | The rule files, as templates. |
| `.claude/skills/` | `init-project`, `task-pipeline`, `retrospective`, `lessons`, `qa-architect`, `docs-audit`, `code-critic`. |
| `.codex/skills/` | The Codex edition of the pipeline, same contract. |
| `scripts/copy-skills-to-agents.mjs` | Regenerates `.agents/skills/` so Codex can discover them. |
| `scripts/worktree-setup.sh` | The worktree procedure every task run uses, with `worktree-setup.test.sh` proving it. Needs only bash and git. |
| `.github/workflows/ci.yml.template` | The structural half of CI — concurrency, permissions, the tracked-environment-file guard — with the commands left blank. Inert until `/init-project` renames it to `ci.yml`, because GitHub runs `*.yml` and would fail on the placeholders. |
| `docs/decisions/0000-template.md` | The decision-record format. |

## What it deliberately does not do

**Nothing synchronises this template with the projects made from it.** A clone is a starting
point, and from that moment the project owns its rules. The first decision record stamps which
commit of `base-proj` the project came from, so a comparison is possible by hand later; there is
no mechanism, and adding one is a decision to make deliberately rather than by drift.

The consequence is worth naming: an improvement discovered in one project does not reach the
others, and over time the rule sets diverge. That is the accepted cost.
