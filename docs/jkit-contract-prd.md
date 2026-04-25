# jkit contract — Product Requirements

**Version:** 1.0
**Subcommands of:** `jkit`
**Status:** proposed extension

---

## Purpose

Three new `jkit` subcommands that own the mechanical halves of service-contract publication, so the `publish-contract` skill stops scraping pom/Spring config, walking codeskel output by hand, computing Javadoc-quality thresholds in-prompt, and orchestrating shell-script chains for git push and marketplace sync.

| Subcommand | Owns |
|---|---|
| `jkit contract service-meta` | Service name resolution, controller discovery (annotation-driven), domain-slug derivation, Javadoc-quality scoring, SDK detection |
| `jkit contract stage` | smart-doc plugin install (via pom-doctor), `smart-doc.json` create/merge, `mvn smart-doc:openapi`, JSON→YAML, template instantiation for `SKILL.md` / `domains/*.md` / `plugin.json` |
| `jkit contract publish` | Contract repo push, marketplace.json update, `claude plugin marketplace update`, catalog write, scoped commits with `chore(contract):` prefix |

The three subcommands map cleanly to the three phases of the existing skill:

1. **Discovery** (service-meta) — what does this service look like?
2. **Generation** (stage) — produce a reviewable contract bundle.
3. **Publication** (publish) — push to GitHub + marketplace.

A hard-gate lives between phases 2 and 3 — `publish` refuses to do anything without an explicit `--confirmed` flag.

**Design principle:** binaries own discovery, deterministic generation, and irreversible network operations. The skill owns the human gates and the structured interview (judgment-heavy: descriptions, invariants, "not responsible for"). Templates live in the binary so every contract this repo emits is byte-identical in shape.

---

## Shared inputs

| Source | Used by | Purpose |
|---|---|---|
| `pom.xml` | service-meta, stage | groupId, artifactId, version, parent (SDK detection), smart-doc plugin presence |
| `src/main/resources/application*.yaml` / `*.properties` | service-meta | `spring.application.name` |
| `src/main/java/**/*.java` | service-meta | Controller discovery via `@RestController` / `@Controller` annotations + Javadoc inspection |
| `.jkit/contract-stage/<service>/` | stage (writes), publish (reads) | Staged contract bundle |
| `.jkit/contract.json` | publish | `{contractRepo, marketplaceRepo, marketplaceName}` |
| Interview answers JSON | stage | Model-collected: description, use_when, invariants, keywords, not_responsible_for, sdk, authentication |

---

## `jkit contract service-meta`

Read-only. Returns everything the skill needs to draft the human-facing prompts.

### CLI

```
jkit contract service-meta [--pom <path>] [--src <path>]
```

| Argument | Default | Description |
|---|---|---|
| `--pom <path>` | `pom.xml` (cwd) | Maven project file |
| `--src <path>` | `src/main/java/` | Java source root |

### Algorithm

1. Read `pom.xml`. Extract `groupId`, `artifactId`, `version`, `parent`. Parse error → exit 1.
2. Resolve `spring.application.name`:
   1. Walk `src/main/resources/application*.yaml` and `application*.properties` (most-specific profile last).
   2. Pick the value from the most-specific source. Reject `${...}` interpolations (record source as `interpolated`); fall back to artifactId.
   3. None found → fall back to `pom.xml` `<artifactId>`.
3. Walk Java source. For every file:
   - Detect class-level `@RestController` or `@Controller` annotations.
   - For each controller class: collect all public method signatures + Javadoc.
   - Compute `domain_slug` from class name: strip `Controller` suffix, kebab-case the rest. `InvoiceController` → `invoice`; `BulkInvoiceController` → `bulk-invoice`.
4. Score Javadoc quality per method:
   - `missing` — `has_docstring: false` or `docstring_text` is empty/whitespace.
   - `thin` — fewer than 5 words OR the docstring is a case-insensitive substring/prefix of the method name (e.g. `"creates an invoice"` for `createInvoice` → thin).
   - `good` — passes both.
5. Detect SDK module: look for a sibling Maven module whose `<artifactId>` ends in `-api` or `-sdk` under the project's parent. None → `sdk: null`.
6. Detect authentication: scan for `@PreAuthorize`, `@RolesAllowed`, Spring Security config beans. Best-effort; emit `null` if undetected (skill asks the human).
7. Emit JSON.

