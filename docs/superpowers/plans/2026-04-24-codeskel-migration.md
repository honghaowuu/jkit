# codeskel + jacoco-filter Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all `bin/jkit skel` and `bin/jkit coverage` calls in skills with native `codeskel` and `jacoco-filter` commands, and write a standalone PRD for the five new codeskel subcommands.

**Architecture:** Four skill SKILL.md files are edited surgically — only the tool invocation blocks and JSON parsing instructions change. A fifth task writes a clean PRD document for the new subcommands, following the existing `docs/codeskel-domains-prd.md` pattern.

**Tech Stack:** Markdown file edits only. No build step. Verification is reading the final file and confirming correctness.

---

## File Map

| File | Change |
|---|---|
| `skills/publish-contract/SKILL.md` | Replace `bin/jkit skel` with `codeskel scan` + `codeskel get` |
| `skills/scenario-gap/SKILL.md` | Replace `bin/jkit skel` with `codeskel scan` + `codeskel get` |
| `skills/java-tdd/SKILL.md` | Replace `bin/jkit coverage` with `jacoco-filter`; update JSON shape |
| `skills/java-verify/SKILL.md` | Replace `bin/jkit coverage` with `jacoco-filter`; remove `--api` line with note |
| `docs/codeskel-new-subcommands-prd.md` | Create — standalone PRD for 5 new codeskel subcommands |

---

## Task 1: Update `publish-contract` skill

**Files:**
- Modify: `skills/publish-contract/SKILL.md`

- [ ] **Step 1: Update checklist item**

Change line 12 from:
```
- [ ] Find and confirm controller path + jkit skel scan
```
To:
```
- [ ] Find and confirm controller path + codeskel scan
```

- [ ] **Step 2: Replace the scan block in Step 3**

Find this block (around line 101–107):
```markdown
Scan with jkit skel:

```bash
bin/jkit skel "src/main/java/${GROUP_PATH}/${SERVICE}/api/"
```

From JSON output: identify classes with `@RestController` or `@Controller` annotation, and their public methods.
```

Replace with:
```markdown
Scan with codeskel:

```bash
codeskel scan "src/main/java/${GROUP_PATH}/${SERVICE}/api/" --lang java
```

This writes `.codeskel/cache.json` and returns `stats.to_comment` (N files). Iterate to find controllers:

```bash
# For i = 0 to stats.to_comment - 1:
codeskel get .codeskel/cache.json --index <i>
```

For each file entry: identify controllers where `signatures[].annotations[].name` is `"RestController"` or `"Controller"`. Collect all method signatures from that entry.
```

- [ ] **Step 3: Update the re-scan reference in Step 4**

Change line 122 from:
```
On A: read each controller, fill missing/thin Javadoc, re-run `jkit skel` to confirm. Do not use pre-improvement data after re-scan.
```
To:
```
On A: read each controller, fill missing/thin Javadoc, then re-scan and re-fetch:

```bash
codeskel rescan .codeskel/cache.json <controller_path>
codeskel get .codeskel/cache.json --path <controller_path>
```

Do not use pre-improvement data after re-scan.
```

- [ ] **Step 4: Verify the file reads correctly**

Read `skills/publish-contract/SKILL.md` lines 95–130 and confirm:
- No remaining `jkit` references in Step 3 or Step 4
- `codeskel scan` command is present
- `codeskel get --index` loop instruction is present
- `codeskel rescan` + `codeskel get --path` re-scan block is present
- `has_docstring` and `docstring_text` field references are unchanged

- [ ] **Step 5: Commit**

```bash
git add skills/publish-contract/SKILL.md
git commit -m "chore: migrate publish-contract from jkit skel to codeskel"
```

---

## Task 2: Update `scenario-gap` skill

**Files:**
- Modify: `skills/scenario-gap/SKILL.md`

- [ ] **Step 1: Replace the scan block in Step 2**

Find this block (around line 41–47):
```markdown
```bash
bin/jkit skel src/test/java/<group-path>/<service>/<domain>/
```

If no test class exists for the domain → all scenarios are gaps.

From JSON output: collect all test method names.
```

