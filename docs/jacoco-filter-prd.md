# jacoco-filter — Extension PRD

**Version:** 1.1
**Language:** Rust
**Binary name:** `jacoco-filter`
**Status:** proposed extension to existing v1.0 binary

---

## Background

`jacoco-filter` v1.0 reads a JaCoCo XML report and emits a ranked list of methods with coverage gaps. It's invoked from `java-tdd` Step 5 to drive the unit-test coverage loop.

v1.1 adds two capabilities the `java-tdd` skill currently asks the model to perform in-prompt:

1. **Plugin bootstrap (`prereqs` subcommand)** — verify (and optionally install) the JaCoCo Maven plugin in `pom.xml`. Currently a Step 3 model task that requires reading and mutating XML.
2. **Iteration state tracking (`--iteration-state` flag)** — detect when the coverage-fill loop has plateaued. Currently a model bookkeeping task ("if two consecutive passes produce no decrease in missed lines, stop") that drifts.

Both are mechanical and error-prone in-prompt; folding them into the binary that already owns coverage data co-locates the concern.

**Design principle (carried from v1.0):** structured input, structured output. `prereqs` returns a state JSON describing what is/was done. `--iteration-state` augments existing output with plateau-detection fields.

---

## CLI changes

### New subcommand: `prereqs`

```
jacoco-filter prereqs [--apply] [--pom <path>]
```

| Argument | Default | Description |
|---|---|---|
| `--apply` | false | Without it: report state, mutate nothing. With it: install missing plugin. |
| `--pom <path>` | `pom.xml` (cwd) | Path to the Maven project file |

### New flag on existing call: `--iteration-state`

```
jacoco-filter <jacoco.xml> [--summary] [--min-score <f>] [--top-k <n>] [--iteration-state <path>]
```

Without the flag, behavior is unchanged from v1.0.

---

## `prereqs` — subcommand

### Algorithm

1. Read `pom.xml` (path from `--pom`, default cwd). Parse error → exit 1.
2. Look for a `<plugin>` with `<artifactId>jacoco-maven-plugin</artifactId>` under `<build><plugins>`.
3. Without `--apply`: emit JSON describing state. Mutate nothing.
4. With `--apply`: insert the bundled fragment into `<build><plugins>` if missing. Record in `actions_taken`. If `<build>` or `<build><plugins>` are absent, create them.

### Bundled template

`templates/pom-fragments/jacoco.xml` — compiled into the binary via `include_str!` so there is no drift between binary version and template content.

Source-of-truth lives at `<repo>/skills/java-tdd/templates/pom-fragments/jacoco.xml`. During binary build, the file is copied into `crates/jacoco-filter/templates/`.

### Output

Single JSON object to stdout:

```json
{
  "jacoco_plugin_present": true,
  "actions_taken": ["added jacoco-maven-plugin to <build><plugins>"],
  "ready": true,
  "blocking_errors": []
}
```

Field semantics:

| Field | Type | Notes |
|---|---|---|
| `jacoco_plugin_present` | bool | Reflects state *after* mutations (post-`--apply`) |
| `actions_taken` | string[] | Empty in dry-run; one entry per mutation under `--apply` |
| `ready` | bool | True when plugin is present and `blocking_errors` is empty |
| `blocking_errors` | string[] | Human-readable; e.g. "pom.xml has no `<project>` root" |

### Edge cases

| Case | Behavior |
|---|---|
| `pom.xml` missing | Exit 1 with error |
| `pom.xml` has no `<build>` | `--apply`: create `<build><plugins>` and insert; record actions. Dry-run: report as missing. |
| Plugin present but with non-default config (e.g. version override) | Treat as present; do not modify |
| Multiple `<build><plugins>` (multi-module pom) | Operate only on the top-level `<build>`; warn to stderr if nested poms exist |
| `--apply` write fails (permissions, etc.) | Exit 1 with error |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success — JSON describes state. `ready: false` is *not* a failure; the caller decides. |
| 1 | Could not read or parse `pom.xml`; could not write under `--apply`; I/O error |

---

## `--iteration-state` — flag

Tracks missed-line totals across successive coverage-loop passes so the skill can stop when no progress is being made.

### Algorithm

