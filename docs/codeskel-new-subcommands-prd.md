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
