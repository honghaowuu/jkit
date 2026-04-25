---
name: migrate-project
description: Use when bootstrapping a project to use jkit's spec-delta workflow — typically a fresh repo or one being onboarded onto change-file-driven specs. Creates docs/changes/{pending,done}/, removes legacy `.jkit/spec-sync` if present, and explains next steps.
---

**Announcement:** At start: *"I'm using the migrate-project skill to bootstrap this project for the spec-delta workflow."*

## When to invoke

- Project has a `pom.xml` (or other Java build file) but no `docs/changes/`
- User asks to "set up jkit", "bootstrap spec-delta", "onboard this project"
- session-start hook has nudged the user about this skill

## What it does

One mechanical step (`jkit changes bootstrap`) plus orientation. No code changes outside `docs/changes/` and (if present) the legacy `.jkit/spec-sync` marker.

## Checklist

- [ ] Confirm we're in a git repo
- [ ] Detect existing state (jkit-managed? legacy `.spec-sync`? non-Java?)
- [ ] `jkit changes bootstrap`
- [ ] Remove legacy `.jkit/spec-sync` if present (with confirmation)
- [ ] Tell the human how to write their first change file

## Detailed Flow

### Step 1 — Confirm git repo

```bash
git rev-parse --git-dir
```

If the command fails: stop and tell the human:
> *"This directory isn't a git repo. Run `git init` first, then re-invoke `/migrate-project`."*

### Step 2 — Detect existing state

```bash
ls -d docs/changes/ pom.xml .jkit/spec-sync 2>/dev/null
```

Three signals to interpret:

| Signal | Meaning | Action |
|---|---|---|
| `docs/changes/` exists | Already bootstrapped | Skip Step 3, jump to Step 5 |
| `.jkit/spec-sync` exists | Legacy spec-sync project | Plan to delete it in Step 4 |
| no `pom.xml` | Not a Java project | Warn and ask whether to continue (jkit is Java-focused) |

### Step 3 — Bootstrap

```bash
jkit changes bootstrap
```

Creates `docs/changes/pending/` and `docs/changes/done/`, each with a `.gitkeep` so the empty dirs survive `git add`. Idempotent. JSON output reports `created` / `existing` lists.

### Step 4 — Remove legacy `.jkit/spec-sync` (if present)

If Step 2 found `.jkit/spec-sync`:

> "Found legacy `.jkit/spec-sync` from the pre-2026-04-24 design. Nothing reads it anymore — safe to delete. Remove it?
> A) Yes (recommended)
> B) Keep it for now"

On A: `rm .jkit/spec-sync`. (Don't `rm -rf .jkit/` — other run dirs may live there.)

### Step 5 — Stage and confirm

```bash
git add docs/changes/
```

If Step 4 deleted `.jkit/spec-sync`: also `git add .jkit/spec-sync`.

Tell the human:

> *"Bootstrap complete. Files staged but not committed — review with `git diff --cached` and commit when ready (suggest `chore: bootstrap jkit spec-delta workflow`).*
>
> *Next: write your first change file as `docs/changes/pending/YYYY-MM-DD-<short-feature>.md` with the following shape:*
>
> ```markdown
> ---
> domain: <existing-domain-or-omit>
> ---
>
> # <Short title>
>
> <Free-form description of what changes — what new behavior, what existing behavior changes, what gets removed. The spec-delta skill will turn this into formal docs.>
> ```
>
> *Then run `/spec-delta` to drive the implementation pipeline."*

## Notes

- Don't create `docs/domains/` here. That's spec-delta's job — it will create per-domain dirs as it processes change files.
- Don't install any git hook. The new design uses an explicit `jkit changes complete` call from `java-tdd` Step 7 instead of a post-commit hook.
- This skill is **idempotent**. Running it again on an already-bootstrapped project should be safe (Steps 3 and 4 are both no-ops).
