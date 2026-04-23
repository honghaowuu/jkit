# Drop `contracts.json` — Use `.claude/settings.json` as Dependency Source of Truth

**Date:** 2026-04-23
**Status:** Draft

---

## Problem

`contracts.json` is a redundant manifest. After `claude plugin install --scope project` runs, the service dependency is already recorded in `.claude/settings.json` under `enabledPlugins`. Two files track the same information.

Validated: `claude plugin marketplace update` fetches plugin content from the marketplace. A new developer only needs marketplace registration + update + `/reload-plugins` — no per-service `claude plugin install` needed on fresh checkout, provided `settings.json` is committed with the correct `enabledPlugins` entries.

---

## Design

### Source of Truth

`.claude/settings.json` (committed) holds `enabledPlugins` as the canonical contract dependency list.

File responsibilities stay clearly split:
- `.claude/settings.json` — committed; shared plugin config including `enabledPlugins`
- `.claude/settings.local.json` — gitignored; dev-specific permissions

### Developer Onboarding (fresh checkout)

```bash
claude plugin marketplace add {marketplaceRepo}
claude plugin marketplace update {marketplaceName}
claude /reload-plugins
```

No per-service install step. Marketplace update fetches plugin files; `/reload-plugins` activates them in the current session; `enabledPlugins` in the committed `settings.json` declares which are active.

### First Setup / Adding a New Dependency

When a developer first declares a contract dependency or adds a new one:

1. `claude plugin install {service-name} --scope project` — fetches files and writes the `enabledPlugins` entry into `.claude/settings.json`
2. Commit `.claude/settings.json`
3. Other devs: `claude plugin marketplace update {marketplaceName}` + `claude /reload-plugins`

### `install-contracts` Skill Changes

| Area | Change |
|------|--------|
| Read step | Remove: read `contracts.json`. Replace with: read `enabledPlugins` from `.claude/settings.json` to detect already-installed contracts and offer to add new ones |
| Install command | Change `--scope local` → `--scope project` |
| Commit step | Remove `contracts.json` from commit. Commit `.claude/settings.json` instead |
| New dev path | If `enabledPlugins` already present in `settings.json` (committed by a prior dev), skip to marketplace setup + remind user to run `/reload-plugins` |
| End of skill | Remind user to run `claude /reload-plugins` to activate newly installed contracts |

### `contracts.json` Removal

- Delete `contracts.json` from any consumer repos that have it
- Remove all references in skill docs and flow diagrams

---

## What Does Not Change

- `.jkit/contract.json` — still persists `marketplaceRepo`, `marketplaceName`, `contractRepo`
- `.jkit/marketplace-catalog.json` — still written for catalog reference
- `publish-contract` skill — no changes needed
- Marketplace registration and update commands — unchanged

---

## Affected Files

| File | Change |
|------|--------|
| `skills/install-contracts/SKILL.md` | Rewrite checklist, flow diagram, and format sections |
| `contracts.json` (consumer repos) | Delete |

