# 0001 — One remote per run, named rather than inferred

## Status

Accepted

## Context

`scripts/worktree-setup.sh` must answer one question before it does anything else: which server is
this run's. The answer decides where the fetch goes, which ref the task branch is created from,
what both merges pull in, and where phase 10 pushes.

The script tried to derive that answer. Four consecutive review rounds each found a different place
where the derivation was wrong, and each fix was correct, tested, and shipped:

| Round | What was inferred | Fix |
| --- | --- | --- |
| 4 | `origin`, hardcoded | Derive it from the repository |
| 7 | `origin` as the fallback when several remotes existed | Read `branch.<name>.remote` |
| 9 | Phase 10's bare `git push` re-answered it through git's defaults | Push by name |
| 11 | A task branch on a remote nobody fetched classified as *absent* | This decision |

Round 11 was the blocking one. With the base tracking `upstream` and the task branch existing only
on `origin`, the branch has no local configuration, so nothing names `origin`; the script selected
`upstream`, fetched only that, classified `feat/x` as absent, created an unrelated branch of the
same name from `upstream/main`, and phase 10 would have pushed that history to `upstream` while the
real work sat orphaned on `origin`.

Two consecutive blocking rounds fired the termination rule in `checkpoints.md`, which is why this
reached a human rather than a fifth fix.

The decisive observation is that **the repository does not contain the answer.** A task branch on
`origin` with a base on `upstream` is a coherent fork workflow; so is the same shape with the roles
swapped. No rule reading the repository can tell which server this task belongs to, so an inference
here has no ground truth and therefore no natural stopping point. That is why four correct fixes
produced a fifth defect.

## Decision

**A run reads and writes exactly one server, and that server is named rather than inferred.**

- Where the repository has exactly one remote, the procedure uses it.
- Where it has several, `--remote` is required — from the `Remote` row in `AGENTS.md` — and the
  procedure exits 2 without it, naming the way out.
- A branch living on any other remote is **outside the run by definition**, not by oversight.

## Consequences

A project with several remotes must record the server by hand, and `/init-project` asks for it
exactly when `git remote` lists more than one. Recording the wrong name there means the procedure
will obey the wrong name. That is the trade this decision buys: a wrong answer visible in one line
of configuration, instead of a silent one derived at run time.

The inconvenient part, stated plainly: a genuine fork workflow — pull the base from `upstream`,
push the branch to `origin` — **cannot be expressed**. One name cannot carry two servers. Such a
project either configures the run against one server and moves work between them by hand, or
proposes a change to this decision with the two-server case designed rather than patched in.

The failure mode this leaves is narrow and worth naming: with `--remote origin` recorded, a branch
of the same name already pushed to a *different* remote is not consulted, and the run creates a
fresh branch from the base. This is defined behaviour and is pinned by an assertion in
`scripts/worktree-setup.test.sh` so a later reader does not mistake it for the round-11 defect and
re-open the inference. It differs from that defect in the way that matters: the server was stated
by a human, not guessed by the script.

## Alternatives considered

**Search every configured remote for the branch and gate on ambiguity.** This is what the round-11
reviewer proposed, and it answers by observation rather than by declaration, which is the stronger
epistemics. It lost on cost and on trajectory: it fetches every remote on every run, and it makes
the script infer *more* rather than less — the fifth site in a family that had already produced
four. Where inference has no ground truth, more inference is more surface.

**Defer the finding and ship the limitation.** Rejected because this repository is a template: the
defect would be cloned into every project made from it, and it surfaces as a lost branch rather
than as an error.
