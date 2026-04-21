# jkit Plugin Implementation Plan [ARCHIVED]

> **ARCHIVED 2026-04-21** — This plan is stale (uses old `codeskel`/`jacoco-filter` tools, missing `java-verify`, includes removed `migrate-project`/`comment` skills). Superseded by per-iteration specs in `docs/superpowers/specs/2026-04-21-jkit-iter*.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the jkit Claude Code plugin — a complete spec-driven development workflow for Java/Spring Boot SaaS microservice teams.

**Architecture:** All deliverables are markdown/config/shell files. Skills (SKILL.md) encode Claude's workflow instructions. Hooks automate `.spec-sync` tracking. Commands expose skills as slash commands. Templates provide project scaffolding. No compiled code except pre-built binaries (already bundled separately).

**Tech Stack:** Claude Code plugin format (plugin.json, SKILL.md, hooks.json), Bash (post-commit hook), XML (Maven pom fragments), YAML (docker-compose), Markdown

**Spec:** `docs/specs/2026-04-08-jkit-design.md`

---

## File Map

| File | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Register skills, hooks, commands (update existing) |
| `hooks/hooks.json` | Register post-commit hook |
| `hooks/post-commit-sync.sh` | Update `.spec-sync` after impl commits |
| `commands/spec-delta.md` | `/spec-delta` slash command |
| `commands/migrate-project.md` | `/migrate-project` slash command |
| `commands/publish-contract.md` | `/publish-contract` slash command |
| `skills/comment/SKILL.md` | Javadoc generation skill |
| `skills/migrate-project/SKILL.md` | Project bootstrapping skill |
| `skills/spec-delta/SKILL.md` | Spec diff → implementation driver |
| `skills/java-tdd/SKILL.md` | TDD + JaCoCo coverage skill |
| `skills/contract-testing/SKILL.md` | API scenario test generation |
| `skills/publishing-service-contract/SKILL.md` | SKILL.md generation for microservices |
| `docs/java-coding-standards.md` | Java coding rules (loaded by code-writing skills) |
| `docs/codeskel-domains-prd.md` | PRD for `codeskel domains` subcommand |
| `templates/CLAUDE.md` | Project workflow conventions template |
| `templates/example.env` | Example env file template |
| `templates/docker-compose.yml` | Local dev dependencies template |
| `templates/docker-compose.test.yml` | Test environment template |
| `templates/pom-fragments/jacoco.xml` | JaCoCo Maven plugin fragment |
| `templates/pom-fragments/springdoc.xml` | springdoc-openapi plugin fragment |
| `templates/pom-fragments/testcontainers.xml` | Testcontainers + RestAssured + WireMock deps |

---

## Task 1: Update plugin.json

**Files:**
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Update plugin.json to register all skills, hooks, and commands**

Replace content with:

```json
{
  "name": "jkit",
  "description": "End-to-end Java SaaS microservice development plugin — spec-driven workflow, TDD, contract testing, migration, and service contract publishing",
  "version": "0.1.0",
  "author": {
    "name": "honghaowu"
  },
  "license": "UNLICENSED",
  "keywords": [
    "java",
    "spring-boot",
    "spring-cloud",
    "microservice",
    "tdd",
    "saas"
  ],
  "skills": [
    { "name": "comment", "path": "skills/comment" },
    { "name": "migrate-project", "path": "skills/migrate-project" },
    { "name": "spec-delta", "path": "skills/spec-delta" },
    { "name": "java-tdd", "path": "skills/java-tdd" },
    { "name": "contract-testing", "path": "skills/contract-testing" },
    { "name": "publishing-service-contract", "path": "skills/publishing-service-contract" }
  ],
  "hooks": "hooks/hooks.json",
  "commands": [
    { "name": "spec-delta", "path": "commands/spec-delta.md" },
    { "name": "migrate-project", "path": "commands/migrate-project.md" },
    { "name": "publish-contract", "path": "commands/publish-contract.md" }
  ]
}
```

- [ ] **Step 2: Verify JSON is valid**

```bash
python3 -m json.tool .claude-plugin/plugin.json > /dev/null && echo "VALID"
```

Expected: `VALID`

---

## Task 2: Hook Infrastructure

**Files:**
- Create: `hooks/hooks.json`
- Create: `hooks/post-commit-sync.sh`

- [ ] **Step 1: Create hooks/hooks.json**

```json
{
  "post-commit": "hooks/post-commit-sync.sh"
}
```

- [ ] **Step 2: Create hooks/post-commit-sync.sh**

Exact content from spec:

```bash
#!/usr/bin/env bash
set -euo pipefail

MSG=$(git log -1 --pretty=%s)

if echo "$MSG" | grep -qE '^(feat|fix|chore)\(impl\):'; then
  # Ensure docs/ directory exists
  mkdir -p docs

  # Write current HEAD SHA to .spec-sync
  git rev-parse HEAD > docs/.spec-sync || {
    echo "ERROR: Failed to write docs/.spec-sync" >&2
    exit 1
  }

  git add docs/.spec-sync

  # Only amend if .spec-sync actually changed
  if ! git diff --cached --quiet; then
    git commit --amend --no-edit || {
      echo "ERROR: Failed to amend commit with .spec-sync update." >&2
      echo "To recover: run 'git commit --amend --no-edit' manually," >&2
      echo "or 'git reset HEAD docs/.spec-sync' to unstage and skip." >&2
      exit 1
    }
  fi
