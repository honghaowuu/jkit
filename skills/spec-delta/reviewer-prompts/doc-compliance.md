# Doc Compliance Reviewer Prompt Template

Use this template when dispatching a doc compliance reviewer subagent in Step 7c.

**Purpose:** Verify the Step 7 doc edits faithfully reflect the change files + Step 6 clarifications — nothing more, nothing less.

```
Task tool (general-purpose):
  description: "Review doc compliance for <feature>"
  prompt: |
    You are reviewing whether a spec-delta doc update matches its change description.

    ## What Was Requested

    ### Change file(s)
    [FULL TEXT of every change file processed in this run — copy from docs/changes/pending/]

    ### Clarifications answered in Step 6
    [Verbatim Q/A pairs, or "None — Step 6 skipped" if all filter criteria were met]

    ### Assumptions silently taken (defaults chosen when Step 6 filter skipped a question)
    [List, or "None"]

    ## What the Doc Updater Claims They Did

    [If Step 7 ran inline: "Main thread applied edits directly."]
    [If Step 7 used subagents: "Subagent(s) per domain applied edits and reported done."]

    Affected domains: [list]

    ## CRITICAL: Do Not Trust the Claim

    You MUST verify independently by reading the actual diff. The doc updater may have
    missed requirements, added unrelated edits, or introduced inconsistencies between
    the three files.

    Run: `git diff -- docs/domains/*/`

    Read the full diff. Do not skim. Do not take the updater's word for completeness.

    ## Your Job — Four Checks

    ### 1. Change-file coverage
    For every concrete item mentioned in the change file(s) — new entity, new field,
    new endpoint, new status code, new business rule, etc. — confirm it appears in
    the diff under the correct domain.

    Missing items are failures. Paraphrased items are failures. A reference to the
    change title without implementing the change is a failure.

    ### 2. Internal consistency (model → logic → spec)
    The three files must line up:
    - Every entity in `domain-model.md` that has service-level behavior should appear
      in `api-implement-logic.md`.
    - Every method in `api-implement-logic.md` that has an HTTP surface should appear
      as an endpoint in `api-spec.yaml`.
    - Field names, types, and required-ness must match across the three files.
    - Response codes in `api-spec.yaml` must be justified by business rules in
      `api-implement-logic.md` (e.g. if api-spec declares a 409, logic must describe
      when that 409 is raised).

    Mismatches are failures.

    ### 3. Scope discipline
    The diff must only touch domains affected by this change. Edits to unrelated
    domains, refactors of existing sections not mentioned in the change, renames
    of unchanged fields — all failures.

    Edits inside `docs/domains/<domain>/test-scenarios.yaml` are exempt from this
    check (they come from `scenarios sync`, not from the doc updater).

    ### 4. Clarification fidelity
    Every Step 6 answer must be reflected in the diff. If the human picked
    "transactional" but the logic doc describes best-effort behavior, that's a
    failure. Same for any "assumption" listed above — if the updater silently
    diverged from the assumption, that's a failure.

    ## What You Must NOT Check

    - Style, grammar, phrasing, markdown formatting
    - "Suggestions for improvement" beyond the four checks
    - Pre-existing content unrelated to this change
    - Code or test files (not in scope)
    - `test-scenarios.yaml` content (owned by `scenarios sync`)

    ## Report Format

    Report exactly one of:

    **✅ Compliant** — no issues under any of the four checks.

    **❌ Issues:**
    - [check #, domain, file, concrete issue with file:line or diff hunk reference]
    - [...]

    Be specific. "BulkInvoice fields inconsistent" is not actionable. "domain-model.md
    declares `BulkInvoice.idempotencyKey` as optional; api-spec.yaml declares it as
    required in the POST /invoices/bulk request body" is actionable.
```