1. If `--iteration-state <path>` is provided:
   - Read existing JSON state if present. Malformed → stderr warning, treat as absent.
   - Compute `missed_lines_total` = sum of `missed_lines.length` across all methods in the current report (after standard v1.0 filtering).
   - Append `{"timestamp": "<ISO8601>", "missed_lines_total": N}` to `iterations`.
   - Compute `missed_lines_delta` = current total minus previous total (`null` on first iteration).
   - Compute `consecutive_no_progress` = count of trailing iterations where `delta >= 0` (no decrease).
   - Set `should_stop` = `consecutive_no_progress >= 2`.
   - Write the updated state file (atomic: write to tempfile in same dir, rename).
2. Augment the standard output JSON with the iteration fields. Do not modify any v1.0 fields.

### State file shape

```json
{
  "iterations": [
    {"timestamp": "2026-04-25T14:00:00Z", "missed_lines_total": 24},
    {"timestamp": "2026-04-25T14:05:00Z", "missed_lines_total": 18},
    {"timestamp": "2026-04-25T14:10:00Z", "missed_lines_total": 18}
  ]
}
```

### Augmented output

```json
{
  "summary": { ... },
  "methods": [ ... ],
  "iteration": 3,
  "missed_lines_total": 18,
  "missed_lines_delta": 0,
  "consecutive_no_progress": 1,
  "should_stop": false
}
```

When `--iteration-state` is *not* passed, none of the four iteration fields are emitted (strict v1.0 compatibility).

### Edge cases

| Case | Behavior |
|---|---|
| State file missing | Create it. `iteration: 1`, `missed_lines_delta: null`, `consecutive_no_progress: 0`, `should_stop: false` |
| State file malformed | Stderr warning, treat as absent (start fresh) |
| State file unwritable | Exit 1 — caller asked for tracking; failing silently is wrong |
| `methods: []` (full coverage, missed_lines_total = 0) | Normal delta logic. Two consecutive zeros → `should_stop: true` (loop is done — also means "you reached coverage goal") |
| State file from a different project (different total methods than current) | No special handling; tracked by missed-line count alone, which is sufficient |
| `consecutive_no_progress` boundary: first pass after a decrease then plateau | After 1 decrease + 1 plateau, `consecutive_no_progress: 1`, `should_stop: false`. After 2 plateaus, `should_stop: true`. |

### Why missed-line count, not method count?

Method count drops to zero only when all methods are perfectly covered. Missed-line count drops gradually as tests are added, giving finer-grained progress signal and detecting plateau earlier.

---

## Backwards compatibility

- All existing v1.0 invocations work unchanged.
- The augmented output fields are present **only** when `--iteration-state` is passed.
- `prereqs` is a new subcommand; existing positional `<jacoco.xml>` invocations are unambiguous because `prereqs` is reserved as a literal.

---

## Suggested dependencies

```toml
# Additions to the existing v1.0 Cargo.toml
quick-xml = { version = "0.36", features = ["serialize"] }   # prereqs: pom.xml parsing
chrono    = { version = "0.4", features = ["serde"] }        # iteration-state: timestamps
```

If v1.0 already depends on `serde_json` and `serde`, no further additions for state-file I/O.

---

## Exit codes

Each subcommand documents its own exit codes above. Global convention:

| Code | Meaning |
|---|---|
| 0 | Success (including `prereqs` reporting `ready: false`) |
| 1 | Hard error — XML parse failure, required file missing, I/O failure |

---

## Impact on java-tdd

- **Step 3 (Verify JaCoCo)** → `jacoco-filter prereqs --apply`. Removes the "check pom.xml; if missing, add fragment from `templates/pom-fragments/jacoco.xml`" instruction. ~2 lines + accuracy win on pom mutation (XML insertion is one of the more error-prone in-prompt operations).
- **Step 5 iteration bound** → add `--iteration-state .jkit/<run>/coverage-state.json` to the existing `jacoco-filter` call. The skill rule collapses from "if two consecutive passes produce no decrease in missed lines, stop" to "if `should_stop: true`, stop." ~4 lines + accuracy win on plateau detection.

Net: ~6 skill lines reclaimed, accuracy gains concentrated in plateau detection (most prone to model drift).
