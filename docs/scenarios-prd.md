# scenarios — Product Requirements

**Version:** 2.1
**Language:** Rust
**Binary name:** `scenarios`

---

## Purpose

A deterministic CLI that owns the mechanical jobs of the scenario-based testing pipeline, without burning LLM tokens.

**Spec/manifest jobs** (used by spec-delta):

1. **sync** — derive required test scenarios from `api-spec.yaml` and append missing entries to `test-scenarios.yaml`
2. **gap** — list scenarios in `test-scenarios.yaml` that lack a matching test method, as compact JSON

**Implementation-loop jobs** (used by scenario-tdd):

3. **prereqs** — detect Spring Boot version, validate required test dependencies in `pom.xml`, resolve container runtime, ensure compose template is in place
4. **gap --run `<dir>`** — aggregate gap detection across the affected domains listed in `change-summary.md`, augment each entry with `test_class_path` + `test_method_name`, filter out entries marked skipped for the run
5. **skip** — record a per-run scenario skip so the lightweight gate doesn't re-prompt on resume

All jobs are deterministic, idempotent, and safe to rerun.

**Design principle:** Reads structured inputs, emits structured outputs (compact JSON for gap/prereqs, canonical YAML for sync). Claude consumes the outputs, not raw specs.

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
# Spec/manifest jobs
scenarios sync <domain>                          # reconcile test-scenarios.yaml with api-spec.yaml
scenarios gap  <domain>  [--test-root <path>]    # list unimplemented scenarios as JSON (single domain)
scenarios      <domain>  [--test-root <path>]    # convenience: sync, then gap

# Implementation-loop jobs
scenarios prereqs        [--apply] [--pom <path>]      # detect + (optionally) install test prerequisites
scenarios gap --run <dir> [--test-root <path>]         # aggregate gap across affected domains for a run
scenarios skip --run <dir> <domain> <id>               # record a per-run skip
```

| Argument | Default | Description |
|---|---|---|
| `<domain>` | required | Domain name. Resolves to `docs/domains/<domain>/` |
| `--test-root <path>` | `src/test/java/` | Root directory for test file search (gap only) |
| `--run <dir>` | — | Path to a `.jkit/<run>/` directory (must contain `change-summary.md`) |
| `--apply` | false | `prereqs` only. Without it, prereqs reports state but mutates nothing. |
| `--pom <path>` | `pom.xml` (cwd) | `prereqs` only. Path to the Maven project file. |

**No `--new` flag.** Delta detection inside a binary is fragile (git state, timing, cache). If the caller wants "new only," snapshot the gap list before the change and diff against the post-change gap list.

**No `--pending` flag.** `gap` is already idempotent — it returns only scenarios with no matching test method — so re-running it after partial implementation naturally yields the remaining work. Resume = re-run.

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

### `gap --run <dir>` — aggregate across affected domains

For driving the scenario-tdd implementation loop. Reads `<dir>/change-summary.md` and runs gap detection across every domain listed in its `## Domains Changed` table, returning one ordered JSON array.

**Algorithm:**

1. Open `<dir>/change-summary.md`. Parse the `## Domains Changed` markdown table; affected domains are the first column. Missing file or missing section → exit 1.
2. For each affected domain (in table order), run the standard `gap` algorithm.
3. If `<dir>/skipped-scenarios.json` exists, load it and filter results — drop any `(domain, endpoint, id)` listed there.
4. Augment each remaining entry with two derived fields (see below).
5. Concatenate per-domain results, preserving table order, and emit a single JSON array.

**Augmented entry shape:**

```json
{
  "domain": "billing",
  "endpoint": "POST /invoices/bulk",
  "id": "happy-path",
  "description": "valid list of 3 → 201 + invoice IDs",
  "test_class_path": "src/test/java/com/example/billing/BillingIntegrationTest.java",
  "test_method_name": "happyPath"
}
```

**Derived field rules:**

| Field | Rule |
|---|---|
| `test_method_name` | `camelCase(id)` — same transform `gap` already uses for matching. |
| `test_class_path` | If a file matching `*<DomainPascalCase>IntegrationTest.java` exists under `--test-root`, use that path. Otherwise, compute the default from `pom.xml` `<groupId>` + `<artifactId>` + domain: `<test-root>/<groupPath>/<artifactId>/<domain>/<DomainPascalCase>IntegrationTest.java`. If `pom.xml` is unreadable or lacks groupId, emit `null` and let the caller decide. |

**Exit codes:**

| Code | Meaning |
|---|---|
| `0` | Success (zero gaps emits `[]`) |
| `1` | `<dir>` missing, `change-summary.md` missing/malformed, or any per-domain `test-scenarios.yaml` parse failure |

---

## `prereqs` — detect + install test prerequisites

Owns the Java/Spring-Boot bootstrap phase of the scenario-tdd skill. The binary contains the canonical knowledge of "what does this project need to run integration tests" so the skill doesn't redraw the decision tree each invocation.

### Algorithm

1. Read `pom.xml` (path from `--pom`, default cwd). Parse `<parent><version>` → Spring Boot version. Missing/malformed → exit 1.
2. Pick the testing strategy:
   - SB ≥ 3.1 → `testcontainers`
   - SB < 3.1 → `compose`
