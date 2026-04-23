# jkit

Spec-driven development for Java/Spring Boot microservice teams.

`jkit` is a Claude Code plugin that brings a structured TDD and contract workflow to AI-assisted Java development. It combines a set of Claude skills covering the full development cycle with a Rust CLI (`bin/jkit`) that gives those skills token-efficient, machine-readable views of your Java project — so Claude makes decisions from compact JSON summaries rather than raw XML and source files.

**What's included:**

- 8 Claude skills covering the full dev cycle: spec delta, unit TDD, integration test TDD, coverage gating, contract publishing, and Feign client generation
- `bin/jkit` — a Rust CLI for Java project analysis (class skeleton scan, JaCoCo coverage gaps, Spring component scan, schema migration scan)
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

### `/scenario-gap`

Identifies integration test gaps by comparing declared API endpoints (from `api-spec.yaml` files) against RestAssured tests already in the test source tree. Called internally by `/spec-delta` but can be run standalone against a single domain.

### `/sql-migration`

Guides authoring of Liquibase or Flyway migrations aligned with the current spec. Reads schema analysis from the change summary and produces migration files that match the intended schema state.

---

## `bin/` tools

**`bin/jkit`** is the Rust CLI that powers the skills' project analysis. It reads raw project files and outputs compact JSON — no prose, no color, machine-readable by default. Use `--pretty` for human-readable output during development.

**`bin/install-contracts.sh`** installs upstream service contract plugins listed in `.claude/settings.json` as Claude plugin dependencies, making their skills and domain docs available locally.

**`bin/pom-add.sh`** injects standard pom fragments (JaCoCo, Testcontainers, quality tools) into `pom.xml` without requiring template file reads.

---

## CLI reference

### Subcommands

| Subcommand | Purpose |
|---|---|
| `jkit skel <path>` | Scan Java source, output class/method signatures with Javadoc metadata |
| `jkit skel domains <root>` | Detect logical subdomains by package structure and annotation patterns |
| `jkit coverage <jacoco.xml>` | Parse JaCoCo XML and output prioritised coverage gaps |
| `jkit coverage --api <domains-dir> <test-src-dir>` | Compare declared API endpoints vs RestAssured-tested endpoints |
| `jkit scan spring` | Identify Spring components relevant to integration testing (repositories, Feign clients, Kafka, Redis) |
| `jkit scan contract` | Identify exposed endpoints and consumed Feign clients |
| `jkit scan schema` | Parse Liquibase/Flyway changelogs and output applied/pending migrations |
| `jkit scan project` | Inspect `pom.xml` and test structure for tooling and coverage gaps |

All subcommands output compact JSON to stdout. Use `--output <path>` to write to a file and `--pretty` for formatted output.

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

Commit prefix conventions are required — the post-commit hook uses the `(impl):` scope to update `.jkit/spec-sync`:

| Prefix | When to use |
|---|---|
| `docs(spec):` or `docs(<domain>):` | Spec change in `docs/domains/` |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |
