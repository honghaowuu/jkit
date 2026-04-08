# spec-delta

Computes the requirements delta since the last implemented spec commit and drives the full implementation cycle: clarify → change-summary → migration preview → plan.

**TRIGGER when:** user runs `/spec-delta`.

---

## Step 1: Resolve or initialize .spec-sync

Check if `docs/.spec-sync` exists in the project root.

**Missing:**
- Run `git log --oneline -- docs/` to find commits that touched spec files.
- **No such commits found:** Initialize silently:
  ```bash
  git rev-parse HEAD > docs/.spec-sync
  ```
  Report: *"No spec commits found. Initialized .spec-sync to HEAD."*
  Then stop (nothing to process yet).
- **Commits found:** Show the last 5 commits. Ask:
  > "No .spec-sync found. Which commit was the last one fully implemented?
  > A) [sha1] [date] [message]   ← most recent spec commit
  > B) [sha2] [date] [message]
  > C) [sha3] [date] [message]
  > D) [sha4] [date] [message]
  > E) [sha5] [date] [message]
  > Z) HEAD — all current specs are already implemented
  > M) Enter a specific SHA manually"
  - Write chosen SHA to `docs/.spec-sync`
  - Report: *"Baseline set to [sha]. Run /spec-delta again to see what's pending."*
  - Stop.

**Present:** Read it to get the baseline SHA.

## Step 2: Compute the diff

```bash
git diff $(cat docs/.spec-sync) HEAD -- docs/
```

If the diff is empty: stop with *"No spec changes since last implementation."*

## Step 3: Establish context from docs/overview.md

**Missing:** Generate it before proceeding:
1. Read all spec files in `docs/`
2. Draft a ≤1 page overview describing what the service does, its domains, and primary responsibilities
3. Ask targeted questions if anything is unclear (labeled options + recommendation)
4. Show draft to human for approval → write approved version to `docs/overview.md`

**Present:** Read it as background context.

*(If a new domain was added in the diff: after change-summary approval in Step 8, you will be prompted to update overview.md — handled there.)*

## Step 4: Order changed domains

Identify which domains changed in the diff.

Order tasks within each domain by dependency:
```
domain-model.md → api-implement-logic.md → api-spec.yaml
```

Cross-domain ordering: if domain-A's model is referenced by domain-B's API, domain-A tasks come first. Ask the human if cross-domain dependencies are unclear:
> "domain-A's model appears in domain-B's API spec. Should domain-A be implemented before domain-B?
> A) Yes — implement domain-A first (recommended)
> B) No — they can be implemented independently"

## Step 5: Semantic schema change analysis

Read the full diff of all changed spec docs (domain-model.md, api-implement-logic.md, api-spec.yaml).

Reason semantically about whether the changes imply database schema changes:
- New entities → new tables
- New entity fields → new columns
- Entity relationships changed → FK changes, join table changes
- Renamed concepts → column renames
- Removed fields → dropped columns
- New query patterns → new indexes

Do NOT use keyword scanning. Use domain understanding to determine if schema changes are needed.

## Step 6: Ask clarification questions

Ask targeted clarification questions one at a time — only for genuine ambiguities.

Each question must have:
- 2-3 labeled options (A, B, C)
- One marked `(recommended)`
- Default answerable with one keystroke

Example:
> "Should bulk invoice creation be transactional or best-effort?
> A) Transactional — all succeed or all fail (recommended)
> B) Best-effort — process valid items, skip invalid ones"

## Step 7: Determine run directory

Create the run directory:
```
docs/jkit/YYYY-MM-DD-<feature>/
```
Where `<feature>` is a short slug derived from the most significant change in the diff (e.g., `billing-bulk-invoice`, `user-auth-2fa`).

## Step 8: Write change-summary.md

Write `docs/jkit/<run>/change-summary.md`:

```markdown
# Change Summary: <feature>

**Baseline:** `<sha>`
**Date:** YYYY-MM-DD

## Domains Changed

| Domain | Added | Modified | Removed |
|--------|-------|----------|---------|
| billing | BulkInvoice entity, POST /invoices/bulk | Invoice.status enum | — |

## Schema Change Required
[Yes / No]

If yes, briefly describe the implied changes:
- CREATE TABLE `bulk_invoice`
- ADD COLUMN `invoice.bulk_id`

## Cross-Domain Effects
[None / describe if present]

## Implementation Order
1. billing/domain-model (BulkInvoice entity)
2. billing/api-implement-logic (BulkInvoiceService)
3. billing/api-spec (POST /invoices/bulk)
```

Ask human to review and approve `change-summary.md` before proceeding.

**After approval — new domain check:** If a new domain was added in the diff, prompt:
> "A new domain was added. Should docs/overview.md be updated?
> A) Yes — generate an updated draft (recommended)
> B) No — overview is still accurate"
If yes: draft update → show to human → write on approval.

## Step 9: SQL migration (if schema changes flagged)

If Step 5 flagged schema changes:

1. Write `docs/jkit/<run>/migration-preview.md`:

```markdown
## Migration Preview: <feature>

| Change | Type | Detail |
|--------|------|--------|
| `bulk_invoice` | CREATE TABLE | id UUID PK, tenant_id UUID, status VARCHAR, created_at TIMESTAMP |
| `invoice.bulk_id` | ADD COLUMN | FK to bulk_invoice(id), nullable |
| `idx_invoice_bulk` | CREATE INDEX | on invoice(bulk_id) |
```

2. Ask human to review and approve:
   > "Please review docs/jkit/<run>/migration-preview.md.
   > A) Approve as-is (recommended)
   > B) Edit preview first — I'll wait
   > C) Skip migration — no schema changes needed"

3. On approval: generate SQL into `docs/jkit/<run>/migration/V<YYYYMMDD>_NNN__<feature>.sql`:

```sql
-- Migration: <feature>
-- Date: YYYY-MM-DD

CREATE TABLE bulk_invoice (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE invoice ADD COLUMN bulk_id UUID REFERENCES bulk_invoice(id);

CREATE INDEX idx_invoice_bulk ON invoice(bulk_id);
```

Note: The SQL file will be moved to `src/main/resources/db/migration/` as the final step of the implementation plan (included in the `writing-plans` plan).

## Step 10: Invoke writing-plans

Invoke `superpowers:writing-plans` with:
- The full diff content
- Contents of `docs/overview.md`
- All clarification answers from Step 6
- Instruction: **save the plan to `docs/jkit/<run>/plan.md`** (not the default superpowers location)

The plan should include, as its final task: move SQL file from `docs/jkit/<run>/migration/` to `src/main/resources/db/migration/` and include it in the implementation commit.

## Step 11: After implementation

The post-commit hook automatically updates `docs/.spec-sync` after each `feat(impl):` / `fix(impl):` / `chore(impl):` commit.