3. Strategy-specific checks:
   - **testcontainers:** verify `<dependencies>` contains Testcontainers, RestAssured, WireMock. Missing → record in `missing_pom_deps`.
   - **compose:** verify RestAssured in `<dependencies>` (record if missing). Probe for container runtime in order: `docker compose`, `docker-compose`, `podman compose`. First hit wins → `runtime`. None found → record blocking error.
4. Strategy-specific files:
   - **testcontainers:** none required.
   - **compose:** verify `docker-compose.test.yml` at repo root. Missing → record in `missing_files`.
5. Without `--apply`: emit JSON describing current state and what *would* be done; mutate nothing.
6. With `--apply`: write missing pom fragments and copy missing template files; record each mutation in `actions_taken`.

### Bundled templates

Templates are compiled into the binary via `include_str!` so there is no drift between binary version and template content:

- `templates/pom-fragments/testcontainers.xml`
- `templates/pom-fragments/restassured.xml`
- `templates/pom-fragments/wiremock.xml`
- `templates/docker-compose.test.yml`

Source-of-truth for the templates lives at `<repo>/skills/scenario-tdd/templates/` (during binary build, these are copied into `crates/scenarios/templates/`).

### Output

Single JSON object to stdout:

```json
{
  "spring_boot_version": "3.2.1",
  "testing_strategy": "testcontainers",
  "runtime": null,
  "missing_pom_deps": [],
  "missing_files": [],
  "actions_taken": ["added testcontainers fragment to pom.xml"],
  "ready": true,
  "blocking_errors": []
}
```

Field semantics:

| Field | Type | Notes |
|---|---|---|
| `spring_boot_version` | string | From `<parent><version>` |
| `testing_strategy` | `"testcontainers"` \| `"compose"` | Derived from version |
| `runtime` | string \| null | Container runtime (`compose` strategy only); null otherwise |
| `missing_pom_deps` | string[] | Empty after a successful `--apply` |
| `missing_files` | string[] | Empty after a successful `--apply` |
| `actions_taken` | string[] | Populated by `--apply`; `[]` in dry-run |
| `ready` | bool | True when no blocking errors and (post-`--apply`) no missing items |
| `blocking_errors` | string[] | Human-readable; e.g. "no container runtime found" |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success — JSON describes state. `ready: false` is *not* a failure; the caller decides. |
| `1` | Could not read or parse `pom.xml`; could not write a fragment under `--apply`; I/O error. |

---

## `skip` — record a per-run scenario skip

When the lightweight gate in scenario-tdd accepts "skip this scenario," that decision needs to be recorded so resume doesn't re-prompt.

### Algorithm

1. Resolve `<dir>/skipped-scenarios.json`. Create with `[]` if absent.
2. Append `{"domain": "...", "endpoint": "...", "id": "..."}` if not already present. Endpoint is looked up from `test-scenarios.yaml` so the caller only needs `<domain> <id>`.
3. Idempotent — re-skipping is a no-op.

### CLI

```
scenarios skip --run .jkit/2026-04-25-foo billing happy-path
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Skip recorded (or already present) |
| `1` | `<dir>` missing, scenario id not found in domain's `test-scenarios.yaml`, or I/O error |

Per-run only. Permanent skips (scenarios that should never get tests) are out of scope for v2.1; revisit as a `skip: true` flag on `test-scenarios.yaml` entries if the need arises.

---

## Default (no subcommand)

`scenarios <domain>` = `sync` then `gap`, in that order. Stdout is the gap JSON; sync reports to stderr. This lets spec-delta collapse its Step 7b + Step 9 into one call:

```bash
scenarios billing
```

---

## Exit codes

Each subcommand documents its own exit codes above. Global convention:

| Code | Meaning |
|---|---|
| `0` | Success (including zero gaps, zero new entries, `prereqs` reporting `ready: false`) |
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
quick-xml = { version = "0.36", features = ["serialize"] }   # prereqs: pom.xml parsing
which = "6"                                                   # prereqs: docker/podman probe
pulldown-cmark = "0.12"                                       # gap --run: change-summary.md table parse
```

---

## Installation

Binary at `bin/scenarios`. `bin/` is on PATH, so callers invoke it as `scenarios` with no prefix.

---

## Impact on spec-delta

- **Step 7b** ("Sync test-scenarios.yaml") → replaced by `scenarios sync <domain>` per affected domain. The in-prompt derivation table is removed from the skill — the binary owns that logic.
- **Step 9** ("Scenario gap detection") → `scenarios gap <domain>`.
- Or collapse both into one call: `scenarios <domain>`.

---

## Impact on scenario-tdd

The new subcommands collapse three steps of the scenario-tdd skill into single binary calls:

- **Step 1 (Detect SB version + prerequisites)** → `scenarios prereqs --apply`. Replaces the SB-version branching, pom-fragment copying, and runtime resolution. The skill announces results from `actions_taken`.
- **Step 2 (Read affected domains + fetch gaps)** → `scenarios gap --run <dir>`. Replaces the per-domain shell loop and the model improvising `test_class_path` / `test_method_name` from endpoint strings. One call returns the authoritative ordered work list with paths and method names baked in.
- **Step 3 lightweight gate "Skip" branch** → `scenarios skip --run <dir> <domain> <id>`. The skip is now recorded; resume (re-running `gap --run`) honors it.

Net effect on the skill: ~75 lines reclaimed and the model never parses pom.xml, markdown tables, or Java identifier conventions itself.
