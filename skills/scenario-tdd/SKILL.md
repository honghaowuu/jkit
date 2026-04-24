---
name: scenario-tdd
description: Use when implementing integration test scenarios identified as gaps for a spec-delta run.
---

**Announcement:** At start: *"I'm using the scenario-tdd skill to implement integration test scenario gaps via TDD."*

## Iron Law

```
NO INTEGRATION TEST WITHOUT A FAILING HTTP TEST FIRST.

Write the RestAssured assertion after the endpoint already passes? Delete it. Start over.

No exceptions:
- Don't generate multiple tests at once then fix failures
- Don't write "placeholder" tests that always pass
- One scenario → RED → GREEN → next scenario
```

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "The unit tests already cover this logic" | Unit tests mock HTTP. Integration tests verify the actual endpoint wires correctly end-to-end. |
| "I'll write all scenarios first, then run them" | Batch generation produces batch failures. You lose the signal of which scenario caused what. |
| "The happy path passes, the error cases are obvious" | Auth failures, validation edge cases, and missing headers are where bugs live. Write the test. |
| "This endpoint is simple, one test is enough" | Each scenario is a contract. Simple endpoints have the same contract obligations. |

## Checklist

- [ ] Load java-coding-standards
- [ ] Detect Spring Boot version + prerequisites
- [ ] Read affected domains + run `scenarios gap` per domain
- [ ] TDD loop: per gap scenario
- [ ] Invoke java-verify

## Process Flow

```dot
digraph scenario_tdd {
    "Load java-coding-standards" [shape=box];
    "Detect SB version\n+ prerequisites" [shape=box];
    "Read affected domains\n+ run scenarios gap" [shape=box];
    "Gaps to implement?" [shape=diamond];
    "Done → invoke java-verify" [shape=doublecircle];
    "Next gap scenario" [shape=box];
    "Show scenario to human\n(lightweight gate)" [shape=box];
    "Write failing RestAssured test" [shape=box];
    "Run test → RED?" [shape=diamond];
    "Rewrite test once\n(still green? ask human)" [shape=box];
    "Fix until GREEN" [shape=box];
    "More gaps?" [shape=diamond];

    "Load java-coding-standards" -> "Detect SB version\n+ prerequisites";
    "Detect SB version\n+ prerequisites" -> "Read affected domains\n+ run scenarios gap";
    "Read affected domains\n+ run scenarios gap" -> "Gaps to implement?";
    "Gaps to implement?" -> "Done → invoke java-verify" [label="none"];
    "Gaps to implement?" -> "Next gap scenario" [label="yes"];
    "Next gap scenario" -> "Show scenario to human\n(lightweight gate)";
    "Show scenario to human\n(lightweight gate)" -> "Write failing RestAssured test" [label="approved"];
    "Show scenario to human\n(lightweight gate)" -> "Next gap scenario" [label="skip"];
    "Write failing RestAssured test" -> "Run test → RED?";
    "Run test → RED?" -> "Fix until GREEN" [label="yes"];
    "Run test → RED?" -> "Rewrite test once\n(still green? ask human)" [label="no (green immediately)"];
    "Rewrite test once\n(still green? ask human)" -> "Run test → RED?";
    "Fix until GREEN" -> "More gaps?";
    "More gaps?" -> "Next gap scenario" [label="yes"];
    "More gaps?" -> "Done → invoke java-verify" [label="no"];
}
```

## Detailed Flow

**Step 0: Load java-coding-standards**

Read `<plugin-root>/docs/java-coding-standards.md`. Apply all rules.

**Step 1: Detect Spring Boot version + prerequisites**

Read `<parent><version>` from `pom.xml`.

| Spring Boot version | Testing strategy |
|---|---|
| 3.1+ | `@SpringBootTest(RANDOM_PORT)` + Testcontainers (`@ServiceConnection`) + RestAssured |
| < 3.1 | `docker-compose.test.yml` → RestAssured against running container |

**Spring Boot 3.1+:** Check `pom.xml` for Testcontainers, RestAssured, WireMock. If missing: add from `templates/pom-fragments/testcontainers.xml`.

**Spring Boot < 3.1:** Resolve container runtime:
1. `docker compose` / `docker-compose`
2. `podman compose`
3. Neither → stop: *"No container runtime found. Install Docker or Podman and re-run."*

Check `docker-compose.test.yml` exists. If missing: copy from `templates/docker-compose.test.yml`.

**Step 2: Read affected domains + fetch gaps**

Read the `## Domains Changed` table from `.jkit/<run>/change-summary.md` (run directory passed by java-tdd). The first column lists the affected domains for this run.

For each affected domain, run:

```bash
scenarios gap <domain>
```

Each command returns a JSON array of `{endpoint, id, description}` objects. Collect across domains to form the authoritative work list for this run — process gaps in domain order as listed in `## Domains Changed`.

If every domain returns `[]` → no scenario gaps detected; complete immediately, invoke `java-verify`.

**Step 3: TDD loop**

Process gaps in the order they appear in change-summary.md (domain order preserved from spec-delta). For each gap scenario:

**Lightweight gate** — announce before writing:
> "Next: `POST /invoices/bulk` — `happy-path`: valid list of 3 → 201 + invoice IDs. Write this test?
> A) Yes (recommended)
> B) Edit this scenario
> C) Skip"

**Write the failing test** targeting exactly this scenario. One test method per scenario.

**Run:**
```bash
# SB 3.1+
JKIT_ENV=test direnv exec . mvn test -Dtest=<Domain>IntegrationTest#<methodName>

# SB < 3.1
<runtime> compose -f docker-compose.test.yml up -d
JKIT_ENV=test direnv exec . mvn test -Dtest=<Domain>IntegrationTest#<methodName>
```

- **RED (compilation or assertion failure):** expected — continue to fix.
- **GREEN immediately:** the test is wrong — it proves nothing. Rewrite it to actually fail. If still green after one rewrite attempt: stop and ask *"This scenario may already be covered. Skip it or adjust the assertion?"*

Fix production code or test setup until GREEN. Then move to next scenario.

**Test class location:** `src/test/java/<group-path>/<service>/<domain>/<Domain>IntegrationTest.java`

**Spring Boot 3.1+ template:**

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class BillingIntegrationTest {
    @Container @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");

    @RegisterExtension
    static WireMockExtension externalSvc = WireMockExtension.newInstance()
        .options(wireMockConfig().dynamicPort()).build();

    @LocalServerPort int port;
    @BeforeEach void setup() { RestAssured.port = port; }

    @Test void bulkInvoice_happyPath() { /* given/when/then */ }
}
```

**Spring Boot < 3.1 template:**

```java
class BillingIntegrationTest {
    static String baseUri = System.getenv().getOrDefault("SERVICE_BASE_URI", "http://localhost:8080");
    @BeforeAll static void setup() { RestAssured.baseURI = baseUri; }

    @Test void bulkInvoice_happyPath() { /* given/when/then */ }
}
```

**Failure classification:**
- Compilation failure or wrong assertion → fix generated test. Do NOT change production code for a test bug.
- Production code fails the correct assertion → fix production code via `superpowers:systematic-debugging`.
- After one self-fix pass still failing → invoke `superpowers:systematic-debugging`.

**Step 4: Invoke java-verify**

**REQUIRED SUB-SKILL: invoke `java-verify`** after all gap scenarios are covered.

scenario-tdd does NOT own the commit. The commit is `java-tdd`'s responsibility.

