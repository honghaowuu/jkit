# jkit — Iteration 1: Foundation

**Date:** 2026-04-21
**Status:** Draft
**Iteration:** 1 of 4

---

## Overview

Establishes the plugin skeleton: registration, hooks, CLI wrapper, templates, and command files. No skills are implemented in this iteration. All subsequent iterations depend on this foundation.

**Changes from the original design:**
- Removes `migrate-project` and `comment` (handled by the `docflow` plugin)
- Renames `publishing-service-contract` → `publish-contract`
- Adds `/java-verify` slash command
- Fixes hook architecture: polyglot dispatcher, proper `matcher` field, platform detection

---

## Deliverables

| File | Action | Purpose |
|------|--------|---------|
| `.claude-plugin/plugin.json` | Update | Plugin registration |
| `hooks/hooks.json` | Create | Hook registration with matcher |
| `hooks/run-hook.cmd` | Create | Polyglot dispatcher (Windows + Unix) |
| `hooks/session-start` | Create | direnv setup + jkit CLI validation |
| `hooks/post-commit-sync.sh` | Create | Updates `.spec-sync` after impl commits |
| `bin/jkit` | Create | Polyglot CLI wrapper |
| `commands/spec-delta.md` | Update | Trigger spec-delta skill |
| `commands/java-verify.md` | Create | Trigger java-verify skill (standalone re-runs + automatic from java-tdd) |
| `commands/contract-testing.md` | Create | Trigger contract-testing skill (human-initiated per domain) |
| `commands/publish-contract.md` | Update | Trigger publish-contract skill |
| `templates/CLAUDE.md` | Create | Project workflow conventions |
| `templates/envrc` | Create | direnv template |
| `templates/example.env` | Create | Env var template |
| `templates/docker-compose.yml` | Create | Local dev dependencies |
| `templates/docker-compose.test.yml` | Create | Legacy SB test environment |
| `templates/pom-fragments/jacoco.xml` | Create | JaCoCo plugin fragment |
| `templates/pom-fragments/quality.xml` | Create | Checkstyle + PMD + SpotBugs |
| `templates/pom-fragments/springdoc.xml` | Create | springdoc-openapi fragment |
| `templates/pom-fragments/testcontainers.xml` | Create | Testcontainers + RestAssured + WireMock |
| `docs/java-coding-standards.md` | Create | Java coding rules (loaded by code-writing skills) |
| `reference/jkit.md` | Create | CLI reference (author aid, not shipped) |

---

## Plugin Registration

### `.claude-plugin/plugin.json`

```json
{
  "name": "jkit",
  "description": "Spec-driven development workflow for Java/Spring Boot SaaS microservice teams — TDD, coverage, contract testing, service contract publishing",
  "version": "0.2.0",
  "author": { "name": "honghaowu" },
  "license": "UNLICENSED",
  "keywords": ["java", "spring-boot", "microservice", "tdd", "contract-testing"],
  "skills": [
    { "name": "spec-delta",        "path": "skills/spec-delta" },
    { "name": "java-tdd",          "path": "skills/java-tdd" },
    { "name": "java-verify",       "path": "skills/java-verify" },
    { "name": "contract-testing",  "path": "skills/contract-testing" },
    { "name": "publish-contract",  "path": "skills/publish-contract" }
  ],
  "hooks": "hooks/hooks.json",
  "commands": [
    { "name": "spec-delta",        "path": "commands/spec-delta.md" },
    { "name": "java-verify",       "path": "commands/java-verify.md" },
    { "name": "contract-testing",  "path": "commands/contract-testing.md" },
    { "name": "publish-contract",  "path": "commands/publish-contract.md" }
  ]
}
```

---

## Hooks

### Architecture

jkit uses two hooks:

1. **`SessionStart`** — direnv setup + jkit CLI validation. Outputs `{}` with no context payload. Session context injection is fully delegated to superpowers' `SessionStart` hook.
2. **`post-commit`** — updates `.spec-sync` after implementation commits via amend.

The `SessionStart` hook routes through `run-hook.cmd`, a polyglot dispatcher that works on Windows and Unix from a single file.

### `hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  },
  "post-commit": "hooks/post-commit-sync.sh"
}
```

**`matcher` field:** Fires on `startup` (fresh session), `clear` (/clear command), and `compact` (/compact command) — any time the agent context is reset.

### `hooks/run-hook.cmd` (polyglot dispatcher)

Extensionless to prevent Claude Code from auto-prepending `bash` on Windows. The file is valid as both Windows CMD batch and Unix bash.

```
: << 'CMDBLOCK'
@echo off
setlocal

