# Change-File-Driven Spec Design

**Date:** 2026-04-24
**Status:** Approved

---

## Problem

The current workflow requires developers to directly edit formal spec documents
(`api-spec.yaml`, `domain-model.md`, `api-implement-logic.md`) to express requirement
changes. This is unnatural: developers think in terms of *what they want to add*, not
*which section of which document to update*. Maintaining large structured docs across
many continuous development cycles is tedious and error-prone.

The `git diff` approach used by `spec-delta` also couples the AI's understanding of
requirements to the quality of the human's doc editing — if the edit is incomplete or
inconsistent, the diff is misleading.

---

## Solution

Introduce a **change-file layer**: humans write short, unstructured markdown descriptions
of what they want to build. The AI reads these descriptions, updates the formal docs, and
proceeds to plan and implement. Formal docs become AI-maintained derived artifacts rather
than human-maintained sources of truth.

**Human gesture before (editing formal docs):**
> Open `api-spec.yaml`, find the right section, add endpoint in correct YAML format,
> update `domain-model.md` with new entity, update `api-implement-logic.md`...

**Human gesture after (writing a change file):**
> Create `docs/changes/pending/2026-04-24-bulk-invoice.md`, write a sentence or two.

---

## Change Description Files

**Location:** `docs/changes/pending/` for unimplemented changes; `docs/changes/done/`
for implemented changes (moved there by the post-commit hook).

**Naming:** `YYYY-MM-DD-<slug>.md`

**Format:** Plain markdown, no required structure. One sentence is enough.

```markdown
# Add bulk invoice creation

Add a POST /invoices/bulk endpoint to the billing domain.
Accepts a list of invoice request objects, processes them transactionally,
returns a job ID. The bulk invoice is a new entity with status tracking.
```

Optional frontmatter to specify domain explicitly:

```markdown
---
domain: billing
---
```

If domain is not specified, `spec-delta` infers it from the description content.

---

## State Tracking

The `.spec-sync` SHA file and its post-commit update logic are removed. State is
implicit in the filesystem:

| State | Meaning |
|---|---|
| `docs/changes/pending/` has files | Those changes are unimplemented |
| `docs/changes/pending/` is empty | Everything is implemented |
| `docs/changes/done/` | Full ordered history of implemented changes |

The run directory (`docs/jkit/<run>/`) records which change files it processed in a
plain-text file called `.change-files` — one filename per line (basename only, e.g.
`2026-04-24-bulk-invoice.md`). The post-commit hook finds the most recent run directory
under `docs/jkit/` (by directory name, which is date-prefixed), reads `.change-files`,
and moves those files from `pending/` to `done/`. The hook stages the moves and amends
the implementation commit.

---

## Updated `spec-delta` Flow

Steps marked `(unchanged)` are identical to the current implementation.

1. **Sync with remote** (unchanged)
2. **Scan `docs/changes/pending/`** — list all `.md` files; if empty, stop:
   *"No pending changes."*
3. **Show pending changes, confirm scope** — if multiple files:
   > "Found 2 pending changes: `2026-04-24-bulk-invoice.md`, `2026-04-23-payment-refund.md`
   > A) Implement all together (recommended)
   > B) Pick one to implement now"
4. **Read selected change files** — full content; no diffing required
5. **Infer affected domains** — from frontmatter or description content; ask if ambiguous
6. **Ask clarification questions** — same as today, grounded in change description
   content rather than a doc diff; one at a time with labeled options
7. **Update formal docs** — for each affected domain, AI updates `api-spec.yaml`,
   `domain-model.md`, `api-implement-logic.md`. Human reviews each update:
   > "Updated `docs/domains/billing/api-spec.yaml`
   > A) Looks good (recommended)
   > B) Edit — tell me what to change"
8. **Semantic schema change analysis** — run `git diff -- docs/domains/*/` after step 7
   to get a precise diff of only what the AI changed in the formal docs. Use this diff
   (not the full docs) as input to the schema analysis. Token-efficient and scoped exactly
   to what changed in this run.
9. **SQL migration sub-flow** (unchanged — triggered if schema changes detected)
10. **Create run directory + write `change-summary.md`** (unchanged)
    — also write `.change-files` to the run directory: one change file basename per line
11. **Invoke `superpowers:writing-plans`** (unchanged)
12. **Invoke `java-tdd`** (unchanged)
13. **After implementation commit** — post-commit hook moves processed change files
    from `pending/` to `done/`

### Resume after interruption

Same as today — spec-delta detects an existing run directory and asks to resume.
Change files remain in `pending/` until the implementation commit, so resuming
correctly re-associates the run with its files.

---

## Changes to Existing Skills and Hooks

### `spec-delta`

Rewritten as described above. Key behavioral changes:
- Input: change description files instead of `git diff` of formal docs
- New step 7: AI updates formal docs; human reviews the update
- Step 2 replaces `.spec-sync` baseline check
- `description` frontmatter updated to mention "pending change files" as a trigger

### `migrate-project`

One change: replace "initialize `.spec-sync` to HEAD" with "create
`docs/changes/pending/` and `docs/changes/done/` directories." Everything else unchanged.

### `post-commit-sync.sh`

Simplified logic:
- **Old:** write HEAD SHA to `docs/.spec-sync`, amend commit
- **New:** find the most recent run directory under `docs/jkit/` (by date-prefixed name);
  read `.change-files` from it; move those files from `pending/` to `done/`;
  stage the moves; amend commit

Trigger condition is unchanged: fires on `feat(impl):`, `fix(impl):`, `chore(impl):` commits.

### `session-start` hook

No change. The `.spec-sync` presence check is removed since `.spec-sync` no longer exists.

### Unaffected skills

`contract-testing`, `publish-contract`, `java-verify`, `java-tdd` — all read formal docs
or run `jkit` CLI commands. None care how formal docs were updated. Zero changes needed.

---

## Migration from `.spec-sync`

For projects already using the old system: on the first run of the new `spec-delta`,
if `.spec-sync` exists and `docs/changes/` does not, spec-delta offers:

> "Found legacy `.spec-sync`. Migrating to change-file tracking.
> A) Migrate now — archive `.spec-sync`, create `docs/changes/` directories (recommended)
> B) Keep using `.spec-sync` — skip migration"

No data is lost. Old formal docs stay as-is; AI begins maintaining them from the first
change-file run onward.

---

## End-to-End Workflow Example

```
1. Developer creates docs/changes/pending/2026-04-24-bulk-invoice.md
   Content: "Add POST /invoices/bulk to billing domain. Transactional, returns job ID."

2. git add + commit (or skip — spec-delta reads the file regardless)

3. /spec-delta
   → scans pending/ → finds bulk-invoice.md
   → infers domain: billing
   → asks: "Should bulk invoice creation be transactional or best-effort?
            A) Transactional (recommended)  B) Best-effort"
   → updates docs/domains/billing/api-spec.yaml
   → tells human: "Updated api-spec.yaml — A) Looks good  B) Edit"
   → updates domain-model.md, api-implement-logic.md (same review loop)
   → detects schema changes → migration-preview.md → SQL → approvals
   → writes change-summary.md → plan.md → invokes java-tdd

4. java-tdd implements per plan → feat(impl): commit

5. post-commit hook:
   → reads run directory → finds bulk-invoice.md was processed
   → moves pending/2026-04-24-bulk-invoice.md → done/
   → stages move → amends commit
```

---

## Out of Scope

- Multi-change-file merging strategies (ordering, conflict resolution between files)
- Non-domain changes (infrastructure, CI/CD) — change files are for spec/domain changes only
- Automated change file creation (from issue trackers, Jira, etc.)
