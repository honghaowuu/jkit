---
name: scenario-gap
description: Use when detecting unimplemented test scenarios for a domain that has a test-scenarios.md file. Invoked by spec-delta during change analysis.
---

**Announcement:** At start: *"I'm using the scenario-gap skill to detect unimplemented scenarios for the [domain] domain."*

## Input (passed by spec-delta)

- Domain name (e.g., `billing`)
- Test source root: `src/test/java/`

`test-scenarios.md` is generated and kept up to date by spec-delta (Step 7b) and may also be extended by humans. The missing-file guard in Step 1 handles domains where the file has not yet been created.

## `test-scenarios.md` Format

Scenario IDs (before the colon) are kebab-case slugs that map to test method names via camelCase conversion.

```markdown
# Test Scenarios: billing

## POST /invoices/bulk
- happy-path: valid list of 3 → 201 + invoice IDs
- validation-empty-list: empty list → 400
- validation-negative-amount: negative amount → 422
- auth-missing-token: missing token → 401
- business-duplicate-key: duplicate idempotency key → 409

## GET /invoices/{id}
- happy-path: existing invoice → 200 + full details
- not-found: non-existent ID → 404
- auth-other-tenant: other tenant's invoice → 403
```

## Process

**Step 1: Parse scenario list**

Read `docs/domains/<domain>/test-scenarios.md`. If the file does not exist → return empty gap list.

Extract all `{endpoint, scenario-id, scenario-description}` triples.

**Step 2: Convert slugs and locate test directory**

Convert every scenario ID from kebab-case to camelCase (e.g., `happy-path` → `happyPath`, `validation-empty-list` → `validationEmptyList`).

Locate the domain test directory:

```bash
find src/test/java -type d -name "<domain>" | head -1
```

If no directory is found → all scenarios are gaps.

**Step 3: Single grep for all slugs**

Build one grep alternation pattern from all camelCase slugs and run a single command:

```bash
grep -rn "void \(happyPath\|validationEmptyList\|authMissingToken\|...\)\b" \
  <test-dir> --include="*Test.java"
```

- Use `void <slug>\b` to match method declarations and avoid false positives (e.g., `happyPathEdgeCase` must not match `happyPath`).
- A scenario is **implemented** if its camelCase slug appears in the grep output.

> **Why not codeskel?** codeskel's default excludes (`**/*Test.java`, `**/test/**`) skip all test files silently. grep avoids that entirely and replaces N+1 cache queries with one command.

**Step 4: Return gap list**

Return all unmatched scenarios as:

```
[{domain, endpoint, scenario_id, scenario_description}, ...]
```

Caller (spec-delta) writes this into the **Test Scenario Gaps** section of change-summary.md.
