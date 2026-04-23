# install-contracts: Replace Skill with Shell Script

**Date:** 2026-04-23
**Status:** Draft

---

## Problem

The `install-contracts` skill is purely mechanical — no AI judgment required. Every step is a deterministic CLI command or file read. Having it as an AI skill adds variance (interpretation differs per session) and requires Claude to be active. Developers cannot run it directly from the terminal.

---

## Design

### Script: `bin/install-contracts.sh`

Replaces the skill entirely. Follows the same patterns as the existing bin scripts (`contract-push.sh`, `marketplace-publish.sh`, `marketplace-sync.sh`).

#### Interface

```bash
bin/install-contracts.sh [service-name...]
```

- **With args**: installs exactly the named services, no prompts for service names
- **No args**: reads current `enabledPlugins` from `.claude/settings.json`, prints existing list, then prompts: `"Service names to add (space-separated, enter to skip): "`

#### Execution Sequence

1. Read `.jkit/contract.json` for `marketplaceRepo` and `marketplaceName`. If file or fields are missing, prompt and save.
2. `claude plugin marketplace add {marketplaceRepo}` — idempotent, safe to re-run
3. `claude plugin marketplace update {marketplaceName}` — fetches latest plugin content
4. Clone marketplace repo → read `.claude-plugin/marketplace.json` → write `.jkit/marketplace-catalog.json` → delete clone
5. Resolve service list: use args if provided, otherwise prompt interactively
6. For each service: warn to stderr if name not found in `.jkit/marketplace-catalog.json`
7. `claude plugin install {service-name} --scope project` — writes `enabledPlugins` entry to `.claude/settings.json`
8. `git add .claude/settings.json .jkit/marketplace-catalog.json .jkit/contract.json`
9. `git commit -m "chore: install contracts [service1, service2, ...]"`
10. Print: `"Run 'claude /reload-plugins' to activate installed contracts in the current session"`

#### Config file: `.jkit/contract.json`

Read for `marketplaceRepo` and `marketplaceName`. If missing, prompt and persist:

```json
{
  "marketplaceRepo": "git@github.com:{org}/marketplace.git",
  "marketplaceName": "{org}-marketplace"
}
```

If `contractRepo` is already present (written by `publish-contract`), leave it untouched.

#### Marketplace catalog validation

After writing `.jkit/marketplace-catalog.json`, the script checks each requested service name against the catalog's `contracts[].name` list. Unknown services print a warning to stderr but do not abort — the install continues for valid services.

#### New developer onboarding

When `enabledPlugins` is already present in the committed `.claude/settings.json` (i.e., a prior developer ran the script and committed), a new developer only needs:

```bash
claude plugin marketplace add {marketplaceRepo}
claude plugin marketplace update {marketplaceName}
claude /reload-plugins
```

They do not need to run `bin/install-contracts.sh` at all unless adding new dependencies.

---

## Deletions

| Path | Action |
|------|--------|
| `skills/install-contracts/` | Delete entire directory |
| `.claude-plugin/plugin.json` | Remove `install-contracts` entry from `skills` array |

---

## Affected Files

| File | Change |
|------|--------|
| `bin/install-contracts.sh` | Create |
| `.claude-plugin/plugin.json` | Remove `install-contracts` skill entry |
| `skills/install-contracts/SKILL.md` | Delete |
