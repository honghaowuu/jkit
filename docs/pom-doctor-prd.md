# pom-doctor — Product Requirements

**Version:** 1.0
**Language:** Rust
**Binary name:** `pom-doctor`

---

## Purpose

A deterministic CLI that owns **all** `pom.xml` mutations for the jkit pipeline. Higher-level binaries (`scenarios`) and skills (`java-tdd`, `java-verify`, `scenario-tdd`) delegate pom-checking and pom-fragment installation to `pom-doctor` so:

1. There is **one** XML parser, one mutation engine, one set of bundled fragment templates — no drift across consumers.
2. The error model and output schema are uniform — every caller consumes the same JSON shape.
3. Pom mutation, the most error-prone in-prompt operation in the pipeline, lives in a single typed binary with tests.

**Design principle:** pom-doctor is a primitive. It does not detect Spring Boot versions, probe runtimes, or copy non-pom files. Composite operations (e.g. "set up scenario testing for this project") live in higher-level binaries that compose pom-doctor with their own concerns.

---

## CLI

```
pom-doctor prereqs --profile <profile> [--apply] [--pom <path>]
```

| Argument | Default | Description |
|---|---|---|
| `--profile <profile>` | required | One of: `testcontainers`, `compose`, `jacoco`, `quality`, `smart-doc` |
| `--apply` | false | Without it: report state, mutate nothing. With it: install missing fragments. |
| `--pom <path>` | `pom.xml` (cwd) | Path to the Maven project file |

---

## Profiles

Each profile names a pom-fragment bundle the binary knows about. Templates are compiled into the binary via `include_str!` from `crates/pom-doctor/templates/`.

| Profile | Fragments | Inserts under |
|---|---|---|
| `testcontainers` | Testcontainers JUnit 5 + PostgreSQL + RestAssured + WireMock + Spring Boot Testcontainers ServiceConnection | `<dependencies>` |
| `compose` | RestAssured | `<dependencies>` |
| `jacoco` | jacoco-maven-plugin (prepare-agent + report goals) | `<build><plugins>` |
| `quality` | Spotless (google-java-format) + PMD + SpotBugs | `<build><plugins>` |
| `smart-doc` | smart-doc-maven-plugin (used by `jkit contract stage` for OpenAPI generation) | `<build><plugins>` |

`testcontainers` and `compose` are mutually exclusive — callers pick based on Spring Boot version. The binary does not detect.

---

## Algorithm

1. Read `pom.xml` (path from `--pom`, default cwd). Parse error → exit 1.
2. Resolve the profile to its fragment list. Unknown profile → exit 1 with valid choices.
3. For each fragment:
   - Locate the parent element (`<dependencies>` or `<build><plugins>`). Missing parent under `--apply`: create it. Missing parent in dry-run: count as a missing fragment, no error.
   - Look for the fragment by `groupId+artifactId` (deps) or `<plugin>` with matching `<artifactId>` (plugins).
   - Present → record in `already_present`.
   - Missing → record in `missing`. Under `--apply`, insert the bundled fragment (atomic write — tempfile in same dir, rename) and record in `actions_taken`.
4. Emit JSON.

Indentation: detect from the existing pom (most common indent unit in the document) and match. Default to 4 spaces if undetectable.

---

## Output

Single JSON object to stdout:

```json
{
  "profile": "jacoco",
  "fragments": [
    {"id": "jacoco-maven-plugin", "present": false, "action": "added"}
  ],
  "missing": [],
  "already_present": [],
  "actions_taken": ["added jacoco-maven-plugin to <build><plugins>"],
  "ready": true,
  "blocking_errors": []
}
```

| Field | Type | Notes |
|---|---|---|
| `profile` | string | Echo of the requested profile |
| `fragments[]` | array | Per-fragment status. `action` is one of `"added"`, `"skipped"` (already present), `"reported"` (dry-run) |
| `missing` | string[] | Fragment ids missing **after** the call (empty after a successful `--apply`) |
| `already_present` | string[] | Fragment ids skipped because already configured |
| `actions_taken` | string[] | Empty in dry-run; one entry per mutation under `--apply` |
| `ready` | bool | True when `missing` is empty and `blocking_errors` is empty |
| `blocking_errors` | string[] | Human-readable; e.g. `"pom.xml has no <project> root element"` |

---

## Edge cases

| Case | Behavior |
|---|---|
| `pom.xml` missing | Exit 1 |
| `pom.xml` has no `<build>` and profile is jacoco/quality | `--apply`: create `<build><plugins>`, insert. Dry-run: report as missing. |
| `pom.xml` has no `<dependencies>` and profile is testcontainers/compose | Same — create under `--apply`, list as missing in dry-run. |
| Plugin/dep present with non-default config (version override, executions) | Treat as present; never modify existing config |
| Multi-module pom (parent with `<modules>`) | Operate only on the file passed to `--pom`; warn to stderr `"multi-module project — verify this is the right pom"` |
| `--apply` write fails (permissions, FS full) | Exit 1 with error |
| Unknown `--profile` | Exit 1 with list of valid profiles |
| Pom uses tabs vs spaces | Match the dominant style in the original |

---

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success — JSON describes state. `ready: false` is *not* a failure; the caller decides. |
| 1 | Could not read or parse `pom.xml`; could not write under `--apply`; unknown profile; I/O error |

---

## Suggested dependencies

```toml
[dependencies]
serde      = { version = "1", features = ["derive"] }
serde_json = "1"
clap       = { version = "4", features = ["derive"] }
quick-xml  = { version = "0.36", features = ["serialize"] }
```

---

## Impact on other binaries

### `scenarios prereqs` (v2.1 → v2.2)

Currently does: SB version detection + pom mutation (testcontainers or compose) + runtime probing + compose template copying.

Under this change, scenarios becomes a thin orchestrator:

1. SB version detection — stays in scenarios.
2. Pom mutation — delegates to `pom-doctor prereqs --profile testcontainers` or `--profile compose`.
3. Runtime probing — stays in scenarios.
4. Compose template copying — stays in scenarios.

The scenarios prereqs output JSON gains a `pom_status` key carrying pom-doctor's response verbatim, alongside the existing `runtime` / `missing_files` / etc. fields.

### `jacoco-filter prereqs` (proposed v1.1) — **removed**

Folded into `pom-doctor prereqs --profile jacoco`. The jacoco-filter v1.1 PRD reduces to just the `--iteration-state` flag. Callers (java-tdd Step 3) invoke pom-doctor directly.

### `bin/pom-add.sh` — **removed**

The previous shell-based pom mutator was deleted alongside this PRD landing. Quality, jacoco, and testcontainers fragments are all now sourced from `pom-doctor`'s bundled templates.

---

## Impact on skills

- **java-tdd Step 3** → `pom-doctor prereqs --profile jacoco --apply`.
- **java-verify Step 1** → `pom-doctor prereqs --profile quality --apply`.
- **scenario-tdd Step 1** → unchanged at the skill level (continues to call `scenarios prereqs`); the orchestration shift is internal to scenarios.

Net architectural effect: every pom-mutation point in the pipeline goes through one binary, one schema, one bundled-template set, one error model.
