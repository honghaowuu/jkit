# jkit CLI — Product Requirements

**Version:** 1.0
**Language:** Rust
**Binary name:** `jkit`

---

## Purpose

A unified Rust CLI replacing the separate `codeskel` and `jacoco-filter` tools.
Provides deterministic, token-efficient analysis of Java/Spring Boot projects so
Claude skills can make accurate decisions without reading raw XML or Java source files.

**Design principle:** Each subcommand reads raw project files and outputs compact JSON.
Claude consumes the JSON summary, not the raw files. This eliminates token waste and
reduces hallucination risk from large file reads.

---

## Subcommands

### `jkit skel`

Subdomain detection and Javadoc scanning. Absorbs `codeskel`.

#### `jkit skel domains <project_root>`

Scans a Spring Boot project and detects logical subdomains by package structure
and annotation patterns.

**Detection rules:**

| Signal | Role |
|---|---|
| Package name segments (`com.example.billing`) | Primary grouping key |
| `@RestController` base path prefix (`/billing/**`) | Primary confirmation |
| `@Entity` / `@Aggregate` package grouping | Secondary |
| `@Service` package grouping | Secondary |

**Options:**
```
--output <path>       Write JSON to file (default: stdout)
--pretty              Pretty-print output
--min-classes <n>     Minimum classes to qualify as a subdomain [default: 2]
--src <path>          Override source root [default: src/main/java]
```

**Output:**
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

**Implementation notes:**
- Parse Java source with tree-sitter — no raw regex
- Group by top-level package segment after the group ID prefix
  (e.g., `com.newland` prefix → `billing` from `com.newland.billing`)
- Cache scan results in `.jkit/cache.json`; re-scan if source files are newer

---

### `jkit coverage <jacoco_xml>`

Parses `target/site/jacoco/jacoco.xml` and outputs prioritized coverage gaps.
Absorbs `jacoco-filter`.

**Options:**
```
--summary             Output summary table only (no per-method detail)
--min-score <f>       Minimum gap score to include [default: 1.0]
--output <path>       Write JSON to file (default: stdout)
```

**Output:**
```json
{
  "summary": { "total_methods": 120, "covered": 98, "gaps": 5 },
  "gaps": [
    {
      "class": "com.example.billing.InvoiceService",
      "method": "cancelBulkInvoice",
      "score": 2.4,
      "missing_branches": ["exception path", "empty list guard"]
    }
  ]
}
```

---

### `jkit scan spring`

Scans a Spring Boot project and identifies components relevant to integration testing.

**Options:**
```
--src <path>          Override source root [default: src/main/java]
--output <path>       Write JSON to file (default: stdout)
```

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

**Detection signals:**
- `@Repository`, `extends JpaRepository`, `extends CrudRepository`
- `@FeignClient`
- `@KafkaListener`
- `@KafkaTemplate` usage, `KafkaProducer` injection
- `RedisTemplate`, `extends RedisRepository`
- `RestTemplate`, `WebClient` bean injections

---

### `jkit scan contract`

Identifies API contract boundaries: what this service exposes and what it consumes.

**Options:**
```
--src <path>          Override source root [default: src/main/java]
--openapi <path>      OpenAPI spec path [default: docs/domains/*/api-spec.yaml, merged]
--output <path>       Write JSON to file (default: stdout)
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

### `jkit scan schema`

Parses Liquibase or Flyway changelogs and outputs a structured summary of pending
and applied migrations.

**Options:**
```
--changelog <path>    Liquibase master changelog or Flyway migration dir
--output <path>       Write JSON to file (default: stdout)
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

### `jkit scan project`

Inspects `pom.xml` and project test structure to detect gaps in tooling and test coverage.

**Options:**
```
--pom <path>          Override pom.xml path [default: pom.xml]
--src <path>          Override source root [default: src/main/java]
--test <path>         Override test root [default: src/test/java]
--output <path>       Write JSON to file (default: stdout)
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

**Detection signals:**
- Quality tools: `maven-checkstyle-plugin`, `maven-pmd-plugin`, `spotbugs-maven-plugin` in pom.xml
- Integration tests: `maven-failsafe-plugin` in pom.xml + `*IT.java` files in test root
- Contract tests: `spring-cloud-contract-verifier` in pom.xml OR WireMock stub files
- Testcontainers: `testcontainers` dependency in pom.xml
- Spring Boot version: `<parent><version>` in pom.xml

---

## Non-goals

- Does not read method bodies
- Does not infer business logic or domain relationships
- Does not generate documentation or code (that is Claude's responsibility)
- Does not run Maven or Gradle — reads project files only

---

## Output format

All subcommands output compact JSON to stdout by default. No prose, no tables,
no color codes. Machine-readable first.

Use `--pretty` for human-readable output during development.

---

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Fatal error (file not found, parse failure) |
| 2 | Partial success with warnings |

---

## Build and distribution

Single Rust binary. Pre-built for three targets, shipped in the `jkit` plugin's `bin/`:

```
bin/jkit                       ← polyglot wrapper (Windows + Unix)
bin/jkit-linux-x86_64
bin/jkit-macos-aarch64
bin/jkit-windows-x86_64.exe
```

Build command:
```bash
cargo build --release --manifest-path /path/to/jkit/Cargo.toml
```

No runtime dependencies. No installation required for team members beyond `chmod +x bin/*`.
