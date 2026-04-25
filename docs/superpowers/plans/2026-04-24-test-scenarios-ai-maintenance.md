# test-scenarios.md AI Maintenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make spec-delta generate and update `test-scenarios.md` after writing `api-spec.yaml` in Step 7, so the file is AI + human co-maintained.

**Architecture:** Add a sub-step inside spec-delta's Step 7 that derives scenario IDs from the changed endpoints already in working memory, reads the existing `test-scenarios.md` (if present), and merges in only missing scenarios. A companion update to `scenario-gap` removes the now-stale implication that the file is externally provided.

**Tech Stack:** Markdown skill editing only — no code files.

---

## File Map

| File | Change |
|---|---|
| `skills/spec-delta/SKILL.md` | Add test-scenarios sub-step at end of Step 7; update directory comment label |
| `skills/scenario-gap/SKILL.md` | Update `## Input` preamble to reflect AI + human authorship |

---

### Task 1: Add test-scenarios sub-step to spec-delta Step 7

**Files:**
- Modify: `skills/spec-delta/SKILL.md` (Step 7 block, lines ~152–166)

- [ ] **Step 1: Open the file and locate Step 7**

Read `skills/spec-delta/SKILL.md`. Find the block starting with `**Step 7: Update formal docs inline**`. The step currently ends with:

```
If the human requests a change, fix it inline and ask again. Wait for confirmation before proceeding to schema analysis.
```

- [ ] **Step 2: Insert the test-scenarios sub-step**

After the line `If the human requests a change, fix it inline and ask again. Wait for confirmation before proceeding to schema analysis.` and before `**Step 8: Schema analysis**`, insert:

```markdown
**Step 7b: Sync test-scenarios.md**

For each domain whose `api-spec.yaml` was just updated, derive scenario IDs from the endpoints that were added or modified in this change (not from the full spec — only the delta):

For each changed endpoint, generate scenario IDs using this table:

| Source in api-spec.yaml | Generated scenario ID |
|---|---|
| Always | `happy-path` |
| `required` field in request body | `validation-<field>-missing` |
| Response `400` or `422` | `validation-<description-slug>` |
| Response `401` | `auth-missing-token` |
| Response `403` | `auth-<description-slug>` |
| Response `404` | `not-found` |
| Response `409` | `business-<description-slug>` |

`<description-slug>` = response description text kebab-cased (e.g., `"Duplicate idempotency key"` → `business-duplicate-idempotency-key`).

Then merge into `docs/domains/<domain>/test-scenarios.md`:

1. If the file does not exist → create it with all derived scenarios
2. If it exists → read it, then for each changed endpoint:
   - Heading absent → append heading + all derived scenarios
   - Heading present → append only scenario IDs not already present under that heading
3. Never delete, reorder, or modify existing rows

Format matches the existing `test-scenarios.md` convention:

```markdown
## POST /invoices/bulk
- happy-path: valid list of 3 → 201 + invoice IDs
- validation-amount-missing: missing amount field → 400
- auth-missing-token: missing token → 401
- business-duplicate-idempotency-key: duplicate idempotency key → 409
```
```

- [ ] **Step 3: Update the directory comment label**

Find line:
```
      test-scenarios.md             ← scenario gap source (human-maintained)
```

Replace with:
```
      test-scenarios.md             ← scenario gap source (AI + human-maintained)
```

- [ ] **Step 4: Commit**

```bash
git add skills/spec-delta/SKILL.md
git commit -m "feat: add test-scenarios.md sync sub-step to spec-delta Step 7"
```

---

### Task 2: Update scenario-gap preamble

**Files:**
- Modify: `skills/scenario-gap/SKILL.md` (Input section, lines ~8–11)

- [ ] **Step 1: Locate the Input section**

Read `skills/scenario-gap/SKILL.md`. Find the `## Input (passed by spec-delta)` section.

- [ ] **Step 2: Replace the section**

Replace:
```markdown
## Input (passed by spec-delta)

- Domain name (e.g., `billing`)
- Test source root: `src/test/java/`
```

With:
```markdown
## Input (passed by spec-delta)

- Domain name (e.g., `billing`)
- Test source root: `src/test/java/`

`test-scenarios.md` is generated and kept up to date by spec-delta (Step 7b) and may also be extended by humans. The missing-file guard in Step 1 handles domains where the file has not yet been created.
```

- [ ] **Step 3: Commit**

```bash
git add skills/scenario-gap/SKILL.md
git commit -m "docs: clarify test-scenarios.md is AI + human maintained in scenario-gap"
```
