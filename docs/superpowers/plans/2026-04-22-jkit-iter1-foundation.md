# jkit Iteration 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the plugin skeleton — update plugin registration, install the hooks system with polyglot dispatcher, create the CLI wrapper, and add all templates needed by downstream iterations.

**Architecture:** A polyglot hook dispatcher (`run-hook.cmd`) works on both Windows and Unix from a single file. The `session-start` hook detects jkit-managed projects via `.jkit/spec-sync` and conditionally injects workflow context into Claude's session. The `bin/jkit` wrapper selects the correct pre-built OS/arch binary. Templates provide copy-paste starting points for microservice teams.

**Tech Stack:** Bash, JSON, Claude Code plugin system (plugin.json, hooks.json), Maven XML fragments

---

## File Map

| File | Action |
|------|--------|
| `.claude-plugin/plugin.json` | Update (v0.1.0 → v0.2.0, replace skills list, remove commands block) |
| `hooks/hooks.json` | Update (add SessionStart hook block with matcher) |
| `hooks/post-commit-sync.sh` | Update (fix path: `docs/.spec-sync` → `.jkit/spec-sync`) |
| `hooks/run-hook.cmd` | Create (polyglot Windows CMD + Unix bash dispatcher) |
| `hooks/session-start` | Create (bash: direnv setup, jkit validate, conditional context injection) |
| `hooks/jkit-context.md` | Create (workflow context injected for jkit-managed projects) |
| `bin/jkit` | Create (polyglot OS/arch binary wrapper) |
| `templates/envrc` | Create |
| `templates/example.env` | Update (simplify to DATABASE_URL format per spec) |
| `templates/docker-compose.test.yml` | Update (add JaCoCo TCP server agent, volumes, port 6300, network) |
| `templates/pom-fragments/jacoco.xml` | Create (5-execution JaCoCo plugin config) |
| `templates/pom-fragments/quality.xml` | Create (Checkstyle + PMD + SpotBugs) |
| `reference/jkit.md` | Create (CLI reference — author aid, not shipped) |

---

### Task 1: Update .claude-plugin/plugin.json

**Files:**
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Overwrite plugin.json**

Write `.claude-plugin/plugin.json`:

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

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('OK')"
```

Expected: `OK`

---

### Task 2: Update hooks/hooks.json

**Files:**
- Modify: `hooks/hooks.json`

The `matcher` field fires on `startup` (fresh session), `clear` (/clear), and `compact` (/compact) — any time agent context resets.

- [ ] **Step 1: Overwrite hooks/hooks.json**

Write `hooks/hooks.json`:

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

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('hooks/hooks.json')); print('OK')"
```

Expected: `OK`

---

### Task 3: Fix hooks/post-commit-sync.sh

**Files:**
- Modify: `hooks/post-commit-sync.sh`

Current state writes to `docs/.spec-sync`. Spec requires `.jkit/spec-sync`. Also update the error recovery message to match.

- [ ] **Step 1: Overwrite hooks/post-commit-sync.sh**

Write `hooks/post-commit-sync.sh`:

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

- [ ] **Step 2: Check with shellcheck**

```bash
shellcheck hooks/post-commit-sync.sh
```

Expected: no output (no warnings or errors)

---

### Task 4: Create hooks/run-hook.cmd

**Files:**
- Create: `hooks/run-hook.cmd`

This file is extensionless to prevent Claude Code from auto-prepending `bash` on Windows. It is valid as both Windows CMD batch and Unix bash simultaneously. The polyglot trick: CMD sees `: << 'CMDBLOCK'` as a label (`:`) and runs the CMD block, skipping to `CMDBLOCK`. Bash treats `: << 'CMDBLOCK'` as a discarded heredoc and runs the bash section below.

- [ ] **Step 1: Write hooks/run-hook.cmd**

Write `hooks/run-hook.cmd` with this exact content:

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

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/run-hook.cmd
```

- [ ] **Step 3: Verify bash syntax is clean**

```bash
bash -n hooks/run-hook.cmd
```

Expected: no output (no syntax errors in the bash portion)

---

### Task 5: Create hooks/session-start

**Files:**
- Create: `hooks/session-start`

The conditional injection logic (Step 4 in the script) is the key design: if `.jkit/spec-sync` does not exist, output `{}` and exit. Only inject `jkit-context.md` for confirmed jkit-managed projects.

- [ ] **Step 1: Write hooks/session-start**

Write `hooks/session-start`:

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

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/session-start
```

