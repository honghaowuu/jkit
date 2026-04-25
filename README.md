# jkit

Spec-driven development for Java/Spring Boot microservice teams.

`jkit` is a Claude Code plugin that brings a structured TDD and contract workflow to AI-assisted Java development. It combines a set of Claude skills covering the full development cycle with a Rust CLI (`bin/jkit`) that gives those skills token-efficient, machine-readable views of your Java project — so Claude makes decisions from compact JSON summaries rather than raw XML and source files.

**What's included:**

- 7 Claude skills covering the full dev cycle: spec delta, unit TDD, integration test TDD, coverage gating, contract publishing, SQL migration authoring, and Feign client generation
- `bin/jkit` — a Rust CLI for Java project pipeline operations (pom fragment management, JaCoCo coverage gaps, scenario gap detection, schema migration diff/place, contract bundle staging)
- `bin/kit` — a language-agnostic companion CLI for cross-cutting operations (plan/plugin status, scenario sync/skip, contract publish)
- `bin/codeskel` — a polyglot project scanner used during contract generation
- Hook-injected project context that keeps skills consistent across Claude sessions

---

## Install

```bash
claude plugin install jkit
```

If your service consumes upstream contracts from other teams, install their contract plugins as dependencies:

```bash
bin/install-contracts.sh
```

---

## Skills workflow

The skills form a pipeline. Spec changes drive TDD, which drives integration tests, which drive contract publishing. Start at `/spec-delta` and follow the cycle through to `/java-verify` before publishing.

### `/spec-delta`

Start here. Computes what changed in `docs/domains/` since the last implementation commit, orders affected domains by dependency, runs scenario-gap detection for each changed domain, and produces a `change-summary.md` for your approval — before any code is written. Everything downstream derives from this change summary.

### `/java-tdd`

Implements a plan via strict TDD: a failing unit test must exist before any implementation code is written. After each red → green cycle, JaCoCo coverage gaps are analysed and fed back into the next test. No exceptions and no "write the test after" — tests written against already-passing code prove nothing.

### `/scenario-tdd`

Implements integration test gaps one scenario at a time, driven by the gap list in `change-summary.md`. Each scenario follows a strict RED → GREEN loop using RestAssured against a live Testcontainers stack. Batch generation is not allowed — one failing test, then implementation, then the next scenario.

### `/java-verify`

Runs the full quality gate: `mvn verify`, merged JaCoCo unit and integration coverage, API endpoint coverage check (declared spec endpoints vs RestAssured-tested endpoints), then hands off to code review. This is the exit gate before a PR is raised.

### `/publish-contract`

Generates the 4-level service contract — a SKILL.md skill definition plus per-domain markdown docs — and pushes it to the contract plugin repo and registers it in the marketplace. Requires Javadoc on all controller methods; the skill enforces this before generating anything.

### `/generate-feign`

Generates a type-safe Feign client from an installed upstream contract plugin. Run this after `bin/install-contracts.sh` to wire a dependency's API into your service.

### `/sql-migration`

Guides authoring of Liquibase or Flyway migrations aligned with the current spec. Reads schema analysis from the change summary and produces migration files that match the intended schema state.

---

## `bin/` tools

**`bin/jkit`** is the Java-pipeline Rust CLI. It reads raw project files and outputs compact JSON — no prose, no color, machine-readable by default. Use `--pretty` for human-readable output during development.

**`bin/kit`** is the language-agnostic companion CLI used by skills that aren't Java-specific (plan/plugin state, scenario sync/skip, contract publish).

**`bin/codeskel`** is a polyglot project scanner used by the contract-generation flow.

**`bin/install-contracts.sh`** installs upstream service contract plugins listed in `.claude/settings.json` as Claude plugin dependencies, making their skills and domain docs available locally.

Pom-fragment installation is now handled by the `jkit pom` subcommand (see `docs/jkit-pom-prd.md`). The previous `bin/pom-add.sh` shell script has been removed.

---

## External tooling

Some skills shell out to third-party tools that must be on `PATH`:

