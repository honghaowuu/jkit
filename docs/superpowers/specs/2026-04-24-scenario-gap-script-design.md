# Design: scenario-gap Rust Binary

**Date:** 2026-04-24

## Summary

Replace the `scenario-gap` LLM skill with a deterministic Rust binary. The binary reads a YAML scenario list, greps test files for implemented method names, and outputs a JSON gap list — zero LLM tokens for gap detection.

## File Format

**Location:** `docs/domains/<domain>/test-scenarios.yaml`  
**Maintained by:** spec-delta Step 7b (AI-only, append-only)

Flat YAML list — one entry per scenario, 3 fields each:

```yaml
- endpoint: "POST /invoices/bulk"
  id: happy-path
  description: valid list of 3 → 201 + invoice IDs

- endpoint: "POST /invoices/bulk"
  id: auth-missing-token
  description: missing token → 401

- endpoint: "GET /invoices/{id}"
  id: not-found
  description: non-existent ID → 404
```

**Why flat list:** spec-delta appends new blocks as plain lines — no indentation, no brackets, no key lookup. The binary groups by endpoint internally.

## CLI Interface

```
scenario-gap <domain> [--test-root <path>] [--new]
```

| Argument | Default | Description |
|---|---|---|
| `<domain>` | required | Domain name (e.g., `billing`); derives `docs/domains/<domain>/test-scenarios.yaml` |
| `--test-root` | `src/test/java/` | Test source root |
| `--new` | off | Only check scenario IDs added as new lines in `git diff HEAD -- docs/domains/<domain>/test-scenarios.yaml` |

**Output (stdout, compact JSON):**

```json
[
  {"endpoint": "POST /invoices/bulk", "id": "happy-path", "description": "valid list of 3 → 201 + invoice IDs"},
  {"endpoint": "POST /invoices/bulk", "id": "auth-missing-token", "description": "missing token → 401"}
]
```

- Empty array `[]` = no gaps
- Exit code `0` = success (including zero gaps)
- Exit code `1` = error (file not found, YAML parse failure, git error)

**Gap detection:** convert each scenario `id` from kebab-case to camelCase, grep for `void <camelCaseId>\b` in `--include="*Test.java"` files under `--test-root`. A scenario is implemented if its camelCase slug appears in at least one method declaration.

## Binary

- **Language:** Rust
- **Location:** `bin/scenario-gap`
- **PATH:** `bin/` is automatically added to PATH — called as `scenario-gap` with no prefix

## Skill Changes

### `skills/spec-delta/SKILL.md` — Step 9

Replace sub-skill invocation with:

```bash
scenario-gap <domain> --new
```

Read JSON output; write gaps into `change-summary.md`. If output is `[]`, omit the Test Scenario Gaps section.

### `skills/scenario-gap/SKILL.md` — deleted

The skill is replaced by the binary. No LLM reasoning needed for gap detection.

### `skills/spec-delta/SKILL.md` — Step 7b format update

Update the file extension reference from `test-scenarios.md` to `test-scenarios.yaml` throughout Step 7b and the directory structure comment.

### `skills/publish-contract/SKILL.md` — strip `bin/` prefix

```bash
# before → after
bin/contract-push.sh    → contract-push.sh
bin/marketplace-publish.sh → marketplace-publish.sh
bin/marketplace-sync.sh → marketplace-sync.sh
```

### `skills/generate-feign/SKILL.md` — strip `bin/` prefix

```bash
bin/install-contracts.sh → install-contracts.sh
```