- [ ] **Step 3: Check with shellcheck**

```bash
shellcheck hooks/session-start
```

Expected: no output

- [ ] **Step 4: Smoke test — non-jkit project outputs {}**

```bash
cd /tmp && bash /workspaces/jkit/hooks/session-start
```

Expected output: `{}`

---

### Task 6: Create hooks/jkit-context.md

**Files:**
- Create: `hooks/jkit-context.md`

This file is injected as `additionalContext` at session start for jkit-managed projects. Kept brief — full skill bodies lazy-load on demand.

- [ ] **Step 1: Write hooks/jkit-context.md**

Write `hooks/jkit-context.md`:

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

---

### Task 7: Create bin/jkit

**Files:**
- Create: `bin/jkit`

Same polyglot pattern as `run-hook.cmd`. Skills call `bin/jkit` only — never the OS-specific binary directly. Pre-built binaries (`jkit-linux-x86_64`, `jkit-macos-aarch64`, `jkit-windows-x86_64.exe`) are not created in this iteration.

- [ ] **Step 1: Create bin/ directory**

```bash
mkdir -p bin
```

- [ ] **Step 2: Write bin/jkit**

Write `bin/jkit` with this exact content:

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

- [ ] **Step 3: Make executable**

```bash
chmod +x bin/jkit
```

- [ ] **Step 4: Verify bash syntax**

```bash
bash -n bin/jkit
```

Expected: no output

---

### Task 8: Create templates/envrc

**Files:**
- Create: `templates/envrc`

- [ ] **Step 1: Write templates/envrc**

Write `templates/envrc`:

```bash
dotenv ".env/${JKIT_ENV:-local}.env"
```

---

### Task 9: Update templates/example.env

**Files:**
- Modify: `templates/example.env`

Current state has granular `DB_HOST`/`DB_PORT`/`DB_NAME`/`DB_USER`/`DB_PASSWORD` vars. Spec uses `DATABASE_URL` (JDBC connection string). Replace entirely.

- [ ] **Step 1: Overwrite templates/example.env**

Write `templates/example.env`:

```bash
# Required environment variables for this service.
# Copy to .env/local.env (gitignored) and fill in values.
# Test: copy to .env/test.env and configure test infrastructure.

SERVER_PORT=8080

# Database (example — add actual vars after running spec-delta)
DATABASE_URL=
```

---

### Task 10: Update templates/docker-compose.test.yml

**Files:**
- Modify: `templates/docker-compose.test.yml`

Current state is missing the JaCoCo TCP server agent, `target/jacoco` volume mount, port 6300, and an explicit network connecting all services. These are required for the legacy SB < 3.1 integration coverage path.

- [ ] **Step 1: Overwrite templates/docker-compose.test.yml**

Write `templates/docker-compose.test.yml`:

```yaml
version: '3.8'

# Legacy Spring Boot (< 3.1) test environment.
# Usage: docker compose -f docker-compose.test.yml up -d
# Then: JKIT_ENV=test direnv exec . mvn test -Dtest=*IntegrationTest

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ${DB_NAME:-test_db}
      POSTGRES_USER: ${DB_USER:-test_user}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-test_password}
    networks:
      - test-net

  wiremock:
    image: wiremock/wiremock:3.3.1
    ports:
      - "8089:8080"
    volumes:
      - ./src/test/resources/wiremock:/home/wiremock
    networks:
      - test-net

  app:
    build: .
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      EXTERNAL_SERVICE_BASE_URL: http://wiremock:8080
      JAVA_OPTS: >-
        -javaagent:/jacoco/jacocoagent.jar=output=tcpserver,port=6300,address=*
    ports:
      - "8080:8080"
      - "6300:6300"
    volumes:
      - ./target/jacoco:/jacoco
    depends_on:
      - postgres
      - wiremock
    networks:
      - test-net

networks:
  test-net:
```

---

### Task 11: Create templates/pom-fragments/jacoco.xml

**Files:**
- Create: `templates/pom-fragments/jacoco.xml`

Five executions cover both unit and integration test paths. Spring Boot 3.1+ uses `prepare-agent-integration` directly (no TCP dump needed). The legacy docker-compose path uses the TCP dump execution to pull coverage from port 6300.

- [ ] **Step 1: Write templates/pom-fragments/jacoco.xml**

Write `templates/pom-fragments/jacoco.xml`:

```xml
<!-- JaCoCo Maven plugin — add inside <build><plugins> -->
<!-- Five executions: unit + integration coverage (SB 3.1+ Testcontainers and legacy docker-compose paths) -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <!-- Unit test instrumentation: sets argLine for Surefire -->
        <execution>
            <id>prepare-agent</id>
            <phase>initialize</phase>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <!-- Integration test instrumentation: sets argLine for Failsafe -->
        <!-- SB 3.1+ Testcontainers: instruments the same JVM directly (no TCP needed) -->
        <!-- Legacy docker-compose: instruments the app container JVM via mounted agent -->
        <execution>
            <id>prepare-agent-integration</id>
            <phase>pre-integration-test</phase>
            <goals><goal>prepare-agent-integration</goal></goals>
        </execution>
        <!-- Legacy docker-compose path only: dump coverage from TCP server after test run -->
        <!-- No-op if TCP server not running (SB 3.1+ Testcontainers path) -->
        <execution>
            <id>dump</id>
            <phase>post-integration-test</phase>
            <goals><goal>dump</goal></goals>
            <configuration>
                <address>localhost</address>
                <port>6300</port>
                <reset>true</reset>
                <destFile>${project.build.directory}/jacoco-it.exec</destFile>
            </configuration>
        </execution>
        <!-- Merge jacoco.exec + jacoco-it.exec → jacoco-merged.exec -->
        <execution>
            <id>merge</id>
            <phase>post-integration-test</phase>
            <goals><goal>merge</goal></goals>
            <configuration>
                <fileSets>
                    <fileSet>
                        <directory>${project.build.directory}</directory>
                        <includes>
                            <include>jacoco.exec</include>
                            <include>jacoco-it.exec</include>
                        </includes>
                    </fileSet>
                </fileSets>
                <destFile>${project.build.directory}/jacoco-merged.exec</destFile>
            </configuration>
        </execution>
        <!-- Generate XML report from merged exec → used by jkit coverage -->
        <execution>
            <id>report</id>
            <phase>verify</phase>
            <goals><goal>report</goal></goals>
            <configuration>
                <dataFile>${project.build.directory}/jacoco-merged.exec</dataFile>
                <outputDirectory>${project.reporting.outputDirectory}/jacoco</outputDirectory>
            </configuration>
        </execution>
    </executions>
</plugin>
```

- [ ] **Step 2: Validate XML**

```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('templates/pom-fragments/jacoco.xml'); print('OK')"
```

Expected: `OK`

---

### Task 12: Create templates/pom-fragments/quality.xml

**Files:**
- Create: `templates/pom-fragments/quality.xml`

All three plugins fail the build on violations (`failOnError`/`failOnViolation = true`).

- [ ] **Step 1: Write templates/pom-fragments/quality.xml**

Write `templates/pom-fragments/quality.xml`:

```xml
<!-- Quality plugins — add inside <build><plugins> -->
<!-- All three configured to fail the build on violations -->

<!-- Checkstyle: enforces Google Java style -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
    <version>3.3.1</version>
    <configuration>
        <configLocation>google_checks.xml</configLocation>
        <consoleOutput>true</consoleOutput>
        <failOnError>true</failOnError>
    </configuration>
    <executions>
        <execution>
            <id>checkstyle</id>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>

<!-- PMD: static analysis for common defect patterns -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-pmd-plugin</artifactId>
    <version>3.21.0</version>
    <configuration>
        <printFailingErrors>true</printFailingErrors>
        <failOnViolation>true</failOnViolation>
    </configuration>
    <executions>
        <execution>
            <id>pmd</id>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>

<!-- SpotBugs: bytecode analysis for bug patterns -->
<plugin>
    <groupId>com.github.spotbugs</groupId>
    <artifactId>spotbugs-maven-plugin</artifactId>
    <version>4.8.3.1</version>
    <configuration>
        <effort>Max</effort>
        <threshold>Medium</threshold>
        <failOnError>true</failOnError>
    </configuration>
    <executions>
        <execution>
            <id>spotbugs</id>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
```

