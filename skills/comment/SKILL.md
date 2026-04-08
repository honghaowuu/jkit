---
name: comment
description: Use when asked to document, comment, or add Javadoc to Java files or directories. Generates accurate Javadoc in dependency order so each file is commented with full knowledge of its dependencies.
---

# comment

Generates accurate, complete Javadoc and docstrings for under-documented Java codebases by processing files in dependency order — so each file is commented with full knowledge of what it depends on. Edits source files directly in place.

**TRIGGER when:** user asks to document, comment, or add Javadoc to Java files or directories in a project.

---

## Step 0: Resolve codeskel binary

Resolve the `codeskel` binary in this order:
1. `<plugin-root>/bin/codeskel-<os>-<arch>` where `<os>` is `linux`/`macos`/`windows` and `<arch>` is `x86_64`/`aarch64`
2. `codeskel` on `PATH`
3. If neither found: stop with "codeskel not found. Expected at <plugin-root>/bin/codeskel-<os>-<arch> or on PATH. See plugin README for setup."

Determine `<plugin-root>` as the directory containing this skill file (i.e., navigate up from `skills/comment/SKILL.md`).

## Step 1: Scan the project

If `.codeskel/cache.json` is absent in the project root, run:
```bash
codeskel scan <project_root>
```

This builds the dependency graph. Always re-run if the user says the codebase has changed significantly.

> **Rationalization table — do NOT skip codeskel rescan when:**
> - The user says "just a few files changed" — dependency order may still shift
> - You think you know the order — the scanner is authoritative
> - The cache file exists — it may be stale; check its mtime vs. source files

## Step 2: Determine file order

```bash
codeskel order <project_root> [--path <subpath>]
```

This outputs files in dependency order (dependencies before dependents). Use `--path` to scope to a subdomain or directory.

## Step 3: Process files in order

For each file in the dependency-ordered list:

1. Read the file fully
2. Read all files it depends on (already processed — they have updated Javadoc)
3. Generate accurate Javadoc for:
   - Each class/interface/enum (class-level `/** ... */`)
   - Each public method (method-level `/** ... */`)
   - Each public field that is not self-evident
4. Rules for accurate Javadoc:
   - Describe **what** the method/class does, not **how**
   - Include `@param` for each parameter with a meaningful description
   - Include `@return` for non-void methods
   - Include `@throws` for declared checked exceptions
   - Do NOT add `@author`, `@version`, or `@since` unless already present
   - Do NOT add comments that restate the method name (e.g., `/** Gets the name. */` for `getName()`)
   - For `@Entity` / `@Aggregate` classes, describe the domain concept, not the JPA mechanics
5. Write the updated file

## Step 4: Verify

After processing all files, run a quick sanity check:
```bash
codeskel rescan <project_root>
```

If any files still show as undocumented in the output, process them.

## Step 5: Report

Report:
- How many files were processed
- Any files skipped and why
- Any ambiguities in the domain model that you encountered while writing Javadoc