:: Try bash on PATH first
where bash >nul 2>&1 && (
    for /f "tokens=*" %%B in ('where bash 2^>nul') do (
        "%%B" "%~dp0%1" %2 %3 %4 %5
        exit /b %ERRORLEVEL%
    )
)
:: Git for Windows fallback
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%~dp0%1" %2 %3 %4 %5
    exit /b %ERRORLEVEL%
)
:: No bash found — exit silently (plugin continues to function)
echo {}
exit /b 0
CMDBLOCK
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "$SCRIPT_DIR/$1" "${@:2}"
```

**Fallback behavior:** If no bash is found on Windows, exits silently with code 0. The plugin continues to function — hook output is skipped for that session.

### `hooks/session-start` (bash, called by run-hook.cmd)

```bash
#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Install direnv if missing
if ! command -v direnv &>/dev/null; then
  echo "jkit: direnv not found — installing..." >&2
  curl -sfL https://direnv.net/install.sh | bash 2>/dev/null \
    || echo "jkit: direnv install failed. Install manually: https://direnv.net" >&2
fi

# 2. Allow .envrc (idempotent — keyed by .envrc hash, silent no-op when already allowed)
if command -v direnv &>/dev/null && [ -f ".envrc" ]; then
  direnv allow . 2>/dev/null || true
fi

# 3. Validate jkit CLI
if [ ! -x "${PLUGIN_ROOT}/bin/jkit" ]; then
  echo "jkit: bin/jkit missing or not executable. Run: chmod +x ~/.claude/plugins/jkit/bin/*" >&2
fi

printf '{}\n'
exit 0
```

### `hooks/post-commit-sync.sh`

Updates `.spec-sync` by amending the implementation commit — no extra commit appears in history.

```bash
#!/usr/bin/env bash
set -euo pipefail

MSG=$(git log -1 --pretty=%s)

if echo "$MSG" | grep -qE '^(feat|fix|chore)\(impl\):'; then
  mkdir -p docs
  git rev-parse HEAD > docs/.spec-sync || {
    echo "ERROR: Failed to write docs/.spec-sync" >&2; exit 1
  }
  git add docs/.spec-sync
  if ! git diff --cached --quiet; then
    git commit --amend --no-edit || {
      echo "ERROR: Failed to amend commit." >&2
      echo "Recover: run 'git commit --amend --no-edit' or 'git reset HEAD docs/.spec-sync'" >&2
      exit 1
    }
  fi
fi
```

**Re-entrancy:** The second post-commit run (triggered by amend) finds `.spec-sync` already at HEAD → `git diff --cached --quiet` returns true → no second amend. Safe.

---

## CLI Wrapper

### `bin/jkit` (polyglot, extensionless)

Selects the correct OS/arch binary. Skills call `bin/jkit` only — never the OS-specific binary directly. No OS detection required in skill code.

```
: << 'CMDBLOCK'
@echo off
"%~dp0jkit-windows-x86_64.exe" %*
exit /b %ERRORLEVEL%
CMDBLOCK
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
exec "$SCRIPT_DIR/jkit-${OS}-${ARCH}" "$@"
```

Bundled binaries: `jkit-linux-x86_64`, `jkit-macos-aarch64`, `jkit-windows-x86_64.exe`. Pre-built; not built by this iteration.

---

## Commands

One-sentence trigger files. No logic in command files.

- `commands/spec-delta.md`: `Invoke the spec-delta skill.`
- `commands/java-verify.md`: `Invoke the java-verify skill.`
- `commands/contract-testing.md`: `Invoke the contract-testing skill.`
- `commands/publish-contract.md`: `Invoke the publish-contract skill.`

**Note on `/java-verify`:** This command is for standalone use — ad-hoc re-runs or when the developer wants to verify integration tests independently. `java-tdd` also invokes `java-verify` automatically as its final step. Both paths are valid and supported.

---

## Templates

### `templates/CLAUDE.md`

Project workflow conventions. **No coding rules** — those live in `docs/java-coding-standards.md`.

```markdown
# Project Conventions

## Commit Prefixes

| Prefix | Meaning |
|--------|---------|
| `docs(spec):` or `docs(<domain>):` | Spec change (triggers spec-delta) |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |

The `(impl):` scope triggers the post-commit hook to update `docs/.spec-sync`.

## Environment

Single `application.yml` using `${ENV_VAR:default}`. No `application-{profile}.yml` files.

- Local: `direnv` auto-loads `.env/local.env` on project entry
- Other envs: `JKIT_ENV=test direnv exec . <cmd>`

## Workflow

1. Edit `docs/domains/` spec files
2. `git commit -m "docs(<domain>): <what changed>"`
3. `/spec-delta` → review artifacts → plan approved → java-tdd runs
4. `/java-verify` (also invoked by java-tdd automatically)
5. `/publish-contract` after API changes

## jkit Run Artifacts

Each spec-delta run creates `docs/jkit/YYYY-MM-DD-<feature>/`:
- `change-summary.md` — review before planning
- `migration-preview.md` — review before SQL generation
- `migration/` — generated SQL (moved to `src/main/resources/db/migration/` in final commit)
- `plan.md` — implementation plan (review before java-tdd)
- `contract-tests.md` — review before test code generation
```

### `templates/envrc`

```bash
dotenv ".env/${JKIT_ENV:-local}.env"
```

### `templates/example.env`

```bash
# Required environment variables for this service.
# Copy to .env/local.env (gitignored) and fill in values.
# Test: copy to .env/test.env and configure test infrastructure.

SERVER_PORT=8080

# Database (example — add actual vars after running spec-delta)
DATABASE_URL=
```

### `templates/docker-compose.yml`

Local dev dependencies. At minimum: PostgreSQL on `${DB_PORT:-5432}` with `${DB_NAME}`, `${DB_USER}`, `${DB_PASSWORD}` env vars, persistent volume.

### `templates/docker-compose.test.yml`

Legacy Spring Boot (< 3.1) test environment. Contains: PostgreSQL + WireMock sidecar + app container (built from `Dockerfile`). App depends on postgres + wiremock. All services connected on a single network. Exposes app on port 8080, WireMock on 8089.

### `templates/pom-fragments/jacoco.xml`

JaCoCo Maven plugin (`0.8.11`). Two executions: `prepare-agent` (default phase) and `report` (test phase). Generates XML report to `target/site/jacoco/jacoco.xml`.

### `templates/pom-fragments/quality.xml`

Three plugins (all with `failOnError`/`failOnViolation = true`):
- Checkstyle `3.3.1` — `google_checks.xml`, `consoleOutput = true`
- PMD `3.21.0` — `printFailingErrors = true`
- SpotBugs `4.8.3.1` — `effort = Max`, `threshold = Medium`

### `templates/pom-fragments/springdoc.xml`

`springdoc-openapi-starter-webmvc-ui 2.3.0` dependency. Generates OpenAPI spec at `/v3/api-docs` when app is running.

### `templates/pom-fragments/testcontainers.xml`

Testcontainers BOM `1.19.3` (in `<dependencyManagement>`), plus test-scoped dependencies:
- `testcontainers:junit-jupiter`
- `testcontainers:postgresql`
- `spring-boot-testcontainers`
- `rest-assured 5.4.0`
- `wiremock-standalone 3.3.1`

---

## Plugin Docs

### `docs/java-coding-standards.md`

Loaded at step 0 by `java-tdd`, `java-verify`, and `contract-testing`. Content: naming conventions (classes PascalCase, methods camelCase, test methods `methodName_scenario`), Spring Boot structure (controllers in `api/` — no business logic, services in service/ — no HTTP concerns), testing rules (unit tests mock all deps, integration tests use real infra, one behavior per test), error handling (RFC 7807 problem details), JPA rules (UUID PKs, Flyway migrations `V<YYYYMMDD>_NNN__<desc>.sql`), logging (SLF4J, no PII/secrets).

### `reference/jkit.md`

CLI reference maintained during development. **Excluded from plugin distribution** — author aid only.

Structure:
- Subcommand table: `jkit skel`, `jkit skel domains <root>`, `jkit coverage <jacoco.xml>`, `jkit scan spring`, `jkit scan contract`, `jkit scan schema`, `jkit scan project`
- Per-subcommand: flags, output format (JSON), field descriptions
- Exit codes: 0 = success, 1 = fatal, 2 = partial with warnings
- JSON output examples for each subcommand

---

## Commit Convention

This iteration is delivered as a single commit:

```
chore: foundation — plugin registration, hooks, templates, CLI wrapper
```