Replace with:
```markdown
```bash
codeskel scan src/test/java/<group-path>/<service>/<domain>/ --lang java
```

If `stats.to_comment` is 0 (no files found) → all scenarios are gaps.

Iterate over all files in the cache:

```bash
# For i = 0 to stats.to_comment - 1:
codeskel get .codeskel/cache.json --index <i>
```

From each file entry: collect all `name` values from `signatures[]` where `kind == "method"`.
```

- [ ] **Step 2: Verify the file reads correctly**

Read `skills/scenario-gap/SKILL.md` lines 39–55 and confirm:
- No remaining `jkit` references
- `codeskel scan` command is present
- `codeskel get --index` loop instruction is present
- `kind == "method"` filter is present
- Step 3 (camelCase matching logic) is unchanged

- [ ] **Step 3: Commit**

```bash
git add skills/scenario-gap/SKILL.md
git commit -m "chore: migrate scenario-gap from jkit skel to codeskel"
```

---

## Task 3: Update `java-tdd` skill

**Files:**
- Modify: `skills/java-tdd/SKILL.md`

- [ ] **Step 1: Update checklist item**

Change line 52 from:
```
- [ ] Run jkit coverage
```
To:
```
- [ ] Run jacoco-filter
```

- [ ] **Step 2: Update the process flow diagram**

Find this node in the dot diagram (around line 69):
```
    "jkit coverage\n--summary --min-score 1.0" [shape=box];
```
Replace with:
```
    "jacoco-filter\n--summary --min-score 1.0" [shape=box];
```

Find these edges (around lines 85–86):
```
    "mvn clean test\njacoco:report" -> "jkit coverage\n--summary --min-score 1.0";
    "jkit coverage\n--summary --min-score 1.0" -> "Gaps above threshold?";
```
Replace with:
```
    "mvn clean test\njacoco:report" -> "jacoco-filter\n--summary --min-score 1.0";
    "jacoco-filter\n--summary --min-score 1.0" -> "Gaps above threshold?";
```

- [ ] **Step 3: Replace the coverage command block in Step 5**

Find this block (around line 147–150):
```markdown
```bash
bin/jkit coverage target/site/jacoco/jacoco.xml --summary --min-score 1.0
```

For each method with gaps above threshold (in priority order): invoke `superpowers:test-driven-development` targeting that specific uncovered path. Repeat until no methods above threshold.
```

Replace with:
```markdown
```bash
jacoco-filter target/site/jacoco/jacoco.xml --summary --min-score 1.0
```

Output shape: `{"summary": {"line_coverage_pct": ..., "lines_covered": ..., "lines_missed": ..., "by_class": [...]}, "methods": [...]}`.
The gap list is `methods[]` sorted by score descending. Overall coverage is `summary.line_coverage_pct`.

For each method with gaps above threshold (in priority order): invoke `superpowers:test-driven-development` targeting that specific uncovered path. Repeat until no methods above threshold.
```

- [ ] **Step 4: Verify the file reads correctly**

Read `skills/java-tdd/SKILL.md` and confirm:
- No remaining `jkit coverage` or `bin/jkit` references
- `jacoco-filter` command is present in checklist, diagram, and Step 5
- JSON shape note (`methods[]`, `summary.line_coverage_pct`) is present

- [ ] **Step 5: Commit**

```bash
git add skills/java-tdd/SKILL.md
git commit -m "chore: migrate java-tdd from jkit coverage to jacoco-filter"
```

---

## Task 4: Update `java-verify` skill

**Files:**
- Modify: `skills/java-verify/SKILL.md`

- [ ] **Step 1: Remove the API endpoint coverage checklist item**

The checklist in `java-verify` has this line:
```
- [ ] Check API endpoint coverage
```

Remove it entirely. "Check merged JaCoCo coverage" already exists as the preceding item; no replacement needed. The checklist should not reference API coverage until `codeskel api-coverage` is implemented.

- [ ] **Step 2: Update the process flow diagram**

