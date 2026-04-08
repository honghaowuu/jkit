---
name: publishing-service-contract
description: >
  Generates a SKILL.md file for a Java microservice by reading controller Javadoc
  and pom.xml, following the microservice.skill.template.md format. The generated
  skill documents the service's public API so other microservices can call it correctly.

  Trigger on: "generate skill for this service", "create microservice skill",
  "document this service for other services", "generate docs/skills for <service>",
  "/publish-contract".
---

# Publishing Service Contract

You are generating a `SKILL.md` for a Java microservice so other services can call
it correctly. Follow every step in order. Do not skip steps.

---

## Prerequisites: resolve `codeskel`

Before anything else, resolve the `codeskel` binary in this order:

1. `<plugin-root>/bin/codeskel-<os>-<arch>` where `<os>` is `linux`/`macos`/`windows` and `<arch>` is `x86_64`/`aarch64`
2. `codeskel` on `PATH`
3. If neither found, stop and tell the user:

```
codeskel not found.
Expected at <plugin-root>/bin/codeskel-<os>-<arch> or on PATH.
See plugin README for setup instructions.
```

Determine `<plugin-root>` as the directory containing this skill file (navigate up from `skills/publishing-service-contract/SKILL.md`).

---

## Step 1 — Extract Maven metadata and check for existing output

Run:
```bash
codeskel pom [project_root] --controller-path src/main/java/com/newland/<service>/api
```

The controller path follows the team convention: `src/main/java/com/newland/<service>/api/`.
If the user specifies a different path, use that instead.

**Error:** If `codeskel` exits 1 → stop:
> "Could not find pom.xml. Please run Claude from the project root, or install
> codeskel with `cargo install codeskel`."

Read from the JSON output:
- `service_name` → `<service-name>`
- `group_id` → SDK dependency groupId
- `version` → resolved literal version string
- `internal_sdk_deps[]` → `depends_on` candidates (already filtered to `-api`/`-sdk` deps matching root groupId)
- `existing_skill_path` → non-null means a skill already exists

**Check for existing output:** If `existing_skill_path` is not null:
> "A skill for `<service-name>` already exists at <existing_skill_path>.
> Overwrite it?"
Stop if user says no.

**Ask the user (one question at a time):**

1. Confirm `nacos_name`:
   > "The Nacos service name will default to `<service_name>`. Is this correct, or does
   > it have a different name in Nacos?"

2. Confirm internal dependencies (show `internal_sdk_deps`):
   > "I found these internal service dependencies: [list]. Should all of these appear
   > in `depends_on`? Remove any that are not direct runtime dependencies."
   If `internal_sdk_deps` is empty, skip this question and omit `depends_on` from output.

**Error:** If `group_id` or `service_name` is missing from output → ask user to provide them.

---

## Step 2 — Identify controller files and check Javadoc

Run once to index the controller path:
```bash
codeskel scan <project_root> --lang java --include src/main/java/com/newland/<service>/api
```

Then for each controller file, fetch its signatures:
```bash
codeskel get <cache> --path <ControllerFile.java>
```

**Identify controllers:** from `codeskel get` output, a file is a controller if its
class-level signature has `annotations[].name` equal to `"RestController"`,
`"Controller"`, or `"RequestMapping"`. Skip files with no matching class annotation.

**Identify public methods:** signatures where `kind == "method"` and
`modifiers` contains `"public"`.

**Error:** If no public method signatures found → stop:
> "No public methods found. Please point to the correct controller file or directory."

### Javadoc Quality Check — MANDATORY

For every public method signature, check `has_docstring` and `docstring_text`:

**Insufficient if any of these apply:**
- `has_docstring` is false
- `docstring_text` is null or empty
- `docstring_text` only restates the method name (e.g., method `getUserById`,
  docstring says "Gets user by id" — this is insufficient)

**If ANY method has missing or insufficient Javadoc:**

> "Some methods are missing sufficient Javadoc. I need to invoke the `comment` skill
> to enrich the documentation before I can generate the skill."

→ **Invoke the `comment` skill immediately** on the controller file(s)/directory.
→ **If the comment skill fails or the user rejects its output** → stop:
> "Cannot generate skill without sufficient Javadoc. Please add documentation first."
→ **After the comment skill completes** → discard all `codeskel get` output. Re-fetch
each controller file:
```bash
codeskel rescan <cache> <ControllerFile.java>
codeskel get <cache> --path <ControllerFile.java>
```
Do not use any in-memory signature data from before the comment skill ran.

---

## Step 3 — Map controller files to modules

Each controller file = one business module. Do not re-group across files.

- **Single file** → one module named after the controller class, minus "Controller"
  suffix (e.g., `UserController` → module "User")
- **Multiple files** → one module per file by the same naming rule. Exception: if two
  files share the same domain prefix (e.g., `OrderQueryController` and
  `OrderCommandController`), propose merging them into one "Order" module.

Present the proposed module list to the user:
> "I'll organize this service into the following modules:
> 1. [Module A] — from [ControllerA.java]
> 2. [Module B] — from [ControllerB.java]
> ...
> Does this look correct? You can rename, merge, or split modules."

Wait for confirmation before proceeding.

**The confirmed module list (after any user renames, merges, or splits) is the authoritative list for Step 5 layout decisions.**

---

## Step 4 — Extract fields and ask user for judgment-call fields

**Frontmatter `capabilities` = rollup of ALL modules** (including any that will
overflow to reference files). Every capability name + one-line description appears
here.

For each module, extract from Javadoc:

- **`capabilities`** (per-module): one capability per public method.
  Name = business action (not method name). Description = what it does in business
  terms. Inputs = key parameters.
- **`Primary Methods`**: 1–3 entry-point methods. Prefer state-changing methods
  (create, update, cancel, submit, process) over query methods. Tie-break: earlier
  declaration order in source wins.
- **`Representative Scenarios`**: 2–4 per module.
  Format: `When <business situation> → use <methodName>`
  Draw ONLY from Javadoc content. Do not fabricate or paraphrase method names as scenarios.
  If Javadoc is present but lacks enough business detail for a scenario, omit that method's scenario rather than fabricating one. If no methods have scenario-worthy Javadoc, skip this sub-section and note it in the module's Notes.
- **`Notes`**: constraints, idempotency requirements, preconditions explicitly stated
  in Javadoc.
- **`API Source`**: fully qualified class name of the controller.
- **`API Path Prefix`**: from the class-level signature in `codeskel get` output,
  find `annotations[]` where `name == "RequestMapping"` and use its `value`
  (e.g., `"/api/v1/users"`). If absent, derive the common prefix from method-level
  `RequestMapping`/`GetMapping`/`PostMapping` annotation values.

**Ask the user these questions one at a time (never batch):**

1. **`description`** — draft from class-level Javadoc:
   > "Here's a draft service description: '[draft]'. Does this capture what the
   > service does? Feel free to rewrite it."

2. **`use_when`** — cannot be inferred from code:
   > "In what business situations should another service call this service?
   > Please list 2–4 scenarios. Example: 'user subscribes to a plan'"

3. **`invariants`** — cannot be inferred from code:
   > "What business rules always hold for this service?
   > Example: 'user must exist in user-service before creating a subscription'"

4. **`keywords`** — offer a draft from module names and prominent Javadoc nouns:
   > "Draft keywords for skill matching: [draft list]. Correct or add to these?"

5. **`not_responsible_for`** — always ask, prevents routing mistakes:
   > "What domains does this service explicitly NOT handle?
   > This prevents Claude from routing unrelated tasks here. Answer 'none' if not applicable."

**`depends_on`:** Use the confirmed list from Step 1. Omit the field if the list is empty.

---

## Step 5 — Determine output structure

Count confirmed modules:

| Modules | Layout |
|---|---|
| ≤ 3 | All content in `SKILL.md` + `## References` section (openapi.yaml link always included) |
| > 3 | First 3 in `SKILL.md`; each remaining module in `reference/<module-name>.md`; `## References` section includes openapi.yaml link AND links to each overflow module file |

**`## Cross-Module Relations` — always present in SKILL.md:**
- 1 module → write: `N/A — single module service.`
- Multiple modules → scan Javadoc for cross-module mentions ("must call X before Y",
  "triggers Z", "requires valid subscription from billing-service"). If found, describe
  the dependency chain. If Javadoc is silent, ask:
  > "How do these modules interact with each other? For example, does one module
  > need to complete before another can run?"
  Use the user's answer. Include overflow modules if they interact with SKILL.md modules.

---

## Step 6 — Generate openapi.yaml

Check if `springdoc-openapi-maven-plugin` is present in `pom.xml`.

**If not present, edit `pom.xml` using the file edit tool and add this plugin block inside the `<build><plugins>` section:**

```xml
<plugin>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-maven-plugin</artifactId>
    <version>1.4</version>
    <executions>
        <execution>
            <id>integration-test</id>
            <goals><goal>generate</goal></goals>
        </execution>
    </executions>
    <configuration>
        <outputFileName>openapi.yaml</outputFileName>
        <outputDir>${project.basedir}/docs/skills/{{service-name}}/reference</outputDir>
    </configuration>
</plugin>
```

**Run:**
```bash
mvn springdoc-openapi:generate
```

**If the build fails** (e.g., app cannot start in this environment) → inform the user:
> "OpenAPI generation failed — the app may need a running database or other
> infrastructure. You can run `mvn springdoc-openapi:generate` manually later.
> I'll continue without openapi.yaml."
Skip to Step 7.

---

## Step 7 — Write output files

Create directory `docs/skills/<service-name>/` and write:

### `docs/skills/<service-name>/SKILL.md`

**Before writing:** Omit the `not_responsible_for` block entirely (including the key) if the user answered 'none'. Omit the `depends_on` block entirely if the list is empty.

```markdown
---
service: <service-name>
description: <confirmed description>
nacos_name: <confirmed nacos_name>

keywords:
  - <keyword>

use_when:
  - <scenario>

not_responsible_for:
  - <domain>

capabilities:
  - name: <capability_name>
    description: <business description>
    inputs: [<key inputs>]

depends_on:
  - <service>

invariants:
  - <rule>
---

## Overview

<2–3 sentences>

---

## Module: <Name>

### Summary
<what this module handles>

### Capabilities
- <capability>

### Primary Methods ⭐
- `<methodName>`

### Representative Scenarios
- When <situation> → use `<methodName>`

### API Source
`<fully.qualified.ClassName>`

**SDK Maven dependency:**
```xml
<dependency>
    <groupId>{{groupId}}</groupId>
    <artifactId>{{artifactId}}</artifactId>
    <version>{{resolved-version}}</version>
</dependency>
```

### API Path Prefix
`/api/v1/<resource>`
> To read OpenAPI details for this module without loading the entire file:
> 1. Run: `grep -n "/api/v1/<resource>" docs/skills/<service-name>/reference/openapi.yaml` (path is relative to the Java project root)
> 2. Note the matching line numbers
> 3. Read only the line range that covers the matching path block (include ~20 lines of context around each match for schema details)

### Notes
- <constraint>

---

## Cross-Module Relations ⭐
<relations or "N/A — single module service.">

---

## References

The following modules are documented in separate files. Read them when the task
involves their domain:

- [openapi.yaml](reference/openapi.yaml) — Full API spec. **Do NOT read whole.**
  Use each module's `API Path Prefix` to grep for the relevant section, then read
  only that line range.
- [ModuleName](reference/module-name.md) — <one-line description>   ← overflow only
```

### `docs/skills/<service-name>/reference/<module-name>.md` (overflow only)

Each overflow module gets its own file with a single module section in the same
format as above (Summary, Capabilities, Primary Methods, Representative Scenarios,
API Source, API Path Prefix, Notes). No Cross-Module Relations section.

### `docs/skills/<service-name>/reference/openapi.yaml`

Written by Step 6. Absent if generation failed.