fi
```

- [ ] **Step 3: Make hook executable**

```bash
chmod +x hooks/post-commit-sync.sh
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n hooks/post-commit-sync.sh && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json hooks/
git commit -m "chore: add plugin registration and post-commit hook"
```

---

## Task 3: Command Files

**Files:**
- Create: `commands/spec-delta.md`
- Create: `commands/migrate-project.md`
- Create: `commands/publish-contract.md`

- [ ] **Step 1: Create commands/spec-delta.md**

```markdown
Invoke the `spec-delta` skill.
```

- [ ] **Step 2: Create commands/migrate-project.md**

```markdown
Invoke the `migrate-project` skill.
```

- [ ] **Step 3: Create commands/publish-contract.md**

```markdown
Invoke the `publishing-service-contract` skill.
```

- [ ] **Step 4: Commit**

```bash
git add commands/
git commit -m "chore: add command files for spec-delta, migrate-project, publish-contract"
```

---

## Task 4: comment skill

**Files:**
- Create: `skills/comment/SKILL.md`

**Purpose:** Generates accurate Javadoc and docstrings for Java codebases, processing files in dependency order. Used by `migrate-project` and `publishing-service-contract`.

- [ ] **Step 1: Create skills/comment/SKILL.md**

```markdown
# comment

Generates accurate, complete Javadoc and docstrings for under-documented Java codebases by processing files in dependency order — so each file is commented with full knowledge of what it depends on. Edits source files directly in place.

**TRIGGER when:** user asks to document, comment, or add Javadoc to Java files or directories in a project.

---

## Step 0: Resolve codeskel binary

Resolve the `codeskel` binary in this order:
1. `<plugin-root>/bin/codeskel-<os>-<arch>` where `<os>` is `linux`/`macos`/`windows` and `<arch>` is `x86_64`/`aarch64`
2. `codeskel` on `PATH`
3. If neither found: stop with "codeskel not found. Expected at <plugin-root>/bin/codeskel-<os>-<arch> or on PATH. See plugin README for setup."

Determine `<plugin-root>` as the directory containing this skill file (i.e., navigate up from `skills/comment/SKILL.md`).

## Step 1: Scan the project

If `.codeskel/cache.json` is absent in the project root, run:
```bash
codeskel scan <project_root>
```

This builds the dependency graph. Always re-run if the user says the codebase has changed significantly.

> **Rationalization table — do NOT skip codeskel rescan when:**
> - The user says "just a few files changed" — dependency order may still shift
> - You think you know the order — the scanner is authoritative
> - The cache file exists — it may be stale; check its mtime vs. source files

## Step 2: Determine file order

```bash
codeskel order <project_root> [--path <subpath>]
```

This outputs files in dependency order (dependencies before dependents). Use `--path` to scope to a subdomain or directory.

## Step 3: Process files in order

For each file in the dependency-ordered list:

1. Read the file fully
2. Read all files it depends on (already processed — they have updated Javadoc)
3. Generate accurate Javadoc for:
   - Each class/interface/enum (class-level `/** ... */`)
   - Each public method (method-level `/** ... */`)
   - Each public field that is not self-evident
4. Rules for accurate Javadoc:
   - Describe **what** the method/class does, not **how**
   - Include `@param` for each parameter with a meaningful description
   - Include `@return` for non-void methods
   - Include `@throws` for declared checked exceptions
   - Do NOT add `@author`, `@version`, or `@since` unless already present
   - Do NOT add comments that restate the method name (e.g., `/** Gets the name. */` for `getName()`)
   - For `@Entity` / `@Aggregate` classes, describe the domain concept, not the JPA mechanics
5. Write the updated file

## Step 4: Verify

After processing all files, run a quick sanity check:
```bash
codeskel rescan <project_root>
```

If any files still show as undocumented in the output, process them.

## Step 5: Report

Report:
- How many files were processed
- Any files skipped and why
- Any ambiguities in the domain model that you encountered while writing Javadoc
```

- [ ] **Step 2: Review against spec**

Verify the SKILL.md covers:
- `codeskel` resolution order (plugin bin/ → PATH → error)
- `codeskel scan` + `codeskel order` usage
- Dependency-ordered processing
- Javadoc quality rules (what not what how, @param/@return/@throws, no trivial comments)
- Used by migrate-project and publishing-service-contract

- [ ] **Step 3: Commit**

```bash
git add skills/comment/
git commit -m "feat: add comment skill"
```

---

## Task 5: migrate-project skill

**Files:**
- Create: `skills/migrate-project/SKILL.md`

**Purpose:** Bootstraps standard project structure on an existing Java microservice.

- [ ] **Step 1: Create skills/migrate-project/SKILL.md**

```markdown
# migrate-project

Bootstraps the standard project structure on an existing Java microservice that lacks docs, has sparse comments, and does not follow the team layout.

**TRIGGER when:** user runs `/migrate-project`.

**IMPORTANT:** Never invoke `superpowers:brainstorming` from this skill. Handle all ambiguity with targeted labeled-option questions directly (see Step 2).

---

## Step 0: Resolve codeskel binary

Same resolution order as the `comment` skill:
1. `<plugin-root>/bin/codeskel-<os>-<arch>`
2. `codeskel` on `PATH`
3. Fail with actionable error if not found

## Step 1: Detect subdomains

```bash
codeskel domains <project_root> --pretty
```

**If the command succeeds:** Present the detected subdomains as JSON to the human.

**If no subdomains detected (empty `detected_subdomains` array):** Ask:
> "No subdomains detected automatically. How many logical domains does this service have? Name them and describe their primary responsibility."
Use the human's answer to define domains manually.

**If the CLI fails:** Fall back to the same question as above.

## Step 2: Confirm subdomains with human

Present detected subdomains to the human. Ask for confirmation or corrections.

If boundaries are ambiguous, ask targeted questions with labeled options:
- Offer 2-3 options labeled A, B, C
- Mark one as `(recommended)`
- Keep the default answer to one keystroke

Example:
> "SharedUtils contains audit logging. Where should it live?
> A) billing domain — it's primarily used by billing (recommended)
> B) A new `audit` domain
> C) Shared infrastructure — keep outside all domains"

Do NOT invoke `superpowers:brainstorming`.

## Step 3: Process each subdomain in parallel

Invoke `superpowers:dispatching-parallel-agents` to run the following steps for each confirmed subdomain simultaneously. Within each subdomain, steps run sequentially:

**For each subdomain:**

a. Run `comment` skill on all classes in the subdomain's package:
   ```
   skills/comment — targeting <subdomain_package>
   ```