Find this node (around line 26):
```
    "jkit coverage (merged jacoco)\njkit coverage --api" [shape=box];
```
Replace with:
```
    "jacoco-filter (merged jacoco)" [shape=box];
```

Find these two edges referencing it (around lines 36–37):
```
    "mvn verify" -> "jkit coverage (merged jacoco)\njkit coverage --api";
    "jkit coverage (merged jacoco)\njkit coverage --api" -> "Failures?";
```
Replace with:
```
    "mvn verify" -> "jacoco-filter (merged jacoco)";
    "jacoco-filter (merged jacoco)" -> "Failures?";
```

- [ ] **Step 3: Replace the coverage block in Step 3**

Find this block (around lines 90–103):
```markdown
**Step 3: Coverage check**

```bash
# Unit + integration combined (merged jacoco.xml)
bin/jkit coverage target/site/jacoco/jacoco.xml --summary --min-score 1.0

# API endpoint coverage: spec vs test source
bin/jkit coverage --api docs/domains/ src/test/java/
```

**Failures** (tests or quality): fix inline, re-run.

**Gaps only** (coverage below threshold or untested endpoints): ask:
> "Coverage gaps found: [list].
> A) Fix gaps now — run scenario-tdd / add unit tests (recommended)
> B) Proceed to code review — I'll note the gaps"
```

Replace with:
```markdown
**Step 3: Coverage check**

```bash
# Unit + integration combined (merged jacoco.xml)
jacoco-filter target/site/jacoco/jacoco.xml --summary --min-score 1.0
```

Output shape: `{"summary": {"line_coverage_pct": ..., "lines_covered": ..., "lines_missed": ..., "by_class": [...]}, "methods": [...]}`.
The gap list is `methods[]`; overall coverage is `summary.line_coverage_pct`.

> **Note:** API endpoint coverage (`codeskel api-coverage`) is not yet implemented. Endpoint gap analysis is skipped until that subcommand is available.

**Failures** (tests or quality): fix inline, re-run.

**Gaps only** (coverage below threshold): ask:
> "Coverage gaps found: [list].
> A) Fix gaps now — run scenario-tdd / add unit tests (recommended)
> B) Proceed to code review — I'll note the gaps"
```

- [ ] **Step 4: Verify the file reads correctly**

Read `skills/java-verify/SKILL.md` and confirm:
- No remaining `jkit` or `bin/jkit` references
- `jacoco-filter` is present in diagram and Step 3
- JSON shape note is present
- The `--api` block is gone and a note about `codeskel api-coverage` is in its place
- "untested endpoints" is removed from the gaps-only prompt

- [ ] **Step 5: Commit**

```bash
git add skills/java-verify/SKILL.md
git commit -m "chore: migrate java-verify from jkit coverage to jacoco-filter, note api-coverage gap"
```

---

## Task 5: Write codeskel new subcommands PRD

**Files:**
- Create: `docs/codeskel-new-subcommands-prd.md`

Follow the same structure and style as `docs/codeskel-domains-prd.md`.

- [ ] **Step 1: Create the PRD document**

Write `docs/codeskel-new-subcommands-prd.md` with this exact content:

```markdown
# codeskel — New Java/Spring Subcommands PRD

Five new subcommands for the `codeskel` CLI, covering Spring infrastructure scanning,
API contract boundary detection, schema migration parsing, project health inspection,
and API endpoint test coverage. All subcommands follow existing codeskel conventions:
compact JSON to stdout, `--pretty`, `--output <path>`, exit codes 0/1/2, and reuse
`.codeskel/cache.json` when present (run `codeskel scan` first if not).

---

## `codeskel spring <project_root>`

**Problem:** Identifying Spring infrastructure components (repositories, Feign clients,
Kafka producers/consumers, Redis, REST clients) requires reading many source files.
A deterministic scanner eliminates this token cost.

**Approach:** Reuse the existing tree-sitter parse cache from `codeskel scan`.
Annotation and supertype detection is already collected — no new parsing logic needed.

### Detection Signals

| Component | Signal |
|---|---|
| Repositories | `@Repository`, `extends JpaRepository`, `extends CrudRepository` |
| Feign clients | `@FeignClient` |
| Kafka consumers | `@KafkaListener` |
| Kafka producers | `KafkaTemplate` injection, `KafkaProducer` injection |
| Redis | `RedisTemplate`, `extends RedisRepository` |
| REST clients | `RestTemplate`, `WebClient` bean injections |

### CLI Interface

```
codeskel spring <project_root> [OPTIONS]

