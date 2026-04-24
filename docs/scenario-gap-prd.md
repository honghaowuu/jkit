# scenario-gap — Product Requirements

**Version:** 1.0
**Language:** Rust
**Binary name:** `scenario-gap`

---

## Purpose

A deterministic CLI tool that detects unimplemented test scenarios for a domain. It reads a YAML scenario list, greps test files for matching method declarations, and outputs a compact JSON gap list — consuming zero LLM tokens.

**Design principle:** Reads structured input, outputs compact JSON. Claude consumes the JSON, not raw files.

---

## Input File

**Location:** `docs/domains/<domain>/test-scenarios.yaml`

Flat YAML list maintained by spec-delta. Each entry has exactly three fields:

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

---

## CLI Interface

```
scenario-gap <domain> [--test-root <path>] [--new]
```

| Argument | Default | Description |
|---|---|---|
| `<domain>` | required | Domain name (e.g., `billing`). Derives path `docs/domains/<domain>/test-scenarios.yaml` |
| `--test-root <path>` | `src/test/java/` | Root directory to search for test files |
| `--new` | off | Only check scenario IDs that appear as added lines in `git diff HEAD -- docs/domains/<domain>/test-scenarios.yaml` |

---

## Gap Detection

For each scenario entry to check:

1. Convert `id` from kebab-case to camelCase (e.g., `happy-path` → `happyPath`, `validation-empty-list` → `validationEmptyList`)
2. Search for a method declaration matching `void <camelCaseId>\b` in all `*Test.java` files under `--test-root`
3. A scenario is **implemented** if at least one matching method declaration is found
4. A scenario is a **gap** if no match is found

Use a single `grep -rn --include="*Test.java"` call with an alternation pattern across all scenario IDs to minimise filesystem operations.

---

## `--new` Filtering

When `--new` is passed:

1. Run `git diff HEAD -- docs/domains/<domain>/test-scenarios.yaml`
2. Extract `id` values from added lines (lines starting with `+  id:`)
3. Only check scenarios whose `id` appears in that set
4. If the set is empty (nothing new) → output `[]` and exit 0

---

## Output

Compact single-line JSON to stdout:

```json
[{"endpoint":"POST /invoices/bulk","id":"happy-path","description":"valid list of 3 → 201 + invoice IDs"},{"endpoint":"POST /invoices/bulk","id":"auth-missing-token","description":"missing token → 401"}]
```

Empty array when no gaps:

```json
[]
```

---

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success (including zero gaps) |
| `1` | Error (file not found is not an error — outputs `[]` and exits 0; errors are YAML parse failure, git failure) |

---

## Suggested Dependencies

```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
serde_json = "1"
clap = { version = "4", features = ["derive"] }
```

---

## Installation

Binary is placed at `bin/scenario-gap`. The `bin/` directory is automatically added to PATH, so callers invoke it as `scenario-gap` with no prefix.