### Output

```json
{
  "service_name": "billing",
  "service_name_source": "spring_application_name",
  "group_id": "com.example",
  "artifact_id": "billing-service",
  "version": "1.2.0",
  "parent_artifact_id": "billing-parent",
  "sdk": {"present": true, "artifact_id": "billing-api", "version": "1.2.0"},
  "authentication_hint": "Bearer",
  "controllers": [
    {
      "class": "com.example.billing.api.InvoiceController",
      "file": "src/main/java/com/example/billing/api/InvoiceController.java",
      "domain_slug": "invoice",
      "methods": [
        {
          "name": "createInvoice",
          "http_method": "POST",
          "path": "/invoices",
          "javadoc_quality": "good",
          "javadoc_text": "Creates a new invoice for the given tenant."
        }
      ]
    }
  ],
  "javadoc_quality": {
    "score": 0.78,
    "total_methods": 18,
    "missing": ["InvoiceController#getInvoice", "..."],
    "thin": ["..."]
  },
  "interview_drafts": {
    "description": "...",
    "keywords": ["invoice", "billing", "..."],
    "invariants": ["..."],
    "use_when": ["..."],
    "not_responsible_for": []
  }
}
```

`interview_drafts` are best-effort suggestions the skill shows to the human. Empty arrays are normal for fields the binary can't infer.

### Edge cases

| Case | Behavior |
|---|---|
| Multiple `application-*.yaml` files | Merge in profile order; record source as profile name |
| `spring.application.name` interpolated (`${SERVICE_NAME}`) | Record `service_name_source: "interpolated"`, fall back to artifactId, surface in `warnings` |
| Class with both `@RestController` and another stereotype | Treat as controller |
| Controller with no public methods | Include in `controllers[]` with empty `methods` |
| File with multiple controller classes | Each becomes its own entry |
| Abstract base controller (no `@RestController` directly) | Skip — only annotated concrete classes count |
| Controller class name without `Controller` suffix | `domain_slug` = kebab-case of the full class name; surface `warnings` entry |
| Two controllers resolving to the same `domain_slug` | All controllers retain entries; surface in `warnings` so the skill can ask the human to merge |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | `pom.xml` missing/malformed; source root missing; I/O error |

---

## `jkit contract stage`

Generate the contract bundle in `.jkit/contract-stage/<service-name>/`.

### CLI

```
jkit contract stage --service <name> --interview <path> --domains <slug,...> [--dry-run]
```

| Argument | Default | Description |
|---|---|---|
| `--service <name>` | required | Service name (matches `service_name` from service-meta) |
| `--interview <path>` | required | Path to model-collected interview answers JSON |
| `--domains <slug,...>` | required | Comma-separated list of confirmed domain slugs (the human-approved subset of `controllers[].domain_slug`) |
| `--dry-run` | false | Report what would be written; mutate nothing |

### Interview answers schema

```json
{
  "description": "Service for invoice lifecycle management.",
  "use_when": ["creating bulk invoices", "querying invoice status"],
  "invariants": ["tenant_id is required on all writes"],
  "keywords": ["invoice", "billing", "tenant"],
  "not_responsible_for": ["payments", "refunds"],
  "sdk": {"present": true, "artifact_id": "billing-api", "version": "1.2.0"},
  "authentication": "Bearer"
}
```

### Algorithm

1. Validate `--service` matches a service detectable in cwd (re-runs service-meta internally for cross-checking; rejects mismatch).
2. Validate `--interview` JSON against the schema above.
3. Validate every `--domains` slug appears in `controllers[].domain_slug` from service-meta. Unknown → exit 1.
4. Install smart-doc plugin if missing: invoke `pom-doctor prereqs --profile smart-doc --apply`. Capture output under `pom_status`.
5. Create or merge `smart-doc.json`:
   - If absent: write fresh from bundled template.
   - If present: preserve all existing keys; overwrite only `outPath`, `openApiAllInOne`, `sourceCodePaths`.