- [ ] **Step 2: Validate XML**

```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('templates/pom-fragments/quality.xml'); print('OK')"
```

Expected: `OK`

---

### Task 13: Create reference/jkit.md

**Files:**
- Create: `reference/jkit.md`

Author aid only — excluded from plugin distribution. Documents the pre-built `bin/jkit` binary's interface.

- [ ] **Step 1: Write reference/jkit.md**

Write `reference/jkit.md`:

````markdown
# jkit CLI Reference

> Author aid — not shipped with the plugin. Documents the pre-built `bin/jkit` binary.

## Subcommands

| Subcommand | Purpose |
|------------|---------|
| `jkit skel <path>` | Scan Java source under `<path>`, output JSON array of class/method signatures |
| `jkit skel domains <root>` | Scan all domain packages under `<root>` |
| `jkit coverage <jacoco.xml>` | Analyze JaCoCo XML report, output coverage gaps |
| `jkit coverage --api <domains-dir> <test-src-dir>` | Compare declared API endpoints vs RestAssured-tested endpoints |
| `jkit scan spring` | Scan Spring Boot project structure |
| `jkit scan contract` | Scan for contract artifacts |
| `jkit scan schema` | Scan for schema migration files |
| `jkit scan project` | Full project scan |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Fatal error |
| 2 | Partial success with warnings |

---

## `jkit skel <path>`

Scans Java source under `<path>`, outputs JSON array of class/method signatures. Used by `publish-contract` for Javadoc quality checks and by `scenario-gap` for test method discovery.

**Output format:**

```json
[
  {
    "class": "com.example.InvoiceController",
    "annotation": "@RestController",
    "methods": [
      {
        "name": "createInvoice",
        "signature": "ResponseEntity<InvoiceResponse> createInvoice(InvoiceRequest request)",
        "has_docstring": true,
        "docstring_text": "Creates a new invoice for the given tenant."
      },
      {
        "name": "getInvoice",
        "signature": "ResponseEntity<InvoiceResponse> getInvoice(UUID id)",
        "has_docstring": false
      }
    ]
  }
]
```

**Notes:**
- `has_docstring`: true if the method has a Javadoc comment
- `docstring_text`: only present when `has_docstring` is true
- A method with `has_docstring: false` or empty `docstring_text` fails the Javadoc quality check in `publish-contract`

---

## `jkit coverage <jacoco.xml>`

Analyzes a JaCoCo XML report for coverage gaps.

**Flags:**
- `--summary` — output a one-line summary instead of full method list
- `--min-score <float>` — filter to methods below this coverage score (0.0–1.0)

**Output format:**

```json
{
  "total_methods": 42,
  "covered_methods": 38,
  "gaps": [
    {
      "class": "com.example.InvoiceService",
      "method": "validateBulkInvoice",
      "branch_coverage": 0.5,
      "line_coverage": 0.6
    }
  ]
}
```

---

## `jkit coverage --api <domains-dir> <test-src-dir>`

Reads all `api-spec.yaml` files under `<domains-dir>`, scans `<test-src-dir>` for RestAssured URL patterns, outputs endpoint coverage gaps.

**Output format:**

```json
{
  "endpoints_declared": 12,
  "endpoints_tested": 10,
  "gaps": [
    {
      "method": "POST",
      "path": "/invoices/bulk",
      "declared_in": "docs/domains/billing/api-spec.yaml"
    }
  ]
}
```
````

---

### Task 14: Commit Iteration 1

- [ ] **Step 1: Stage all files**

```bash
git add .claude-plugin/plugin.json
git add hooks/hooks.json hooks/run-hook.cmd hooks/session-start hooks/jkit-context.md hooks/post-commit-sync.sh
git add bin/jkit
git add templates/envrc templates/example.env templates/docker-compose.test.yml
git add templates/pom-fragments/jacoco.xml templates/pom-fragments/quality.xml
git add reference/jkit.md
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: foundation — plugin registration, hooks, templates, CLI wrapper"
```

Expected: commit succeeds, post-commit hook runs and exits cleanly (commit message does not match `(impl):` pattern so no amend occurs).
