# Design: AI Maintenance of test-scenarios.md

**Date:** 2026-04-24

## Summary

`test-scenarios.md` is currently marked human-maintained. This design makes it AI + human co-maintained: spec-delta generates and updates the file as part of its existing Step 7, with a merge strategy that preserves all human edits.

## Placement & Trigger

A new sub-step is added to spec-delta's Step 7, immediately after `api-spec.yaml` is written. `api-spec.yaml` is already in working memory at that point — no extra reads. Only endpoints that were **added or modified** in the current change are processed. Untouched endpoints are never re-evaluated.

## Scenario Derivation

Scenarios are derived mechanically from the OpenAPI spec — no inference beyond what is explicitly present:

| Source in api-spec.yaml | Generated scenario ID |
|---|---|
| Always | `happy-path` |
| `required` field in request body | `validation-<field>-missing` |
| Response `400` or `422` | `validation-<description-slug>` |
| Response `401` | `auth-missing-token` |
| Response `403` | `auth-<description-slug>` |
| Response `404` | `not-found` |
| Response `409` | `business-<description-slug>` |

Description slugs are kebab-cased from the response description text (e.g., `"Duplicate idempotency key"` → `business-duplicate-idempotency-key`).

## Merge Rule

1. If `test-scenarios.md` does not exist → create it with all derived scenarios
2. If it exists → read it first, then for each changed endpoint:
   - Heading absent → append heading + all derived scenarios
   - Heading present → append only scenario IDs not already present under that heading
3. Never delete, reorder, or modify existing rows

Human edits (added edge cases, renamed descriptions, reordering) are always preserved.

**File update cost:** one read + one write per domain, both already expected in Step 7's flow.

## Downstream Impact

| File | Change |
|---|---|
| `spec-delta/SKILL.md` line 305 | Label: `(human-maintained)` → `(AI + human-maintained)` |
| `scenario-gap/SKILL.md` | Remove implication that file is externally provided; existing missing-file guard unchanged |

No other skills affected.

## Files Changed

- `skills/spec-delta/SKILL.md` — add test-scenarios sub-step in Step 7; update label
- `skills/scenario-gap/SKILL.md` — minor preamble update
