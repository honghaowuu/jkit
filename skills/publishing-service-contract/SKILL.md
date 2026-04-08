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
