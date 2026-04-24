# codeskel + jacoco-filter Migration — Design Spec

**Date:** 2026-04-24
**Status:** Approved

---

## Overview

The `bin/jkit` CLI binary is retired. Skills that called `bin/jkit skel` and `bin/jkit coverage` are migrated to call `codeskel` and `jacoco-filter` directly. Five unimplemented jkit subcommands (`scan spring`, `scan contract`, `scan schema`, `scan project`, `coverage --api`) are specified as new `codeskel` subcommands.

The plugin name, `.jkit/` working directories, and all other plugin structure remain unchanged.

---

## Part 1: Skills Migration

### 1.1 `publish-contract`

**Before:**
```bash
bin/jkit skel "src/main/java/${GROUP_PATH}/${SERVICE}/api/"
```

**After:**
```bash
codeskel scan "src/main/java/${GROUP_PATH}/${SERVICE}/api/" --lang java
codeskel get .codeskel/cache.json --path <controller_file>
```

- Controller detection: `signatures[].annotations[].name == "RestController"` or `"Controller"`
- Javadoc check: `signatures[].has_docstring` and `signatures[].docstring_text`
- After editing controllers to improve Javadoc: `codeskel rescan .codeskel/cache.json <path>` then re-run `codeskel get` to confirm

### 1.2 `scenario-gap`

**Before:**
```bash
bin/jkit skel src/test/java/<group-path>/<service>/<domain>/
```

**After:**
```bash
codeskel scan src/test/java/<group-path>/<service>/<domain>/ --lang java
codeskel get .codeskel/cache.json --index <i>   # per test class
```

- Collect method names from `signatures[]` where `kind == "method"`
- Matching logic (camelCase scenario ID → test method name) is unchanged

### 1.3 `java-tdd`

**Before:**
```bash
bin/jkit coverage target/site/jacoco/jacoco.xml --summary --min-score 1.0
```

**After:**
```bash
jacoco-filter target/site/jacoco/jacoco.xml --summary --min-score 1.0
```

- JSON shape change: old `{gaps: [...]}` → new `{summary: {line_coverage_pct, lines_covered, lines_missed, by_class}, methods: [...]}`
- Gap list is `methods[]`; overall coverage is `summary.line_coverage_pct`

### 1.4 `java-verify`

**Before:**
```bash
bin/jkit coverage target/site/jacoco/jacoco.xml --summary --min-score 1.0
bin/jkit coverage --api docs/domains/ src/test/java/
```

**After:**
```bash
jacoco-filter target/site/jacoco/jacoco.xml --summary --min-score 1.0
# API endpoint coverage check removed — restored when codeskel api-coverage is implemented
```

- Same JSON shape update as `java-tdd`
- The `--api` line is removed with an inline note in the skill; `java-verify` documents the gap

---

## Part 2: New `codeskel` Subcommands PRD

All new subcommands follow existing codeskel conventions:
- Compact JSON to stdout by default
- `--pretty` for human-readable output
- `--output <path>` to write to file
- Exit codes: `0` success, `1` fatal error, `2` partial success with warnings
- Reuse `.codeskel/cache.json` when already present; run `codeskel scan` internally if not

### 2.1 `codeskel spring <project_root>`

Scans `src/main/java` for Spring infrastructure components. Reuses tree-sitter parse cache.

**Detection signals:**

| Component | Signal |
|---|---|
| Repositories | `@Repository`, `extends JpaRepository`, `extends CrudRepository` |
| Feign clients | `@FeignClient` |
| Kafka consumers | `@KafkaListener` |
| Kafka producers | `KafkaTemplate` injection, `KafkaProducer` injection |
| Redis | `RedisTemplate`, `extends RedisRepository` |
| REST clients | `RestTemplate`, `WebClient` bean injections |

**Output:**
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

**Options:**
```
--src <path>      Override source root [default: src/main/java]
--output <path>   Write JSON to file [default: stdout]
--pretty          Pretty-print output
```

---

### 2.2 `codeskel contract <project_root>`

Identifies what this service exposes and what it consumes. Reads from the codeskel cache (controllers for exposed endpoints, `@FeignClient` interfaces for consumed clients).

**Endpoint extraction:** `@RequestMapping` value from `annotations[].value` on controller class and method signatures.

**Options:**
```
--src <path>        Override source root [default: src/main/java]
--openapi <path>    OpenAPI spec path [default: docs/domains/*/api-spec.yaml, merged]
--output <path>     Write JSON to file [default: stdout]
--pretty            Pretty-print output
```

**Output:**
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

---

### 2.3 `codeskel schema <project_root>`

Parses Liquibase or Flyway migration files. No tree-sitter required — XML/SQL parsing only.

**Detection:**
- Liquibase: `src/main/resources/db/changelog-master.xml` or `src/main/resources/db/changelog/*.xml`
- Flyway: `src/main/resources/db/migration/V*.sql`

**Options:**
```
--changelog <path>  Override changelog path
--output <path>     Write JSON to file [default: stdout]
--pretty            Pretty-print output
```

**Output:**
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

---

### 2.4 `codeskel project <project_root>`

Reads `pom.xml` and counts test files. No source scan required.

**Detection signals:**
- Spring Boot version: `<parent><version>` in pom.xml
- Quality tools: `maven-checkstyle-plugin`, `maven-pmd-plugin`, `spotbugs-maven-plugin`
- JaCoCo: `jacoco-maven-plugin`
- Failsafe: `maven-failsafe-plugin`
- Testcontainers: `testcontainers` dependency
- SpringDoc: `springdoc-openapi` dependency
- Test types: `*Test.java` (unit), `*IT.java` (integration), WireMock stub files or `spring-cloud-contract-verifier` (contract)

**Options:**
```
--pom <path>     Override pom.xml path [default: pom.xml]
--src <path>     Override source root [default: src/main/java]
--test <path>    Override test root [default: src/test/java]
--output <path>  Write JSON to file [default: stdout]
--pretty         Pretty-print output
```

**Output:**
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

---

### 2.5 `codeskel api-coverage <domains_dir> <test_src_dir>`

Compares declared API endpoints (from `api-spec.yaml` files) against RestAssured-tested endpoints (string literals matching URL patterns in test source). Restores the retired `jkit coverage --api` capability.

**Endpoint extraction:**
- Declared: parse all `api-spec.yaml` under `<domains_dir>`, extract `paths` keys and HTTP methods
- Tested: scan `<test_src_dir>` for RestAssured URL string literals (`.get("/path")`, `.post("/path")`, etc.)

**Options:**
```
--output <path>   Write JSON to file [default: stdout]
--pretty          Pretty-print output
```

**Output:**
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

Once implemented, `java-verify` restores the api-coverage check:
```bash
codeskel api-coverage docs/domains/ src/test/java/
```

---

## Non-goals

- `bin/jkit` wrapper script — skills call tools directly
- Changes to `.jkit/` working directory conventions
- Changes to any skill not listed above
