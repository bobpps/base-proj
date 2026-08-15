# Evidence

Read before claiming that anything works, and again before writing the `validation.md`
checkpoint of a task run.

Nothing in this file depends on a programming language, a framework, or a task tracker.
The project supplies the commands; this file supplies what a command has to prove.

## The one rule

**Configuration states intent. Observation states fact.**

A migration records what was asked for; the privilege catalogue records what the object
now does. A build script records what the author meant to run; the command's output
records what ran. Re-reading the file you just wrote confirms your own intention, and it
cannot see what was already there before you wrote it.

Every claim of completion is backed by an observation. Never by a re-reading, never by a
diff that "looks right", never by the fact that the code compiles.

## The proving commands

`AGENTS.md` names one concrete command per role below, for this project. Everything else
in this file is written in terms of the roles, never the tools, so it holds unchanged when
the project's language changes.

| Role | What a green result proves |
| --- | --- |
| Type correctness | Every type the compiler or checker can see is consistent, across the whole project rather than the files that were touched. |
| Lint | The rules the project chose to enforce mechanically are not violated. It proves nothing about correctness. |
| Format check | The tree is formatted. Run the check, not the writer, when proving — a formatter that rewrites files reports success by changing them. |
| Unit tests | The behaviour the tests describe still holds. Coverage of what they do not describe is unknown, not proven. |
| Single-test run | One named test or file can be run in isolation. This is what makes a red-green loop affordable. |
| Build | The artifact can be produced. |
| Artifact smoke | The produced artifact starts. See below — this is a separate role on purpose. |
| Integration / data layer | The parts that need real infrastructure behave. `AGENTS.md` records where this one is allowed to run. |

A role with no command in `AGENTS.md` is a role this project cannot prove. Say that, in
those words, rather than substituting a neighbouring command that proves something else.

## Four outcomes, never three

Every check reported at a checkpoint carries one of four states, and the state that gets
dropped is always the last one:

- **PASS** — it ran and succeeded.
- **FAIL** — it ran and failed, with what it said.
- **Checked by hand** — a human or the agent observed the behaviour directly, with what
  was observed.
- **Not run** — nobody ran it, and here is why.

Each also carries **where it ran**: this machine, or CI with the run's URL. A check whose
location is missing is indistinguishable from a check that was assumed.

## "I could not check this" is said plainly

An unprovable check is a fact about the run, not an embarrassment to be smoothed over. Say
it in those words, and give a reproducible manual alternative where one exists.

What is forbidden is the substitution: reporting a related check that did run, reporting
that the code "should" work, or leaving the item out of the report entirely. Silence reads
as success to every reader, which is exactly why it is the tempting option.

## Pre-existing failures are separated from regressions

A failing check that was already failing before this change is reported as such, with
evidence that it predates the work — the same command on the base commit. It is never
hidden, and it is never allowed to blur into the changes this run introduced.

Hiding it costs the next run the same investigation. Blurring it costs the reviewer the
ability to tell whether this change broke something.

## Whoever owns the gate runs the checks

The session that pushes, opens the pull request, or declares the work finished runs the
proving commands itself, in its own context. Delegation is allowed everywhere else, but a
delegated agent returns a **claim** that the tests passed, and a gate needs **evidence**.

If the run does delegate verification anyway, require the raw tail of the command's output
back and treat that — not the agent's summary — as the evidence.

## Refusals do not prove a policy is correct

A permission check, an authorization rule, or an access policy is proved by at least one
**positive** case per permitted operation, alongside the negative ones.

The reason is mechanical: a correct policy and a policy that denies everyone produce
identical evidence when only refusals are tested. Both refuse the outsider, both look
green, and only one of them lets the owner do their job. A test suite made entirely of
refusals cannot tell "correctly closed" from "broken for everybody".

## A green linter is the start of the argument

Advisors, linters, and security scanners encode the mistakes someone thought to check for.
A construct can satisfy every one of them and still expose everything — the classic case
is a view or projection that passes every rule while sitting on top of a rule that matches
all rows.

Treat a green advisor as one input. The argument is finished when the behaviour has been
observed, not when the tool stops complaining.

## Building an artifact is not proving it runs

The build role and the artifact-smoke role are separate because a bundle that compiles and
a bundle that starts are different claims. Bundlers resolve imports at build time and
discover missing runtime dependencies at start time; a configuration that externalizes a
workspace package builds cleanly and dies on the first process start.

Where the project produces a runnable artifact, `AGENTS.md` names a command that starts it,
and CI runs that command. Where it produces a library, this role is recorded as not
applicable rather than left blank.

## Where the line between this machine and CI falls

Some checks cannot run everywhere. A development machine may lack a container runtime, a
database CLI, or a credential that only CI holds. `AGENTS.md` records the line for this
project, and the rule around it is fixed:

- Checks on the near side of the line are proved **before** any claim of completion, on the
  machine that wrote the code.
- Checks on the far side are proved by CI, and CI is **watched to a verdict** rather than
  predicted. A push is not a result.
- The checkpoint says which side each check was on. A validation file that reports
  "awaiting CI" after the run went green has lost the record that mattered most — update it
  when the real outcome exists.

The line is a decision with consequences, so it belongs in `docs/decisions/` with its
reasoning, not in someone's memory.

## Verification is not a phase you can skip when short on time

The failure this file exists to prevent has one recognisable shape: the work is done, the
diff looks right, the remaining checks feel like formality, and the run reports success
having proved a subset. Everything above is cheap; discovering in production which subset
was skipped is not.