b. Generate `docs/<subdomain>/api-spec.yaml` from `@RestController` classes in `src/main/java/com/newland/<service>/api/`:
   - Use OpenAPI v3 format
   - Infer paths, methods, request/response schemas from controller signatures and Javadoc (now present from step a)
   - If springdoc-openapi is configured in pom.xml, note that it can auto-generate this at runtime

c. Generate `docs/<subdomain>/domain-model.md` from `@Entity` / `@Aggregate` classes:
   ```markdown
   # Domain Model: <subdomain>

   ## Entities

   ### <EntityName>
   <description from Javadoc>

   **Fields:**
   | Field | Type | Description |
   |-------|------|-------------|
   | id | UUID | Primary key |
   ...

   **Relationships:**
   - <EntityA> has many <EntityB> via ...
   ```

d. Generate `docs/<subdomain>/api-implement-logic.md` from `@Service` classes:
   ```markdown
   # Implementation Logic: <subdomain>

   ## <ServiceName>

   ### <methodName>
   <description of business logic, validation rules, side effects>
   ```

## Step 4: Generate project-level artifacts

After all subdomains complete:

1. Copy template stubs from plugin:
   - `templates/example.env` → `<project_root>/.env/example.env`
   - `templates/docker-compose.yml` → `<project_root>/docker-compose.yml`

2. Generate `docs/overview.md`:
   - Analyze codeskel output + main class, controllers, domain entities
   - Draft ≤1 page overview: what the service does, its domains, primary responsibilities
   - If service purpose is unclear, ask targeted question:
     > "What is the primary business domain of this service?
     > A) [inferred from package name, e.g. 'billing'] (recommended)
     > B) [other inferred option]
     > C) Other — describe it"
   - Show draft to human → write on approval

3. Add missing `pom.xml` plugin fragments from `templates/pom-fragments/` if absent:
   - Check for JaCoCo plugin → if absent, append `templates/pom-fragments/jacoco.xml` content into `<build><plugins>`
   - Check for springdoc-openapi → if absent, append `templates/pom-fragments/springdoc.xml` content into `<dependencies>`
   - Check for Testcontainers/RestAssured/WireMock in `<dependencies>` → if absent, append `templates/pom-fragments/testcontainers.xml`

4. Extract all `${VAR_NAME}` and `${VAR_NAME:default}` references from `application.yml`.
   Populate `<project_root>/.env/example.env` with all required keys (no values, just keys with comments):
   ```bash
   # Required: describe what this configures
   VAR_NAME=
   ```

## Step 5: Initialize .spec-sync

```bash
git rev-parse HEAD > docs/.spec-sync
```

## Step 6: Final commit

```bash
git add -A
git commit -m "chore(migrate): bootstrap standard project structure"
```

The post-commit hook will run but will NOT update `.spec-sync` (commit message uses `chore(migrate):`, not `chore(impl):`). That's correct — `.spec-sync` was already set to HEAD in Step 5.
```

- [ ] **Step 2: Review against spec**

Verify:
- `codeskel domains` usage + fallback to manual question
- No `superpowers:brainstorming` invocation
- Parallel dispatch via `superpowers:dispatching-parallel-agents`
- Sequential per-subdomain: comment → api-spec → domain-model → api-implement-logic
- Template copying + env extraction
- pom.xml fragment addition
- `.spec-sync` initialized to HEAD
- Commit uses `chore(migrate):` prefix

- [ ] **Step 3: Commit**

```bash
git add skills/migrate-project/
git commit -m "feat: add migrate-project skill"
```

---

## Task 6: spec-delta skill

**Files:**
- Create: `skills/spec-delta/SKILL.md`

**Purpose:** Computes requirements delta from spec files and drives implementation end-to-end.

- [ ] **Step 1: Create skills/spec-delta/SKILL.md**

```markdown
# spec-delta

Computes the requirements delta since the last implemented spec commit and drives the full implementation cycle: clarify → change-summary → migration preview → plan.

**TRIGGER when:** user runs `/spec-delta`.

---

## Step 1: Resolve or initialize .spec-sync

Check if `docs/.spec-sync` exists in the project root.

**Missing:**
- Run `git log --oneline -- docs/` to find commits that touched spec files.
- **No such commits found:** Initialize silently:
  ```bash
  git rev-parse HEAD > docs/.spec-sync
  ```
  Report: *"No spec commits found. Initialized .spec-sync to HEAD."*
  Then stop (nothing to process yet).
- **Commits found:** Show the last 5 commits. Ask:
  > "No .spec-sync found. Which commit was the last one fully implemented?
  > A) [sha1] [date] [message]   ← most recent spec commit
  > B) [sha2] [date] [message]
  > C) [sha3] [date] [message]
  > D) [sha4] [date] [message]
  > E) [sha5] [date] [message]
  > Z) HEAD — all current specs are already implemented
  > M) Enter a specific SHA manually"
  - Write chosen SHA to `docs/.spec-sync`
  - Report: *"Baseline set to [sha]. Run /spec-delta again to see what's pending."*
  - Stop.

**Present:** Read it to get the baseline SHA.

## Step 2: Compute the diff

```bash
git diff $(cat docs/.spec-sync) HEAD -- docs/
```

If the diff is empty: stop with *"No spec changes since last implementation."*

## Step 3: Establish context from docs/overview.md

**Missing:** Generate it before proceeding:
1. Read all spec files in `docs/`
2. Draft a ≤1 page overview describing what the service does, its domains, and primary responsibilities
3. Ask targeted questions if anything is unclear (labeled options + recommendation)
4. Show draft to human for approval → write approved version to `docs/overview.md`

**Present:** Read it as background context.

*(If a new domain was added in the diff: after change-summary approval in Step 8, you will be prompted to update overview.md — handled there.)*

## Step 4: Order changed domains

Identify which domains changed in the diff.

Order tasks within each domain by dependency:
```
domain-model.md → api-implement-logic.md → api-spec.yaml
```

