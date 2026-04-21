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
| `hooks/session-start` | Create | direnv setup + jkit CLI validation + conditional context injection |
| `hooks/post-commit-sync.sh` | Create | Updates `.spec-sync` after impl commits |
| `hooks/jkit-context.md` | Create | Workflow context injected by session-start (jkit-managed projects only) |
| `bin/jkit` | Create | Polyglot CLI wrapper |
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
  "keywords": ["java", "spring-boot", "microservice", "tdd", "scenario-tdd"],
  "skills": [
    { "name": "spec-delta",        "path": "skills/spec-delta" },
    { "name": "sql-migration",     "path": "skills/sql-migration" },
    { "name": "java-tdd",          "path": "skills/java-tdd" },
    { "name": "scenario-gap",      "path": "skills/scenario-gap" },
    { "name": "scenario-tdd",      "path": "skills/scenario-tdd" },
    { "name": "java-verify",       "path": "skills/java-verify" },
    { "name": "publish-contract",  "path": "skills/publish-contract" }
  ],
  "hooks": "hooks/hooks.json"
}
```

---

## Hooks

### Architecture

jkit uses two hooks:

1. **`SessionStart`** — direnv setup + jkit CLI validation + **conditional context injection**. If `.jkit/spec-sync` exists in the working directory (jkit-managed project), injects `hooks/jkit-context.md` as `additionalContext`. Otherwise outputs `{}`. Platform detection follows the superpowers pattern (Cursor / Claude Code / SDK fallback).
2. **`post-commit`** — updates `.jkit/spec-sync` after implementation commits via amend.

The `SessionStart` hook routes through `run-hook.cmd`, a polyglot dispatcher that works on Windows and Unix from a single file.

**Why conditional injection:** The hook fires for every project when jkit is installed. Injecting workflow context into non-jkit projects would pollute sessions with irrelevant conventions. `.jkit/spec-sync` is the reliable signal that this is a jkit-managed project.

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

# 4. Conditional context injection — only for jkit-managed projects
if [ ! -f ".jkit/spec-sync" ]; then
  printf '{}\n'
  exit 0
fi

CONTEXT=$(cat "${PLUGIN_ROOT}/hooks/jkit-context.md")

# Platform detection (follows superpowers pattern)
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  # Cursor
  printf '{"additional_context": %s}\n' "$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
  # Claude Code
  printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": %s}}\n' \
    "$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
else
  # SDK / fallback
  printf '{"additionalContext": %s}\n' "$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
fi
exit 0
```

### `hooks/jkit-context.md`

Injected as `additionalContext` when `.jkit/spec-sync` is detected. Kept brief — full skill bodies lazy-load on demand.

```markdown
This is a jkit-managed Java/Spring Boot microservice project.

## Commit conventions

| Prefix | When to use |
|--------|-------------|
| `docs(spec):` or `docs(<domain>):` | Spec change in docs/domains/ |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |

The `(impl):` scope triggers the post-commit hook to update `.jkit/spec-sync`.

## Environment

Single `application.yml` using `${ENV_VAR:default}`. No `application-{profile}.yml` files.
- Local dev: `direnv` auto-loads `.env/local.env` when you enter the project directory
- Other envs: `JKIT_ENV=test direnv exec . <cmd>`

## Key skills

- **spec-delta** — compute requirements delta since last implementation → drives full spec-to-commit cycle
- **java-tdd** — TDD implementation with JaCoCo unit coverage gap analysis
- **scenario-gap** — detect unimplemented scenarios per domain from test-scenarios.md; invoked by spec-delta
- **scenario-tdd** — implement missing scenarios via integration TDD: one at a time, RED → GREEN
- **java-verify** — quality gate: mvn verify + merged coverage check + code review handoff
- **publish-contract** — generate 4-level progressive disclosure contract for other services to consume
```

### `hooks/post-commit-sync.sh`

Updates `.spec-sync` by amending the implementation commit — no extra commit appears in history.

```bash
#!/usr/bin/env bash
set -euo pipefail

MSG=$(git log -1 --pretty=%s)

if echo "$MSG" | grep -qE '^(feat|fix|chore)\(impl\):'; then
  mkdir -p .jkit
  git rev-parse HEAD > .jkit/spec-sync || {
    echo "ERROR: Failed to write .jkit/spec-sync" >&2; exit 1
  }
  git add .jkit/spec-sync
  if ! git diff --cached --quiet; then
    git commit --amend --no-edit || {
      echo "ERROR: Failed to amend commit." >&2
      echo "Recover: run 'git commit --amend --no-edit' or 'git reset HEAD .jkit/spec-sync'" >&2
      exit 1
    }
  fi
fi
```

