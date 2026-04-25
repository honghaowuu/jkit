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

One mechanical step (`jkit init`) plus orientation. `jkit init` is the umbrella that runs `changes bootstrap` + `standards init` + `init scaffold` and emits a single JSON report. No code changes outside the project's project-owned config files.

## Checklist

- [ ] Ensure we're in a git repo (`git init` if not)
- [ ] Detect whether already bootstrapped
- [ ] `jkit init`
- [ ] Surface `next_steps[]` from the JSON report verbatim
- [ ] Stage the created files; the human reviews and commits

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

- `docs/changes/` already exists → already bootstrapped. Step 3 is still safe to run — `jkit init` is idempotent and will report empty `created` arrays for everything.
- No `pom.xml` (and no `build.gradle*`) → warn the human that jkit is Java-focused and ask whether to continue.

### Step 3 — Bootstrap

```bash
jkit init
```

One call. Behavior, in order:

1. **changes bootstrap** — creates `docs/changes/{pending,done}/` with `.gitkeep` markers.
2. **standards init** — copies `docs/project-info.yaml` from the shipped template if absent (skips silently if present).
3. **init scaffold** — copies `.envrc`, `.env/local.env`, `.env/test.env`, `docker-compose.yml`, `docs/overview.md` from embedded templates; merges canonical entries (`.env/`, `target/`, `.jkit/done/`) into `.gitignore` under a fenced jkit block.

Read the JSON. The shape is:

```json
{
  "ok": true,
  "steps": {
    "changes_bootstrap": { "created": [...], "existing": [...] },
    "standards_init":    { "created": [...], "existing": [...] },
    "scaffold":          { "created": [...], "existing": [...], "gitignore_added": [...] }
  },
  "next_steps": ["…", "…"]
}
```

### Step 4 — Surface next steps

Print the `next_steps[]` array verbatim as a numbered list. The binary builds it from what was actually created — re-runs against an already-bootstrapped project produce a shorter list (typically just the `/write-change` pointer).

If `docs/project-info.yaml` was created in this run, emphasize:

> *"Review `docs/project-info.yaml` and adjust the `enabled` flags (e.g., set `spring-cloud.enabled: true` if this project uses Nacos/Eureka; set `i18n.enabled: false` if you don't ship multi-language messages). The current settings determine which rule files `jkit standards list` returns."*

If `docs/overview.md` was created, emphasize:

> *"Fill the `<!-- TODO -->` markers in `docs/overview.md` (≤1 page). spec-delta and downstream skills read it as ground truth for what this service does."*

### Step 5 — Stage and confirm

Stage everything `jkit init` touched plus the new `.gitignore` block:

```bash
git add docs/ .envrc .env/ docker-compose.yml .gitignore
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
- This skill is **idempotent**. `jkit init` skips every file that already exists; re-running on a fully bootstrapped project is a JSON-only no-op.
- If the human wants to regenerate one scaffolded file (e.g., they edited `.envrc` and want a clean copy), they delete the file first — `jkit init` then re-creates it on the next run. There's deliberately no `--force` flag.