Cross-domain ordering: if domain-A's model is referenced by domain-B's API, domain-A tasks come first. Ask the human if cross-domain dependencies are unclear:
> "domain-A's model appears in domain-B's API spec. Should domain-A be implemented before domain-B?
> A) Yes — implement domain-A first (recommended)
> B) No — they can be implemented independently"

## Step 5: Semantic schema change analysis

Read the full diff of all changed spec docs (domain-model.md, api-implement-logic.md, api-spec.yaml).

Reason semantically about whether the changes imply database schema changes:
- New entities → new tables
- New entity fields → new columns
- Entity relationships changed → FK changes, join table changes
- Renamed concepts → column renames
- Removed fields → dropped columns
- New query patterns → new indexes

Do NOT use keyword scanning. Use domain understanding to determine if schema changes are needed.

## Step 6: Ask clarification questions

Ask targeted clarification questions one at a time — only for genuine ambiguities.

Each question must have:
- 2-3 labeled options (A, B, C)
- One marked `(recommended)`
- Default answerable with one keystroke

Example:
> "Should bulk invoice creation be transactional or best-effort?
> A) Transactional — all succeed or all fail (recommended)
> B) Best-effort — process valid items, skip invalid ones"

## Step 7: Determine run directory

Create the run directory:
```
docs/jkit/YYYY-MM-DD-<feature>/
```
Where `<feature>` is a short slug derived from the most significant change in the diff (e.g., `billing-bulk-invoice`, `user-auth-2fa`).

## Step 8: Write change-summary.md

Write `docs/jkit/<run>/change-summary.md`:

```markdown
# Change Summary: <feature>

**Baseline:** `<sha>`
**Date:** YYYY-MM-DD

## Domains Changed

| Domain | Added | Modified | Removed |
|--------|-------|----------|---------|
| billing | BulkInvoice entity, POST /invoices/bulk | Invoice.status enum | — |

## Schema Change Required
[Yes / No]

If yes, briefly describe the implied changes:
- CREATE TABLE `bulk_invoice`
- ADD COLUMN `invoice.bulk_id`

## Cross-Domain Effects
[None / describe if present]

## Implementation Order
1. billing/domain-model (BulkInvoice entity)
2. billing/api-implement-logic (BulkInvoiceService)
3. billing/api-spec (POST /invoices/bulk)
```

Ask human to review and approve `change-summary.md` before proceeding.

**After approval — new domain check:** If a new domain was added in the diff, prompt:
> "A new domain was added. Should docs/overview.md be updated?
> A) Yes — generate an updated draft (recommended)
> B) No — overview is still accurate"
If yes: draft update → show to human → write on approval.

## Step 9: SQL migration (if schema changes flagged)

If Step 5 flagged schema changes:

1. Write `docs/jkit/<run>/migration-preview.md`:

```markdown
## Migration Preview: <feature>

| Change | Type | Detail |
|--------|------|--------|
| `bulk_invoice` | CREATE TABLE | id UUID PK, tenant_id UUID, status VARCHAR, created_at TIMESTAMP |
| `invoice.bulk_id` | ADD COLUMN | FK to bulk_invoice(id), nullable |
| `idx_invoice_bulk` | CREATE INDEX | on invoice(bulk_id) |
```

2. Ask human to review and approve:
   > "Please review docs/jkit/<run>/migration-preview.md.
   > A) Approve as-is (recommended)
   > B) Edit preview first — I'll wait
   > C) Skip migration — no schema changes needed"

3. On approval: generate SQL into `docs/jkit/<run>/migration/V<YYYYMMDD>_NNN__<feature>.sql`:

```sql
-- Migration: <feature>
-- Date: YYYY-MM-DD

CREATE TABLE bulk_invoice (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE invoice ADD COLUMN bulk_id UUID REFERENCES bulk_invoice(id);

CREATE INDEX idx_invoice_bulk ON invoice(bulk_id);
```

Note: The SQL file will be moved to `src/main/resources/db/migration/` as the final step of the implementation plan (included in the `writing-plans` plan).

## Step 10: Invoke writing-plans

Invoke `superpowers:writing-plans` with:
- The full diff content
- Contents of `docs/overview.md`
- All clarification answers from Step 6
- Instruction: **save the plan to `docs/jkit/<run>/plan.md`** (not the default superpowers location)

The plan should include, as its final task: move SQL file from `docs/jkit/<run>/migration/` to `src/main/resources/db/migration/` and include it in the implementation commit.

## Step 11: After implementation

The post-commit hook automatically updates `docs/.spec-sync` after each `feat(impl):` / `fix(impl):` / `chore(impl):` commit.
```

- [ ] **Step 2: Review against spec**

Verify all 12 steps from spec are covered:
- .spec-sync missing: interactive baseline selection + stop
- git diff baseline computation
- Empty diff → stop
- overview.md: missing → generate; present → read; new domain update fires AFTER change-summary approval
- Domain ordering (dependency order)
- Semantic schema analysis (no keyword scanning)
- Labeled-option questions
- change-summary.md format + human approval
- migration-preview.md + SQL generation (when schema flagged)
- writing-plans invocation explicitly instructs plan saved to `docs/jkit/<run>/plan.md` (superpowers compatibility rule #2)
- Post-commit hook updates .spec-sync

- [ ] **Step 3: Commit**

```bash
git add skills/spec-delta/
git commit -m "feat: add spec-delta skill"
```

---

## Task 7: java-tdd skill

**Files:**
- Create: `skills/java-tdd/SKILL.md`

**Purpose:** TDD workflow for Java, extended with JaCoCo coverage gap analysis after GREEN phase.

- [ ] **Step 1: Create skills/java-tdd/SKILL.md**

```markdown
# java-tdd

TDD workflow for Java/Spring Boot, extended with JaCoCo coverage gap analysis after the GREEN phase.

**TRIGGER when:** implementing any Java feature or bugfix in this project.

**Wraps:** `superpowers:test-driven-development` — follow that skill's full RED/GREEN/REFACTOR cycle first, then continue with the JaCoCo extension below.

---

## Step 0: Load coding standards

