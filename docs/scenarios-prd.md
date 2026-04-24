# scenarios — Product Requirements

**Version:** 2.0
**Language:** Rust
**Binary name:** `scenarios`

---

## Purpose

A deterministic CLI that owns two mechanical jobs for scenario-based testing, without burning LLM tokens:

1. **sync** — derive required test scenarios from `api-spec.yaml` and append missing entries to `test-scenarios.yaml`
2. **gap** — list scenarios in `test-scenarios.yaml` that lack a matching test method, as compact JSON

Both jobs are deterministic, idempotent, and safe to rerun.

**Design principle:** Reads structured inputs, emits structured outputs (compact JSON for gap, canonical YAML for sync). Claude consumes the outputs, not raw specs.

---

## Why not Schemathesis or similar?

Schemathesis is a **runtime fuzz tester** — it generates HTTP traffic from an OpenAPI spec and asserts live responses conform. It solves a different problem: dynamic conformance checking against a running server. It does not enumerate planning-level scenarios, does not maintain a test-case manifest, and cannot run until tests already exist.

Sync + gap are pre-implementation planning tools — they write a scenario manifest that humans and AI consume when authoring JUnit integration tests. Schemathesis is complementary: once tests exist, it can be added as a supplementary fuzzer. It is not a substitute.

Other alternatives surveyed (`dredd`, `prism`, `pact`, NIST `tcases`) are also runtime-oriented or produce output models that don't align with the flat-yaml convention. Chosen path: small Rust binary with a plain OpenAPI parser (`openapiv3` crate) plus local rules.

---

## Input files

| File | Used by | Purpose |
|---|---|---|
| `docs/domains/<domain>/api-spec.yaml` | sync | OpenAPI v3 source of truth for endpoints, required fields, response codes |
| `docs/domains/<domain>/test-scenarios.yaml` | sync (read + append), gap (read) | Flat YAML scenario manifest |

**test-scenarios.yaml schema** — flat list, one entry per scenario:

```yaml
- endpoint: "POST /invoices/bulk"
  id: happy-path
  description: valid list of 3 → 201 + invoice IDs

- endpoint: "POST /invoices/bulk"
  id: auth-missing-token
  description: missing token → 401
```

---

## CLI

```
scenarios sync <domain>                       # reconcile test-scenarios.yaml with api-spec.yaml
scenarios gap  <domain> [--test-root <path>]  # list unimplemented scenarios as JSON
scenarios <domain>      [--test-root <path>]  # convenience: sync, then gap
```

| Argument | Default | Description |
|---|---|---|
| `<domain>` | required | Domain name. Resolves to `docs/domains/<domain>/` |
| `--test-root <path>` | `src/test/java/` | Root directory for test file search (gap only) |

**No `--new` flag.** Delta detection inside a binary is fragile (git state, timing, cache). If the caller wants "new only," snapshot the gap list before the change and diff against the post-change gap list.

---

## `sync` — scenario generation

### Algorithm

1. Parse `docs/domains/<domain>/api-spec.yaml` as OpenAPI v3
2. For every endpoint (`method + path`), derive the required scenario set (table below)
3. Load existing `test-scenarios.yaml` (missing → treat as empty)
4. Build the set of existing keys: `(endpoint, id)` tuples
5. For each derived scenario not present, **append** it to the yaml
6. Never modify, reorder, or remove existing entries
7. Warn (stderr) about orphaned entries — yaml `endpoint` values no longer in the spec — but do not prune them

### Derivation table

| Source in api-spec.yaml | Scenario ID |
|---|---|
| Always | `happy-path` |
| Each `required` field in request body | `validation-<field>-missing` |
| Each `required` field in query params | `validation-query-<field>-missing` |
| Each `required` field in path params | `validation-path-<field>-missing` |
| Response `400` or `422` | `validation-<description-slug>` (fallback: `validation-bad-request`) |
| Response `401` | `auth-missing-token` |
| Response `403` | `auth-<description-slug>` (fallback: `auth-forbidden`) |
| Response `404` | `not-found` |
| Response `409` | `business-<description-slug>` (fallback: `business-conflict`) |

`<description-slug>` = kebab-cased response description text. The category prefix comes from the row, not the description (e.g. description `"Duplicate idempotency key"` + row prefix `business-` → `business-duplicate-idempotency-key`).

### Edge cases

| Case | Behavior |
|---|---|
| Non-2xx response has no `description` | Use fallback ID (`validation-bad-request`, `auth-forbidden`, `business-conflict`) |
| Two responses with identical slug under one endpoint | Keep first, warn to stderr for the rest |
| Human-added scenario ID not produced by the table | Preserve untouched (append-only guarantees this) |
| Endpoint present in yaml but removed from spec | Preserve; warn to stderr — humans may still want the history |
| `required` list absent on a body schema | Treat as no required fields; skip `validation-<field>-missing` rows |
| `api-spec.yaml` missing | Exit 1 with error — sync requires a spec |
| `test-scenarios.yaml` missing | Create it with derived entries |
| `oneOf` / `anyOf` body schemas | Apply to each branch independently; dedupe by `(endpoint, id)` |

### Output formatting

- Use `serde_yaml` for write; preserve a blank line between entries to match the hand-maintained style
- If no new entries were appended, **do not rewrite the file** — avoid spurious diffs
- On success, stderr: `sync: <N> added, <M> already present, <K> orphaned`

---

## `gap` — unimplemented detection

### Algorithm

1. Load `docs/domains/<domain>/test-scenarios.yaml` (missing → output `[]`, exit 0)
2. For each scenario, convert `id` kebab-case → camelCase (`happy-path` → `happyPath`, `validation-empty-list` → `validationEmptyList`)
3. Search `*Test.java` under `--test-root` for method declarations matching `void <camelCaseId>\b`
4. A scenario is **implemented** if at least one match exists
5. Emit JSON array of `{endpoint, id, description}` for every scenario with no match

Use a single `grep -rn --include="*Test.java"` call with an alternation pattern across all IDs to minimise filesystem work.

### Output

Compact single-line JSON to stdout:

```json
[{"endpoint":"POST /invoices/bulk","id":"happy-path","description":"valid list of 3 → 201 + invoice IDs"}]
```

Empty → `[]`.

---

## Default (no subcommand)

`scenarios <domain>` = `sync` then `gap`, in that order. Stdout is the gap JSON; sync reports to stderr. This lets spec-delta collapse its Step 7b + Step 9 into one call:

```bash
scenarios billing
```

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (including zero gaps, zero new entries) |
| `1` | Hard error — YAML parse failure, OpenAPI parse failure, missing required file for the requested subcommand, I/O failure |

---

## Suggested dependencies

```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
serde_json = "1"
clap = { version = "4", features = ["derive"] }
openapiv3 = "2"
heck = "0.5"
```

---

## Installation

Binary at `bin/scenarios`. `bin/` is on PATH, so callers invoke it as `scenarios` with no prefix.

---

## Impact on spec-delta

- **Step 7b** ("Sync test-scenarios.yaml") → replaced by `scenarios sync <domain>` per affected domain. The in-prompt derivation table is removed from the skill — the binary owns that logic.
- **Step 9** ("Scenario gap detection") → `scenarios gap <domain>`.
- Or collapse both into one call: `scenarios <domain>`.