**Re-entrancy:** The second post-commit run (triggered by amend) finds `.jkit/spec-sync` already at HEAD → `git diff --cached --quiet` returns true → no second amend. Safe.

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

## Skill Invocation

Skills are invoked via the Claude Code `Skill` tool — no slash commands. Developers trigger skills by name:
- `spec-delta` — start the implementation loop after spec changes
- `scenario-gap` — detect unimplemented scenarios from test-scenarios.md (invoked by spec-delta)
- `scenario-tdd` — integration TDD per domain from gap list (invoked by java-tdd; also usable standalone)
- `java-verify` — quality gate + code review handoff (invoked by scenario-tdd; also usable standalone)
- `publish-contract` — publish the service contract after API changes

**Pipeline:** `spec-delta → [sql-migration] → java-tdd → scenario-tdd → java-verify → code review`

---

## Templates

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

Legacy Spring Boot (< 3.1) test environment. Contains: PostgreSQL + WireMock sidecar + app container (built from `Dockerfile`). App depends on postgres + wiremock. All services connected on a single network. Exposes app on port 8080, WireMock on 8089, JaCoCo TCP server on port 6300.

App service includes JaCoCo TCP server agent so integration test coverage can be dumped after the test run:
```yaml
environment:
  JAVA_OPTS: >-
    -javaagent:/jacoco/jacocoagent.jar=output=tcpserver,port=6300,address=*
volumes:
  - ./target/jacoco:/jacoco   # jacocoagent.jar mounted from host
ports:
  - "6300:6300"
```

### `templates/pom-fragments/jacoco.xml`

JaCoCo Maven plugin (`0.8.11`). Five executions covering both unit and integration test runs:

| Execution ID | Phase | Goal | Purpose |
|---|---|---|---|
| `prepare-agent` | `initialize` | `prepare-agent` | Instruments unit tests (sets `argLine` for Surefire) |
| `prepare-agent-integration` | `pre-integration-test` | `prepare-agent-integration` | Instruments integration tests (sets `argLine` for Failsafe) |
| `dump` | `post-integration-test` | `dump` | Dumps coverage from JaCoCo TCP server (legacy docker-compose path: `address=localhost`, `port=6300`); no-op if TCP server not running |
| `merge` | `post-integration-test` | `merge` | Merges `jacoco.exec` + `jacoco-it.exec` → `jacoco-merged.exec` |
| `report` | `verify` | `report` | Generates XML report from `jacoco-merged.exec` to `target/site/jacoco/jacoco.xml` |

Spring Boot 3.1+ path: `prepare-agent-integration` instruments the same JVM — no TCP dump needed, merge picks up both exec files automatically. Legacy docker-compose path: TCP dump populates `jacoco-it.exec` before merge.

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

Loaded at step 0 by `java-tdd`, `scenario-tdd`, and `java-verify`. Content: naming conventions (classes PascalCase, methods camelCase, test methods `methodName_scenario`), Spring Boot structure (controllers in `api/` — no business logic, services in service/ — no HTTP concerns), testing rules (unit tests mock all deps, integration tests use real infra, one behavior per test), error handling (RFC 7807 problem details), JPA rules (UUID PKs, Flyway migrations `V<YYYYMMDD>_NNN__<desc>.sql`), logging (SLF4J, no PII/secrets).

### `reference/jkit.md`

CLI reference maintained during development. **Excluded from plugin distribution** — author aid only.

Structure:
- Subcommand table: `jkit skel`, `jkit skel domains <root>`, `jkit coverage <jacoco.xml>`, `jkit coverage --api <domains-dir> <test-src-dir>`, `jkit scan spring`, `jkit scan contract`, `jkit scan schema`, `jkit scan project`
- Per-subcommand: flags, output format (JSON), field descriptions
- `jkit skel <path>`: scans Java source under `<path>`, outputs JSON array of class/method signatures. Each method entry includes `has_docstring` (bool) and `docstring_text` (string, only present when `has_docstring` is true). Used by `publish-contract` for Javadoc quality checks.
- `jkit coverage --api`: reads all `api-spec.yaml` files under `<domains-dir>`, scans `<test-src-dir>` for RestAssured URL patterns, outputs `{ endpoints_declared, endpoints_tested, gaps: [{method, path, declared_in}] }`
- Exit codes: 0 = success, 1 = fatal, 2 = partial with warnings
- JSON output examples for each subcommand

---

## Commit Convention

This iteration is delivered as a single commit:

```
chore: foundation — plugin registration, hooks, templates, CLI wrapper
```