6. Run `mvn smart-doc:openapi`. Failure → exit 1, surface last 20 lines of mvn output.
7. Convert `<stage-dir>/reference/openapi.json` → `<stage-dir>/reference/contract.yaml`. Delete the JSON.
8. Instantiate templates from bundled sources (`include_str!`):
   - `<stage-dir>/.claude-plugin/plugin.json` from `templates/contract/plugin.json.tera`
   - `<stage-dir>/skills/<service>/SKILL.md` from `templates/contract/skill.md.tera`
   - `<stage-dir>/domains/<slug>.md` from `templates/contract/domain.md.tera` — one per `--domains` entry
9. Add `.jkit/contract-stage/` to `.gitignore` if not already present.
10. Emit JSON.

### Output

```json
{
  "service": "billing",
  "stage_dir": ".jkit/contract-stage/billing/",
  "files_written": [
    ".jkit/contract-stage/billing/.claude-plugin/plugin.json",
    ".jkit/contract-stage/billing/skills/billing/SKILL.md",
    ".jkit/contract-stage/billing/domains/invoice.md",
    ".jkit/contract-stage/billing/reference/contract.yaml"
  ],
  "pom_status": { "...verbatim pom-doctor response..." },
  "smart_doc_action": "merged_existing",
  "mvn_smart_doc": "ok",
  "gitignore_updated": true,
  "warnings": []
}
```

### Edge cases

| Case | Behavior |
|---|---|
| `<stage-dir>` already exists | Default: refuse with exit 1, instructing the caller to use the skill's overwrite gate. With `--force`: regenerate. |
| `--domains` empty | Exit 1 — at least one domain required |
| `mvn smart-doc:openapi` fails | Exit 1, surface mvn tail in `blocking_errors` |
| `smart-doc.json` malformed JSON | Exit 1; the merge step refuses to silently overwrite |
| `--dry-run` | Skip steps 4–9; emit `files_written` populated with intended paths and `actions_pending` |

### Bundled templates

`crates/jkit/templates/contract/`:

- `plugin.json.tera`
- `skill.md.tera`
- `domain.md.tera`
- `smart-doc.json.tera`

Source-of-truth lives at `<repo>/skills/publish-contract/templates/`; copied into the crate at build time.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (including `--dry-run`) |
| 1 | Validation failure; mvn failure; pom-doctor failure; I/O error |

---

## `jkit contract publish`

Push contract repo, sync marketplace, write catalog, scoped commits. **Default is dry-run** — the binary describes what it would do. `--confirmed` is required to actually push.

### CLI

```
jkit contract publish --service <name> [--confirmed] [--no-commit]
```

| Argument | Default | Description |
|---|---|---|
| `--service <name>` | required | Service name (matches the staged dir at `.jkit/contract-stage/<service>/`) |
| `--confirmed` | false | **Mandatory for any network or git mutation.** Without it: dry-run reporting only. |
| `--no-commit` | false | Skip the `chore(contract):` commits at the end (caller wants to manage commits) |

### Algorithm

1. Read `.jkit/contract.json`. Missing or any field absent → exit 1 with the missing field list (skill gathers them and re-runs).
2. Check `.jkit/contract-stage/<service>/` exists and is non-empty. Missing → exit 1.
3. Without `--confirmed`: emit a JSON description of the planned actions; do not push, do not commit. Exit 0.
4. With `--confirmed`:
   - Push contract repo to `contractRepo` (init the staging dir as a git repo if not already; force-push protected by branch rules at GitHub).
   - Clone `marketplaceRepo` to a tempdir; update `marketplace.json` to include this contract; push; delete the tempdir.
   - Run `claude plugin marketplace update <marketplaceName>`.
   - Write `.jkit/marketplace-catalog.json` with the catalog snapshot.
5. Unless `--no-commit`:
   - If `smart-doc.json` or `pom.xml` were modified during the run, commit them as `chore(contract): add smart-doc configuration`.
   - Commit `.jkit/contract.json`, `.gitignore`, `.jkit/marketplace-catalog.json` as `chore(contract): publish service contract for <service>`.
6. Emit JSON describing what was pushed and committed.

### Output (dry-run)

