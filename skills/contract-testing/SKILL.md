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
