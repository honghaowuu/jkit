---
name: migrate-project
description: Use when bootstrapping a project to use jkit's spec-delta workflow — typically a fresh repo or an existing Java project being onboarded. Creates docs/changes/{pending,done}/ and explains how to write the first change file.
---

**Announcement:** At start: *"I'm using the migrate-project skill to bootstrap this project for the spec-delta workflow."*

## When to invoke

- Project has a `pom.xml` (or other Java build file) but no `docs/changes/`
- User asks to "set up jkit", "bootstrap spec-delta", "onboard this project"
- session-start hook has nudged the user about this skill

## What it does

One mechanical step (`jkit changes bootstrap`) plus orientation. No code changes outside `docs/changes/`.

## Checklist

- [ ] Ensure we're in a git repo (`git init` if not)
- [ ] Detect whether already bootstrapped
- [ ] `jkit changes bootstrap`
- [ ] Tell the human how to write their first change file

## Detailed Flow

### Step 1 — Ensure git repo

```bash
git rev-parse --git-dir 2>/dev/null || git init -q
```

If `git rev-parse` fails, run `git init` directly — no prompt. Announce: *"Initialized git repo."* The bootstrap workflow assumes git, so this is a safe automatic action.

### Step 2 — Detect existing state

```bash
ls -d docs/changes/ pom.xml 2>/dev/null
```

- `docs/changes/` already exists → already bootstrapped. Step 3 is a no-op (still safe to run); jump straight to Step 4.
- No `pom.xml` (and no `build.gradle*`) → warn the human that jkit is Java-focused and ask whether to continue.

### Step 3 — Bootstrap

```bash
jkit changes bootstrap
```

Creates `docs/changes/pending/` and `docs/changes/done/`, each with a `.gitkeep` so the empty dirs survive `git add`. Idempotent. JSON output reports `created` / `existing` lists.

### Step 4 — Stage and confirm

```bash
git add docs/changes/
```

Tell the human:

> *"Bootstrap complete. Files staged but not committed — review with `git diff --cached` and commit when ready (suggest `chore: bootstrap jkit spec-delta workflow`).*
>
> *Next: run `/write-change` to author your first change file — it'll either interview you (brainstorm mode) or capture a description you already have (one-shot mode), then write it to `docs/changes/pending/YYYY-MM-DD-<slug>.md` and offer to hand off to `/spec-delta`.*
>
> *If you'd rather skip the skill and write the file by hand, the format is:*
>
> ```markdown
> ---
> domain: <existing-domain-or-omit>
> ---
>
> # <Short title>
>
> <Free-form description of what changes — what new behavior, what existing behavior changes, what gets removed. The spec-delta skill will turn this into formal docs.>
> ```"*

## Notes

- Don't create `docs/domains/` here. That's spec-delta's job — it will create per-domain dirs as it processes change files.
- Don't install any git hook. The design uses an explicit `jkit changes complete` call from `java-tdd` Step 7 instead of a post-commit hook.
- This skill is **idempotent**. Running it again on an already-bootstrapped project is safe (Step 3 is a no-op).