Read `<plugin-root>/docs/java-coding-standards.md` before writing any code. Apply all rules throughout this skill.

## Step 1: Verify JaCoCo prerequisite

Check `pom.xml` for the JaCoCo Maven plugin configuration.

**If missing:** Add the fragment from `<plugin-root>/templates/pom-fragments/jacoco.xml` into `<build><plugins>` in `pom.xml`. Commit: `chore(impl): add JaCoCo Maven plugin`

## Step 2: Follow superpowers:test-driven-development

Invoke `superpowers:test-driven-development` and complete the full cycle:
- RED: write failing test
- GREEN: minimal implementation
- REFACTOR: clean up while keeping tests green

## Step 3: JaCoCo coverage gap analysis

After GREEN phase (all tests pass):

### 3a. Generate JaCoCo report

```bash
mvn clean test jacoco:report
```

**If command fails or `target/site/jacoco/jacoco.xml` is absent after build:**
Stop and ask:
> "JaCoCo report generation failed. Verify pom.xml includes the JaCoCo plugin (see templates/pom-fragments/jacoco.xml). Add it and re-run."

### 3b. Run jacoco-filter

```bash
<plugin-root>/bin/jacoco-filter-<os>-<arch> target/site/jacoco/jacoco.xml --summary --min-score 1.0
```

Resolve the binary the same way as `codeskel`:
1. `<plugin-root>/bin/jacoco-filter-<os>-<arch>`
2. `jacoco-filter` on `PATH`
3. Fail with actionable message if not found

### 3c. Analyze coverage gaps

Feed the JSON output to Claude. For each uncovered method with score ≥ threshold:
- Write a test targeting that specific method/branch
- Run `mvn test` to verify the new test passes
- Repeat `jacoco-filter` to check remaining gaps

### 3d. Repeat until clean

Repeat Steps 3a–3c until `jacoco-filter` reports no methods above the score threshold.

## Step 4: Final commit

Commit message MUST use one of:
- `feat(impl): <description>` — new feature
- `fix(impl): <description>` — bug fix
- `chore(impl): <description>` — non-feature work

This triggers the post-commit hook to update `docs/.spec-sync`.
```

- [ ] **Step 2: Review against spec**

Verify:
- Step 0: loads java-coding-standards.md
- JaCoCo prerequisite check
- Wraps superpowers:test-driven-development
- Post-GREEN JaCoCo extension: report → jacoco-filter → write tests → repeat
- jacoco-filter binary resolution (bin/ first, then PATH)
- Final commit uses `(impl):` prefix

- [ ] **Step 3: Commit**

```bash
git add skills/java-tdd/
git commit -m "feat: add java-tdd skill"
```

---

## Task 8: contract-testing skill

**Files:**
- Create: `skills/contract-testing/SKILL.md`

**Purpose:** API scenario tests derived from a domain's api-spec.yaml.

- [ ] **Step 1: Create skills/contract-testing/SKILL.md**

```markdown
# contract-testing

Generates API scenario integration tests for a specific domain, derived from its `api-spec.yaml`. Supports both Spring Boot 3.1+ and legacy versions.

**TRIGGER when:** implementing a domain's API endpoints (after java-tdd for that domain).

**Invocation:** Per-domain. Target one domain at a time.

---

## Step 0: Load coding standards

Read `<plugin-root>/docs/java-coding-standards.md` before writing any code.

## Step 1: Read the diff

Read the diff of `docs/<domain>/api-spec.yaml` from the run's baseline SHA:

```bash
git diff $(cat docs/.spec-sync) HEAD -- docs/<domain>/api-spec.yaml
```

Extract only **added or modified** endpoints from the diff. Unchanged endpoints already have tests — do NOT regenerate them.

## Step 2: Detect Spring Boot version

Read `<parent><version>` from `pom.xml`.

| Spring Boot version | Testing strategy |
|---------------------|-----------------|
| 3.1+ | `@SpringBootTest` + Testcontainers (`@ServiceConnection`) + RestAssured |
| < 3.1 | docker-compose + RestAssured against running container |

## Step 3: Verify test prerequisites

**Spring Boot 3.1+:**
Check `pom.xml` for Testcontainers, RestAssured, and WireMock test dependencies.
If missing: add from `<plugin-root>/templates/pom-fragments/testcontainers.xml`

**Spring Boot < 3.1:**
Check that `docker-compose.test.yml` exists in project root.
If missing: copy from `<plugin-root>/templates/docker-compose.test.yml`

## Step 4: Ask about external service dependencies

> "Which external services do these endpoints call?
> A) None (recommended if self-contained)
> B) [list detected Feign clients / RestTemplate calls from codebase]"

Use the answer to determine which services need WireMock stubs.

## Step 5: Write contract-tests.md

Write `docs/jkit/<run>/contract-tests.md`:

```markdown
## Contract Tests: <domain> domain

| Endpoint | Scenario | Input | Expected |
|----------|----------|-------|----------|
| POST /invoices/bulk | happy path | valid list of 3 | 201 + list of invoice IDs |
| POST /invoices/bulk | empty list | [] | 400 validation error |
| POST /invoices/bulk | unauthenticated | no token | 401 |
| POST /invoices/bulk | missing required field | list without amount | 422 |
```

Include scenarios for:
- Happy path (success case)
- Input validation failures (400, 422)
- Authentication/authorization (401, 403)
- Not found (404) where applicable
- Edge cases specific to the business logic

**Scope:** Only added/modified endpoints from Step 1.

Ask human to review and approve the scenario table before proceeding.

## Step 6: Generate Java test code

Generate `src/test/java/com/newland/<service>/<domain>/<Domain>IntegrationTest.java` from the approved scenarios.