| Tool | Used by | Install |
|---|---|---|
| `openapi-generator-cli` | `generate-feign` (OpenAPI → Feign Java client) | `npm i -g @openapitools/openapi-generator-cli` or `brew install openapi-generator` |
| `mvn` | `java-tdd`, `java-verify`, `scenario-tdd`, `publish-contract` (smart-doc) | Standard Maven distribution |
| `docker compose` / `podman compose` | `scenario-tdd` (Spring Boot < 3.1 integration tests) | Docker Desktop, Docker Engine, or Podman |
| `psql` (or other DB client) | `sql-migration` (live-schema introspection) | `brew install postgresql` / distro package |

---

## CLI reference

### `jkit` subcommands

| Subcommand | Purpose |
|---|---|
| `jkit pom prereqs --profile <name> [--apply]` | Install a static profile of pom fragments (`testcontainers`, `compose`, `jacoco`, `quality`, `smart-doc`) |
| `jkit pom add-dep --group-id … --artifact-id … --version … [--apply]` | Add a single dependency to `<dependencies>` |
| `jkit coverage <jacoco.xml> [--summary] [--min-score N] [--top-k N] [--iteration-state PATH]` | Parse JaCoCo XML and output prioritised coverage gaps |
| `jkit scenarios prereqs [--apply]` | Detect Spring Boot version, install test deps, resolve runtime, ensure compose template |
| `jkit scenarios gap [<domain> \| --run <dir>]` | List scenarios in `test-scenarios.yaml` lacking a matching JUnit test method |
| `jkit migration diff --run <dir>` | Compute the schema delta and surface warnings |
| `jkit migration place --run <dir> --feature <slug>` | Move an approved SQL file into the Flyway directory with a freshly-computed NNN |
| `jkit contract service-meta` | Read-only: returns the metadata the contract skill needs |
| `jkit contract stage --service … --interview … --domains …` | Generate the contract bundle in `.jkit/contract-stage/<service>/` |

### `kit` subcommands

| Subcommand | Purpose |
|---|---|
| `kit plan-status [--run <dir>]` | Report current jkit plan/run state as JSON |
| `kit plugin-status <plugin-name>` | Report install state of a Claude Code plugin |
| `kit scenarios sync <domain>` | Derive required scenarios from `api-spec.yaml`; append-only into `test-scenarios.yaml` |
| `kit scenarios skip --run <dir> <domain> <id>` | Record a per-run scenario skip |
| `kit contract publish --service … [--confirmed] [--no-commit]` | Push a pre-staged contract bundle and update the marketplace |

### `codeskel` subcommands

| Subcommand | Purpose |
|---|---|
| `codeskel scan <project-root>` | Analyse project, output class/method signatures + Javadoc metadata to a cache |
| `codeskel get <cache-path> [--path FILE \| --index N \| --deps FILE \| --refs FILE]` | Query individual files or dependency edges from the cache |
| `codeskel rescan` / `codeskel next` / `codeskel pom` | Re-analyse files, advance the scan cursor, extract Maven metadata |

All subcommands output compact JSON to stdout. Most accept `--pretty` for formatted output.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Fatal error (file not found, parse failure) |
| 2 | Partial success with warnings |

---

## Repo layout

```
bin/        # jkit CLI binary (pre-built, polyglot wrapper) + helper scripts
docs/       # PRDs, design specs, Java coding standards
hooks/      # Claude Code hooks and project context injection
reference/  # Author-facing reference docs (not shipped with the plugin)
skills/     # Claude skill definitions (one directory per skill)
templates/  # Docker Compose templates, pom fragments, env file templates
```

---

## Contributing

Clone the repo and work directly against `main`. Skills live in `skills/<name>/SKILL.md` — each file is a self-contained skill definition consumed by Claude Code. The `bin/jkit` binary is pre-built from Rust source described in `docs/jkit-cli-prd.md`; rebuild with `cargo build --release` and replace the platform binary in `bin/`.

Commit prefix conventions are required — the post-commit hook uses the `(impl):` scope to move processed change files from `docs/changes/pending/` to `docs/changes/done/`:

| Prefix | When to use |
|---|---|
| `docs(spec):` or `docs(<domain>):` | Spec change in `docs/domains/` |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |
