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