**Spring Boot 3.1+ template:**
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class InvoiceIntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");

    // WireMock for each external service dependency
    @RegisterExtension
    static WireMockExtension externalService = WireMockExtension.newInstance()
        .options(wireMockConfig().dynamicPort())
        .build();

    @LocalServerPort
    int port;

    @BeforeEach
    void setup() {
        RestAssured.port = port;
    }

    @Test
    void bulkInvoiceCreation_happyPath() {
        // given
        var request = List.of(/* valid invoice data */);

        // when / then
        given()
            .contentType(ContentType.JSON)
            .body(request)
        .when()
            .post("/invoices/bulk")
        .then()
            .statusCode(201)
            .body("$", hasSize(3));
    }
}
```

**Spring Boot < 3.1 template:**
```java
class InvoiceIntegrationTest {

    // Service runs via docker-compose.test.yml
    // Base URI set from environment variable
    static String baseUri = System.getenv().getOrDefault("SERVICE_BASE_URI", "http://localhost:8080");

    @BeforeAll
    static void setup() {
        RestAssured.baseURI = baseUri;
    }

    @Test
    void bulkInvoiceCreation_happyPath() {
        given()
            .contentType(ContentType.JSON)
            .body(/* valid payload */)
        .when()
            .post("/invoices/bulk")
        .then()
            .statusCode(201);
    }
}
```

Test class naming: `<Domain>IntegrationTest.java` (e.g., `InvoiceIntegrationTest.java`).

## Step 7: Run integration tests

**Spring Boot 3.1+:**
```bash
source .env/test.env && mvn test -Dtest=*IntegrationTest
```

**Spring Boot < 3.1:**
```bash
docker-compose -f docker-compose.test.yml up -d
source .env/test.env && mvn test -Dtest=*IntegrationTest
```

Fix any failures before proceeding.
```

- [ ] **Step 2: Review against spec**

Verify:
- Step 0: loads java-coding-standards.md
- Reads diff from .spec-sync baseline (only changed endpoints)
- Spring Boot version detection from pom.xml
- Both testing strategies covered (3.1+ and < 3.1)
- Prerequisite check (testcontainers.xml)
- External service question (labeled options)
- contract-tests.md format + human approval
- Java code from approved table
- Test naming: *IntegrationTest.java
- Run command differences per version

- [ ] **Step 3: Commit**

```bash
git add skills/contract-testing/
git commit -m "feat: add contract-testing skill"
```

---

## Task 9: publishing-service-contract skill

**Files:**
- Create: `skills/publishing-service-contract/SKILL.md`

**Purpose:** Generates a SKILL.md for this microservice so other Claude instances can call it correctly.

- [ ] **Step 1: Create skills/publishing-service-contract/SKILL.md**

```markdown
# publishing-service-contract

Generates a `SKILL.md` for this microservice so other microservices (and Claude instances working in other repos) can call it correctly. Also generates the reference OpenAPI spec.

**TRIGGER when:** user runs `/publish-contract`, or after implementing new/changed API endpoints.

---

## Step 0: Resolve codeskel binary

Same resolution order as `comment` skill:
1. `<plugin-root>/bin/codeskel-<os>-<arch>`
2. `codeskel` on `PATH`
3. Fail with actionable error if not found

## Step 1: Identify the service name and controllers

- Service name: read from `pom.xml` → `<artifactId>`
- Controllers: scan `src/main/java/com/newland/<service>/api/` for `@RestController` classes

## Step 2: Ensure Javadoc quality on controllers

Run the `comment` skill targeting `src/main/java/com/newland/<service>/api/`:
```
skills/comment — targeting api/ directory
```

This ensures the generated SKILL.md describes endpoints accurately based on up-to-date Javadoc.

## Step 3: Generate OpenAPI spec

If springdoc-openapi is configured in pom.xml:
```bash
mvn spring-boot:run &
sleep 5
curl http://localhost:8080/v3/api-docs -o docs/skills/<service-name>/reference/openapi.yaml
kill %1
```

If springdoc-openapi is NOT configured:
- Check pom.xml and add `<plugin-root>/templates/pom-fragments/springdoc.xml` if missing
- Then run the above command

Output: `docs/skills/<service-name>/reference/openapi.yaml`

## Step 4: Run codeskel to build dependency context

```bash
codeskel scan <project_root>
codeskel order <project_root> --path src/main/java/com/newland/<service>/api/
```

## Step 5: Generate SKILL.md

Read all `@RestController` classes (in dependency order from Step 4).
Read `docs/skills/<service-name>/reference/openapi.yaml`.
Read `docs/overview.md` for service context.

Generate `docs/skills/<service-name>/SKILL.md` following this format:

```markdown
# <service-name>

<one-paragraph description of what this service does and when to use it>

**Base URL:** `${<SERVICE_NAME>_BASE_URL}`

---

## Endpoints

### POST /path/to/endpoint

**Description:** [what it does]

**Request:**
\`\`\`json
{
  "field": "type — description"
}
\`\`\`

**Response (201):**
\`\`\`json
{
  "field": "type — description"
}
\`\`\`

**Error responses:**
| Status | Condition |
|--------|-----------|
| 400 | Validation failure |
| 401 | Missing/invalid token |
| 404 | Resource not found |

---

## Authentication

[Describe auth mechanism — Bearer token, API key, etc.]

## Environment Variables Required

| Variable | Description |
|----------|-------------|
| `<SERVICE_NAME>_BASE_URL` | Base URL of this service |

## WireMock Stub Example

\`\`\`java
stubFor(post(urlEqualTo("/path/to/endpoint"))
    .willReturn(aResponse()
        .withStatus(201)
        .withHeader("Content-Type", "application/json")
        .withBody("{ ... }")));
\`\`\`
```

## Step 6: Commit

```bash
git add docs/skills/<service-name>/
git commit -m "chore(impl): publish service contract for <service-name>"
```
```

- [ ] **Step 2: Review against spec**

Verify:
- codeskel resolution (bin/ first)
- comment skill for Javadoc quality gate
- openapi.yaml generated to docs/skills/<service-name>/reference/
- SKILL.md at docs/skills/<service-name>/SKILL.md
- Includes WireMock stub example (for other services)
- Commit uses `chore(impl):` prefix

- [ ] **Step 3: Commit**

```bash
git add skills/publishing-service-contract/
git commit -m "feat: add publishing-service-contract skill"
```

---

## Task 10: Templates

**Files:**
- Create: `templates/CLAUDE.md`
- Create: `templates/example.env`
- Create: `templates/docker-compose.yml`
- Create: `templates/docker-compose.test.yml`
- Create: `templates/pom-fragments/jacoco.xml`
- Create: `templates/pom-fragments/springdoc.xml`
- Create: `templates/pom-fragments/testcontainers.xml`

- [ ] **Step 1: Create templates/CLAUDE.md**

This is the project template — workflow conventions only, no coding rules (those live in java-coding-standards.md).

```markdown
# Project Conventions

