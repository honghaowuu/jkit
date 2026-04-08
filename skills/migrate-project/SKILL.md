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