```json
{
  "service": "billing",
  "confirmed": false,
  "contract_repo": "git@github.com:example/billing-contract.git",
  "marketplace_repo": "git@github.com:example/marketplace.git",
  "marketplace_name": "example-marketplace",
  "would_push_files": [
    ".claude-plugin/plugin.json",
    "skills/billing/SKILL.md",
    "domains/invoice.md",
    "reference/contract.yaml"
  ],
  "would_run": [
    "git push <contract-repo>",
    "marketplace.json update + push",
    "claude plugin marketplace update example-marketplace"
  ],
  "would_commit": [
    "chore(contract): add smart-doc configuration",
    "chore(contract): publish service contract for billing"
  ]
}
```

### Output (confirmed)

```json
{
  "service": "billing",
  "confirmed": true,
  "contract_pushed": true,
  "contract_sha": "abc1234",
  "marketplace_pushed": true,
  "marketplace_sha": "def5678",
  "catalog_written": ".jkit/marketplace-catalog.json",
  "commits": [
    {"sha": "111aaa", "subject": "chore(contract): add smart-doc configuration"},
    {"sha": "222bbb", "subject": "chore(contract): publish service contract for billing"}
  ]
}
```

### Edge cases

| Case | Behavior |
|---|---|
| Contract repo not empty on first push | Refuse with `"contract repo must be empty for first push — auto-generated README will collide"` |
| Marketplace repo missing | Exit 1; instruct the human to create it |
| `claude plugin marketplace update` not on PATH | Exit 1; surface install instructions |
| Contract push succeeds but marketplace push fails | Surface partial state in `blocking_errors`; do not run subsequent commits. Re-running with `--confirmed` should be idempotent. |
| Two `chore(contract):` commits already on HEAD (re-run) | Skip both commits; surface `already_committed: true` |
| `--no-commit` | Skip the commit step but still push |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (dry-run or confirmed) |
| 1 | Missing `.jkit/contract.json`; missing stage dir; push failure; commit failure |

---

## Suggested dependencies

```toml
# Additions to the existing jkit Cargo.toml
git2       = "0.19"           # contract publish: clone, commit, push (or shell out — pick one)
tera       = "1"              # template instantiation
walkdir    = "2"              # source scanning for service-meta
serde_yaml = "0.9"            # contract.yaml conversion
```

If `jkit` already shells out to `git` for other subcommands, stay consistent — drop `git2`.

---

## Impact on pom-doctor

Adds a new profile: `smart-doc` (insert smart-doc-maven-plugin under `<build><plugins>`). See updated entry in `docs/pom-doctor-prd.md`.

---

## Impact on bash scripts — deprecated

The following scripts under `bin/` become deprecated once `jkit contract` ships:

| Script | Replaced by |
|---|---|
| `bin/contract-push.sh` | `jkit contract publish --confirmed` (push phase) |
| `bin/marketplace-publish.sh` | `jkit contract publish --confirmed` (marketplace phase) |
| `bin/marketplace-sync.sh` | `jkit contract publish --confirmed` (sync phase) |

Remove them once the binary is implemented and `publish-contract` is migrated, mirroring the `bin/pom-add.sh` removal in commit `2495380`.

---

## Impact on publish-contract skill

Skill collapses from ~398 lines to ~110:

- **Step 1 (service metadata)** → `jkit contract service-meta`. Removes grep/yaml-parsing improvisation.
- **Step 3 (controller path + scan)** + **Step 4 (Javadoc audit)** + **Step 5 (domain mapping)** → all consumed from service-meta JSON. Removes the manual codeskel index loop and the subjective Javadoc threshold.
- **Step 6 (interview)** → presented as a drafted-answers gate (one prompt with all 7 drafts from `interview_drafts`) instead of seven sequential questions.
- **Step 7 (smart-doc) + Step 8 (templates)** → `jkit contract stage`. Removes inline pom mutation, JSON merge logic, and ~80 lines of inlined SKILL.md / domain templates.
- **Step 11 (push, marketplace, commits)** → `jkit contract publish --confirmed`. Removes the three bash scripts and the conditional-commit logic.

Skill responsibilities that remain in-prompt (judgment + gates):
- Confirming the domain mapping (gate after service-meta).
- Editing/confirming the interview drafts.
- Resolving Javadoc gaps (read the `weak_methods` list, edit, re-run service-meta).
- Hard-gate before publish.
- Asking for `.jkit/contract.json` fields if missing.

Net: ~290 skill lines reclaimed and three bash scripts retired.