## Commit Prefixes

| Prefix | Meaning |
|--------|---------|
| `docs(spec):` or `docs(<domain>):` | Spec change |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |
| `chore(migrate):` | Project migration commit |

The `(impl):` scope triggers the post-commit hook to update `docs/.spec-sync`.

## Environment Variables

- Single `application.yml` using `${ENV_VAR:default}` substitution
- No `application-{profile}.yml` files
- Load env: `source .env/<env>.env && mvn <command>`
- Test: `source .env/test.env && mvn test`

## Running Integration Tests

```bash
source .env/test.env && mvn test -Dtest=*IntegrationTest
```

## Workflow

1. Edit `docs/` spec files
2. Commit with `docs(spec):` or `docs(<domain>):`
3. Run `/spec-delta` to compute delta and generate plan
4. Implement using `/java-tdd` per task
5. Test APIs using `/contract-testing` per domain
6. Commit with `feat(impl):` — post-commit hook updates `.spec-sync`
7. Run `/publish-contract` to update service contract

## jkit Artifacts

Each implementation run creates `docs/jkit/YYYY-MM-DD-<feature>/`:
- `change-summary.md` — review before planning
- `contract-tests.md` — review before test generation
- `migration-preview.md` — review before SQL generation
- `migration/` — generated SQL (moved to `src/main/resources/db/migration/` in final commit)
- `plan.md` — implementation plan
```

- [ ] **Step 2: Create templates/example.env**

```bash
# Required environment variables for this service
# Copy to .env/local.env (gitignored) and fill in values
# For tests: copy to .env/test.env and configure test infrastructure

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=
DB_USER=
DB_PASSWORD=

# Service
SERVER_PORT=8080
```

- [ ] **Step 3: Create templates/docker-compose.yml**

```yaml
version: '3.8'

# Local development dependencies
# Usage: docker-compose up -d

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ${DB_NAME:-app_db}
      POSTGRES_USER: ${DB_USER:-app_user}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-app_password}
    ports:
      - "${DB_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

- [ ] **Step 4: Create templates/docker-compose.test.yml**

```yaml
version: '3.8'

# Test environment: spins up service + all dependencies
# Usage: docker-compose -f docker-compose.test.yml up -d
# Then: source .env/test.env && mvn test -Dtest=*IntegrationTest

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ${DB_NAME:-test_db}
      POSTGRES_USER: ${DB_USER:-test_user}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-test_password}
    ports:
      - "${DB_PORT:-5433}:5432"

  wiremock:
    image: wiremock/wiremock:3.3.1
    ports:
      - "8089:8080"
    volumes:
      - ./src/test/resources/wiremock:/home/wiremock

  app:
    build: .
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      EXTERNAL_SERVICE_BASE_URL: http://wiremock:8080
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - wiremock
```

- [ ] **Step 5: Create templates/pom-fragments/jacoco.xml**

```xml
<!-- JaCoCo Maven Plugin — add inside <build><plugins> -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>test</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

- [ ] **Step 6: Create templates/pom-fragments/springdoc.xml**

```xml
<!-- springdoc-openapi dependency — add inside <dependencies> -->
<!-- Generates OpenAPI spec at /v3/api-docs when app is running -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

- [ ] **Step 7: Create templates/pom-fragments/testcontainers.xml**

```xml
<!-- Testcontainers + RestAssured + WireMock — add inside <dependencies> -->
<!-- For Spring Boot 3.1+ integration testing -->

<!-- Testcontainers BOM — add to <dependencyManagement><dependencies> -->
<!--
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>testcontainers-bom</artifactId>
    <version>1.19.3</version>
    <type>pom</type>
    <scope>import</scope>
</dependency>
-->

<!-- Test dependencies -->
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <version>5.4.0</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.wiremock</groupId>
    <artifactId>wiremock-standalone</artifactId>
    <version>3.3.1</version>
    <scope>test</scope>
</dependency>
```

- [ ] **Step 8: Verify XML fragments are well-formed**

Wrap each fragment in a root element to allow standard XML parsing:

```bash
python3 -c "
import xml.etree.ElementTree as ET
import sys

files = [
    'templates/pom-fragments/jacoco.xml',
    'templates/pom-fragments/springdoc.xml',
    'templates/pom-fragments/testcontainers.xml',
]
for f in files:
    try:
        content = open(f).read()
        ET.fromstring('<root>' + content + '</root>')
        print(f'OK: {f}')
    except Exception as e:
        print(f'ERROR {f}: {e}')
        sys.exit(1)
"
```

Expected: all three print `OK:`.

- [ ] **Step 9: Commit**

```bash
git add templates/
git commit -m "feat: add project templates (CLAUDE.md, docker-compose, pom fragments)"
```

---

## Task 11: Plugin Docs

**Files:**
- Create: `docs/java-coding-standards.md`
- Create: `docs/codeskel-domains-prd.md`

- [ ] **Step 1: Create docs/java-coding-standards.md**

