# Domain Doc Updater Prompt Template

Use this template when dispatching per-domain subagents in Step 9.1 to update the three spec files for a single affected domain.

**Purpose:** Apply the change file's requirements + Step 8 clarifications to the three files of one domain, nothing more.

```
Task tool (general-purpose):
  description: "Update <domain> docs for <feature>"
  prompt: |
    You are updating the three spec files of a single domain to reflect a change
    description. All ambiguity has already been resolved by the main thread — do
    not ask questions.

    ## Change file(s)

    [FULL TEXT of every change file processed in this run — copy from
    docs/changes/pending/]

    ## Clarifications answered in Step 8

    [Verbatim Q/A pairs, or "None — Step 8 skipped" if all filter criteria were met]

    ## Assumptions silently taken (defaults chosen when the Step 8 filter skipped a question)

    [List, or "None"]

    ## Target domain

    `<domain>` — update these three files IN THIS ORDER so each can reference
    the previous:

    1. `docs/domains/<domain>/domain-model.md` — entities, fields, relationships
    2. `docs/domains/<domain>/api-implement-logic.md` — service methods, business rules
    3. `docs/domains/<domain>/api-spec.yaml` — endpoints, request/response schemas

    ## Rules

    - Only edit sections related to the change. Do not touch unrelated content.
    - Do not create new files.
    - Do not run tests, build tools, or other binaries.
    - Do not request clarifications. If something is truly unresolvable, report
      `BLOCKED: <reason>` — the main thread will fall back to inline edits for
      this domain.
    - Do not rewrite or reorder pre-existing sections.
    - Do not edit `test-scenarios.yaml` — that file is owned by `scenarios sync`.

    ## Report

    `done` once all three files are saved, OR `BLOCKED: <one-line reason>`.
```