Options:
  --src <path>      Override source root [default: src/main/java]
  --output <path>   Write JSON to file [default: stdout]
  --pretty          Pretty-print output
```

### Output Format

```json
{
  "repositories": ["OrderRepository", "CustomerRepository"],
  "feign_clients": ["InventoryFeignClient", "PaymentFeignClient"],
  "kafka_consumers": ["OrderCreatedConsumer"],
  "kafka_producers": ["OrderEventProducer"],
  "redis_operations": ["OrderCacheRepository"],
  "rest_templates": []
}
```

### Non-Goals

- Does not read method bodies
- Does not infer message schemas or topic names
- Does not generate configuration (Claude's responsibility)

---

## `codeskel contract <project_root>`

**Problem:** Identifying what a service exposes and what it consumes requires reading
controllers and Feign client interfaces. The codeskel cache already contains signatures
and annotation values — no additional file reads needed.

**Approach:** Read exposed endpoints from `@RequestMapping` annotation values on
controller classes and methods. Read consumed clients from `@FeignClient` interfaces.

### CLI Interface

```
codeskel contract <project_root> [OPTIONS]

Options:
  --src <path>        Override source root [default: src/main/java]
  --openapi <path>    OpenAPI spec path [default: docs/domains/*/api-spec.yaml, merged]
  --output <path>     Write JSON to file [default: stdout]
  --pretty            Pretty-print output
```

### Output Format

```json
{
  "exposed_endpoints": [
    { "method": "POST", "path": "/invoices/bulk", "controller": "InvoiceController" }
  ],
  "consumed_clients": [
    {
      "name": "InventoryFeignClient",
      "service": "inventory-service",
      "methods": ["checkStock", "reserveItems"]
    }
  ]
}
```

### Implementation Notes

- Endpoint path = class-level `@RequestMapping` value + method-level `@GetMapping`/`@PostMapping`/etc. value, concatenated
- `service` field on consumed clients derived from `@FeignClient(name = "...")` or `value` attribute
- Reuse `annotations[].value` from cached signatures — no raw source reads

### Non-Goals

- Does not validate that declared endpoints match an OpenAPI spec
- Does not detect internal service-to-service calls via `RestTemplate`

---

## `codeskel schema <project_root>`

**Problem:** Reviewing pending schema migrations requires parsing Liquibase or Flyway
files. Feeding raw XML or SQL to the LLM is token-expensive and error-prone.

**Approach:** XML/SQL parsing only — no tree-sitter required. Auto-detect Liquibase vs
Flyway from file structure.

### CLI Interface

```
codeskel schema <project_root> [OPTIONS]

Options:
  --changelog <path>  Override changelog path
  --output <path>     Write JSON to file [default: stdout]
  --pretty            Pretty-print output
```

### Detection

- **Liquibase:** `src/main/resources/db/changelog-master.xml` or `src/main/resources/db/changelog/*.xml`
- **Flyway:** `src/main/resources/db/migration/V*.sql`

### Output Format

```json
{
  "tool": "liquibase",
  "applied": ["V001__initial_schema.sql", "V002__add_bulk_invoice.sql"],
  "pending": [],
  "tables_created": ["bulk_invoice"],
  "columns_added": [{ "table": "invoice", "column": "bulk_id" }],
  "indexes_created": ["idx_invoice_bulk"]
}
```

### Non-Goals

- Does not execute migrations
- Does not connect to a live database
- Does not infer business meaning of schema changes

---

## `codeskel project <project_root>`

**Problem:** Assessing a project's tooling and test coverage posture requires reading
`pom.xml` and counting test files. Reading raw `pom.xml` (200+ lines) in the LLM is
wasteful when only a few fields are needed.

**Approach:** Parse `pom.xml` directly and count test files by naming convention. No
source scan or tree-sitter required.

### CLI Interface

```
codeskel project <project_root> [OPTIONS]

Options:
  --pom <path>     Override pom.xml path [default: pom.xml]
  --src <path>     Override source root [default: src/main/java]
  --test <path>    Override test root [default: src/test/java]
  --output <path>  Write JSON to file [default: stdout]
  --pretty         Pretty-print output
```

### Detection Signals

| Field | Signal |
|---|---|
| `spring_boot_version` | `<parent><version>` in pom.xml |
| `quality_tools` | `maven-checkstyle-plugin`, `maven-pmd-plugin`, `spotbugs-maven-plugin` |
| `has_jacoco` | `jacoco-maven-plugin` in pom.xml |
| `has_failsafe` | `maven-failsafe-plugin` in pom.xml |
| `has_testcontainers` | `testcontainers` dependency in pom.xml |
| `has_springdoc` | `springdoc-openapi` dependency in pom.xml |
| Unit tests | `*Test.java` files in test root |
| Integration tests | `*IT.java` files in test root + `maven-failsafe-plugin` |
| Contract tests | `spring-cloud-contract-verifier` dependency OR WireMock stub files |

### Output Format

```json
{
  "spring_boot_version": "3.2.1",
  "quality_tools": ["checkstyle"],
  "missing_quality_tools": ["pmd", "spotbugs"],
  "has_jacoco": true,
  "has_unit_tests": true,
  "has_integration_tests": false,
  "has_contract_tests": false,
  "has_testcontainers": false,
  "has_failsafe": false,
  "has_springdoc": true,
  "test_file_count": { "unit": 42, "integration": 0, "contract": 0 }
}
```

### Non-Goals

- Does not run Maven
- Does not infer quality score or make recommendations

---

## `codeskel api-coverage <domains_dir> <test_src_dir>`

**Problem:** Verifying that every declared API endpoint has a RestAssured test requires
diffing YAML specs against test source — a task that requires reading many files.

**Approach:** Parse all `api-spec.yaml` files for declared endpoints. Scan test source
for RestAssured URL string literals. Diff and report gaps.

### CLI Interface

```
codeskel api-coverage <domains_dir> <test_src_dir> [OPTIONS]

Options:
  --output <path>   Write JSON to file [default: stdout]
  --pretty          Pretty-print output
```

### Endpoint Extraction

- **Declared:** All `api-spec.yaml` files under `<domains_dir>`. Extract `paths` keys and HTTP methods from OpenAPI structure.
- **Tested:** Scan Java files in `<test_src_dir>` for RestAssured call patterns: `.get("/path")`, `.post("/path")`, `.put("/path")`, `.delete("/path")`, `.patch("/path")`.

### Output Format

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

### Implementation Notes

- Path matching is exact (no regex or template variable substitution)
- A declared endpoint is considered tested if any test file contains a matching method + path literal
- `gaps` is sorted by `declared_in` path, then by `method`, for stable output

### Non-Goals

- Does not verify request/response schema conformance
- Does not run tests
- Does not parse path template variables (e.g., `/invoices/{id}` is matched as-is)

---

## Exit Codes

Follows existing `codeskel` conventions:
- `0` = success
- `1` = fatal error
- `2` = partial success with warnings
```

- [ ] **Step 2: Verify the document**

Read `docs/codeskel-new-subcommands-prd.md` and confirm:
- All five subcommands are present: `spring`, `contract`, `schema`, `project`, `api-coverage`
- Each has: Problem, CLI Interface, Output Format, Non-Goals
- Exit codes section is present
- No TBD or placeholder text

- [ ] **Step 3: Commit**

```bash
git add docs/codeskel-new-subcommands-prd.md
git commit -m "docs: add codeskel new subcommands PRD (spring, contract, schema, project, api-coverage)"
```