```markdown
# Java Coding Standards

These rules apply to all Java code written in this project. Loaded by `java-tdd` and `contract-testing` skills.

## Naming

- Classes: `PascalCase`
- Methods and fields: `camelCase`
- Constants: `UPPER_SNAKE_CASE`
- Packages: `lowercase.with.dots`
- Test classes: suffix with `Test` (unit) or `IntegrationTest` (integration)
- Test methods: `methodName_scenarioDescription` (e.g. `createInvoice_withValidData_returns201`)

## Code Structure

- One public class per file
- Controllers in `api/` package: only request mapping, input validation, response mapping. No business logic.
- Services in `service/` or domain package: business logic only. No HTTP concerns.
- Repositories in `repository/` package: data access only.
- DTOs/request/response objects: immutable where possible, use records for Java 16+.

## Spring Boot

- Use constructor injection (not `@Autowired` on fields)
- Validate request bodies with `@Valid` and Jakarta Bean Validation annotations
- Use `@RestControllerAdvice` for global exception handling
- Return `ResponseEntity<T>` from controllers
- Use `@Transactional` at the service layer, not the controller layer

## Testing

- Unit tests: mock all dependencies with Mockito
- Integration tests (`*IntegrationTest`): use real infrastructure (Testcontainers or docker-compose)
- Test one behavior per test method
- Use `@BeforeEach` for setup, `@AfterEach` for cleanup
- Assert on behavior, not implementation details
- Do NOT test private methods directly — test through public API

## Error Handling

- Use custom exception classes extending `RuntimeException` for domain errors
- Map exceptions to HTTP status codes in `@RestControllerAdvice`
- Return RFC 7807 problem details format for error responses:
  ```json
  {
    "type": "https://example.com/problems/not-found",
    "title": "Resource not found",
    "status": 404,
    "detail": "Invoice 123 not found"
  }
  ```

## Database / JPA

- Use `UUID` primary keys (not auto-increment Long)
- Annotate entities with `@Entity`, repositories with `@Repository`
- Use Flyway for database migrations (files in `src/main/resources/db/migration/`)
- Migration naming: `V<YYYYMMDD>_NNN__<description>.sql`
- Do NOT use `@GeneratedValue(strategy = AUTO)` — use `@GeneratedValue(generator = "UUID")` or assign in constructor

## Logging

- Use SLF4J (`private static final Logger log = LoggerFactory.getLogger(MyClass.class)`)
- Log at INFO for significant business events
- Log at DEBUG for internal state (disabled in production)
- Never log passwords, tokens, or PII
```

- [ ] **Step 2: Create docs/codeskel-domains-prd.md**

Extract the `codeskel domains` PRD section from the design spec verbatim (it's fully specified there):

```markdown
# codeskel domains — PRD

**Problem:** Migrating existing Java microservices to the standard doc structure
requires identifying subdomain boundaries. Reading all Java files with Claude is
token-expensive and imprecise. A deterministic scanner eliminates this cost.

**Approach:** Add a `domains` subcommand to the existing `codeskel` CLI. All
required data (packages, class-level annotations) is already collected by
`codeskel scan` via tree-sitter. No new tool or new parsing logic needed.

## Detection Rules

| Signal | Role |
|--------|------|
| Package name segments (`com.example.billing`) | Primary grouping key |
| `@RestController` base path prefix (`/billing/**`) | Primary confirmation |
| `@Entity` / `@Aggregate` package grouping | Secondary |
| `@Service` package grouping | Secondary |

## CLI Interface

```
codeskel domains <project_root> [OPTIONS]

Options:
  --output <path>       Write JSON to file (default: stdout)
  --pretty              Pretty-print output
  --min-classes <n>     Minimum classes to qualify as a subdomain [default: 2]
  --src <path>          Override source root [default: src/main/java]
```

## Output Format

```json
{
  "detected_subdomains": [
    {
      "name": "billing",
      "package": "com.example.billing",
      "controllers": ["InvoiceController", "PaymentController"],
      "entities": ["Invoice", "Payment"],
      "services": ["InvoiceService"]
    }
  ],
  "ambiguous": ["SharedUtils", "AuditLog"],
  "stats": { "total_classes": 47, "unmapped": 3 }
}
```

## Exit Codes

Follows existing `codeskel` conventions:
- `0` = success
- `1` = fatal error
- `2` = partial success with warnings

## Non-Goals

- Does not read method bodies
- Does not infer business logic or domain relationships
- Does not generate docs (Claude's responsibility)

## Implementation Notes

- Reuse `.codeskel/cache.json` if present; run `codeskel scan` first if not
- Group by top-level package segment after the group ID prefix
  (e.g., `com.newland` prefix → `billing` from `com.newland.billing`)
- Annotation detection reuses existing tree-sitter parsing — no raw regex
- Rust, same codebase as `codeskel`
```

- [ ] **Step 3: Commit**

```bash
git add docs/java-coding-standards.md docs/codeskel-domains-prd.md
git commit -m "feat: add java-coding-standards and codeskel-domains-prd docs"
```

---

## Task 12: Final Verification

- [ ] **Step 1: Verify full file tree matches spec**

```bash
find . -not -path './.git/*' -not -path './docs/specs/*' -not -path './docs/superpowers/*' -type f | sort
```

Expected output should include all files from spec's `Plugin Structure` section (except `bin/` pre-built binaries).

- [ ] **Step 2: Verify plugin.json is valid JSON**

```bash
python3 -m json.tool .claude-plugin/plugin.json > /dev/null && echo "VALID"
```

- [ ] **Step 3: Verify hooks.json is valid JSON**

```bash
python3 -m json.tool hooks/hooks.json > /dev/null && echo "VALID"
```

- [ ] **Step 4: Verify hook script has no syntax errors**

```bash
bash -n hooks/post-commit-sync.sh && echo "SYNTAX OK"
```

- [ ] **Step 5: Verify all SKILL.md files exist**

```bash
for skill in comment migrate-project spec-delta java-tdd contract-testing publishing-service-contract; do
  [ -f "skills/$skill/SKILL.md" ] && echo "OK: $skill" || echo "MISSING: $skill"
done
```

- [ ] **Step 6: Verify all command files exist**

```bash
for cmd in spec-delta migrate-project publish-contract; do
  [ -f "commands/$cmd.md" ] && echo "OK: $cmd" || echo "MISSING: $cmd"
done
```

- [ ] **Step 7: Final commit (if any cleanup needed)**

```bash
git add -A
git status  # should be clean
```
