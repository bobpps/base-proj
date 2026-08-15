# Stack profiles

The proving commands, manifest, and CI setup steps for each profile. Read this when block 2 reaches
the stack.

A profile is a set of **defaults to confirm**, never a set of answers to apply. The eight roles come
from `docs/engineering/evidence.md`, and what makes them useful is that each is proved by its own
observation. A profile that maps two roles to one command has not proved two things.

## TypeScript / Node

| Role | Default command |
| --- | --- |
| Type correctness | `npm run typecheck` → `tsc --noEmit` |
| Lint | `npm run lint` → `eslint .` |
| Format check | `npm run format:check` → `prettier --check .` |
| Unit tests | `npm test` → `vitest run` |
| Single test or file | `npm test -- <path>` |
| Build | `npm run build` |
| Artifact smoke | `npm run smoke` — a script that starts each built artifact |
| Integration / data layer | asked; commonly a database CLI's test command |

Supporting (`{{CMD_SUPPORTING}}`): `npm ci`, `npm run format`.
Setup (`{{SETUP_COMMANDS}}`, for `README.md`): `nvm use && npm ci`.
Format, write mode (`{{CMD_FORMAT}}`): `npm run format` → `prettier --write .`.

Node version pinned in `.nvmrc`; CI reads it with `node-version-file` rather than a literal, so the
two cannot drift. Manifest is `package.json` with `"type": "module"` and, for the workspace layout,
a `workspaces` array.

### Generate the lockfile before finishing

`npm ci` — the supporting command, and the install step in CI — **fails outright without a
lockfile**: *the npm ci command can only install with an existing package-lock.json or
npm-shrinkwrap.json*, exit 1. Writing `package.json` alone therefore produces a project whose
documented setup command and whose CI both fail on the first run, and the failure looks like a
broken workflow rather than like a missing file.

So run `npm install` once after writing the manifest, and leave `package-lock.json` in place for
the first commit. Where that cannot run — no network, no toolchain on this machine — say so in the
final report as an unmet prerequisite, in the same shape as a missing remote: the project is
configured, and it will not install until somebody generates the lockfile.

CI setup step:

```yaml
- uses: actions/setup-node@<pinned-sha> # vN
  with:
    node-version-file: .nvmrc
    cache: npm
- run: npm ci
```

Pin the action by commit, not by tag — a tag is a mutable pointer, and this step runs with access
to the checkout.

### Two traps this profile carries

Both were paid for in the projects this template was derived from. Where they apply, say so in the
generated `AGENTS.md` rather than assuming the next person meets them fresh:

- **In a workspace layout, installing dependencies does not build internal packages.** Type errors
  in a dependent package are meaningless until the shared package has been built once. Whatever the
  build order is, it belongs in `AGENTS.md` — otherwise a green typecheck means only that nothing
  was checked.
- **A bundler flag that leaves workspace packages external produces a bundle that builds cleanly
  and fails at process start.** This is exactly the gap the smoke role exists to close, which is
  why the smoke role is not optional for an application.

## .NET

**These defaults were derived from documentation, not from a live run in this repository.** State
that in the question, show the values pre-filled, and require confirmation rather than accepting
silence.

That is not politeness. Per `evidence.md`, an unverified default presented as verified is the exact
failure the whole doctrine exists to prevent — and a profile is not exempt from the rule it ships.

| Role | Proposed default |
| --- | --- |
| Type correctness | `dotnet build --no-restore` — compilation is the type check |
| Lint | `dotnet format --verify-no-changes --severity warn`, or the analyzer set the project uses |
| Format check | `dotnet format --verify-no-changes` |
| Unit tests | `dotnet test` |
| Single test or file | `dotnet test --filter FullyQualifiedName~<name>` |
| Build | `dotnet build -c Release` |
| Artifact smoke | `dotnet <path-to-dll> --version`, or an equivalent that starts the produced binary |
| Integration / data layer | asked; commonly `dotnet test` over a category, with containers |

Supporting (`{{CMD_SUPPORTING}}`): `dotnet restore`.
Setup (`{{SETUP_COMMANDS}}`, for `README.md`): `dotnet restore`.
Format, write mode (`{{CMD_FORMAT}}`): `dotnet format`.

Version pinned in `global.json`; CI sets it up from that file. There is no lockfile step here —
`dotnet restore` resolves from the manifest, which is why the Node profile needs one and this one
does not.

CI setup step:

```yaml
- uses: actions/setup-dotnet@<pinned-sha> # vN
  with:
    global-json-file: global.json
- run: dotnet restore
```

### Two mappings that need saying out loud

They differ from the Node profile in ways that quietly weaken the doctrine if left unstated:

- **Type correctness and build are the same command here.** Say so in `AGENTS.md` rather than
  listing one command twice as though two independent checks had run. Two roles proved by one
  observation is one observation, and writing it twice is how a report comes to claim more than it
  saw.
- **Migrations are a framework command rather than a CLI's**, and the file layout differs between
  the available ones. Ask for the project's actual command instead of guessing.

## Other

No defaults. Ask for all eight — **and for the three values that are not roles**, because
`README.md` and `AGENTS.md` carry them and a run that skips them cannot pass its own verification:

| Value | What it is |
| --- | --- |
| `{{SETUP_COMMANDS}}` | what a person runs once, in a fresh clone, before anything else works |
| `{{CMD_FORMAT}}` | formatting in write mode, as opposed to the format **check** among the eight |
| `{{CMD_SUPPORTING}}` | install, restore, and whatever else the other commands assume has run |

The other two profiles answer these from their defaults. This one has no defaults to answer from,
so it asks — and leaving them is not an option, because they are not roles and there is no "this
project cannot prove it" to record.

Any role the human leaves blank is recorded in `AGENTS.md` as a role **this project cannot prove**,
in those words. `evidence.md` requires that phrasing: a blank row reads as an oversight, and "we
have no command for this" reads as what it is — a known gap that a later reviewer can close or
accept deliberately.

Do not substitute a neighbouring command to fill a blank. A lint command in the type-correctness
row means every future run reports type correctness it never checked.
