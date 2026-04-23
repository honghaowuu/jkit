# install-contracts Shell Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `install-contracts` skill with a standalone shell script `bin/install-contracts.sh` that a developer can run directly from the terminal.

**Architecture:** `bin/install-contracts.sh` handles the full flow — resolving marketplace config from `.jkit/contract.json` (prompting if missing), registering/refreshing the marketplace, writing the catalog, installing named contract plugins with `claude plugin install --scope project`, committing changed files, and reminding the developer to run `/reload-plugins`. The skill directory and its `plugin.json` entry are deleted.

**Tech Stack:** bash, python3 (JSON manipulation), Claude Code CLI (`claude plugin marketplace`, `claude plugin install`), shellcheck

---

## File Structure

| File | Action |
|------|--------|
| `bin/install-contracts.sh` | Create |
| `.claude-plugin/plugin.json` | Modify — remove `install-contracts` entry |
| `skills/install-contracts/` | Delete entire directory |

---

### Task 1: Create `bin/install-contracts.sh`

**Files:**
- Create: `bin/install-contracts.sh`

- [ ] **Step 1: Write the script**

Create `bin/install-contracts.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

CONTRACT_JSON=".jkit/contract.json"
SETTINGS_JSON=".claude/settings.json"
CATALOG_JSON=".jkit/marketplace-catalog.json"
CLONE_DIR=".jkit/marketplace-clone"

# Resolve marketplaceRepo and marketplaceName from .jkit/contract.json
MARKETPLACE_REPO=""
MARKETPLACE_NAME=""

if [ -f "$CONTRACT_JSON" ]; then
  MARKETPLACE_REPO=$(python3 -c "import json; d=json.load(open('$CONTRACT_JSON')); print(d.get('marketplaceRepo',''))")
  MARKETPLACE_NAME=$(python3 -c "import json; d=json.load(open('$CONTRACT_JSON')); print(d.get('marketplaceName',''))")
fi

if [ -z "$MARKETPLACE_REPO" ]; then
  read -rp "Marketplace repo URL (e.g. git@github.com:org/marketplace.git): " MARKETPLACE_REPO
fi
if [ -z "$MARKETPLACE_NAME" ]; then
  read -rp "Marketplace name (e.g. org-marketplace): " MARKETPLACE_NAME
fi

mkdir -p .jkit
python3 - <<PYEOF
import json, os
path = "$CONTRACT_JSON"
data = json.load(open(path)) if os.path.exists(path) else {}
data["marketplaceRepo"] = "$MARKETPLACE_REPO"
data["marketplaceName"] = "$MARKETPLACE_NAME"
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PYEOF

# Register and refresh marketplace
claude plugin marketplace add "$MARKETPLACE_REPO"
claude plugin marketplace update "$MARKETPLACE_NAME"

# Clone marketplace, write .jkit/marketplace-catalog.json, delete clone
rm -rf "$CLONE_DIR"
git clone "$MARKETPLACE_REPO" "$CLONE_DIR"

python3 - <<PYEOF
import json
from datetime import datetime, timezone
with open("$CLONE_DIR/.claude-plugin/marketplace.json") as f:
    data = json.load(f)
catalog = {
    "marketplaceName": "$MARKETPLACE_NAME",
    "updatedAt": datetime.now(timezone.utc).isoformat(),
    "contracts": [
        {"name": p["name"], "description": p["description"]}
        for p in data.get("plugins", [])
    ]
}
with open("$CATALOG_JSON", "w") as f:
    json.dump(catalog, f, indent=2)
PYEOF

rm -rf "$CLONE_DIR"

# Resolve service list: use positional args or prompt interactively
if [ $# -gt 0 ]; then
  SERVICES=("$@")
else
  if [ -f "$SETTINGS_JSON" ]; then
    EXISTING=$(python3 -c "
import json
try:
    d = json.load(open('$SETTINGS_JSON'))
    keys = list(d.get('enabledPlugins', {}).keys())
    print(', '.join(keys) if keys else '')
except Exception:
    print('')
")
    if [ -n "$EXISTING" ]; then
      echo "Currently installed contracts: $EXISTING"
    fi
  fi
  read -rp "Service names to add (space-separated, enter to skip): " INPUT
  if [ -z "$INPUT" ]; then
    SERVICES=()
  else
    read -ra SERVICES <<< "$INPUT"
  fi
fi

# Validate against catalog and install
CATALOG_NAMES=$(python3 -c "
import json
try:
    d = json.load(open('$CATALOG_JSON'))
    print(' '.join(c['name'] for c in d.get('contracts', [])))
except Exception:
    print('')
")

INSTALLED=()
if [ ${#SERVICES[@]} -gt 0 ]; then
  for SERVICE in "${SERVICES[@]}"; do
    if [[ ! " $CATALOG_NAMES " =~ " $SERVICE " ]]; then
      echo "WARNING: '$SERVICE' not found in marketplace catalog — skipping" >&2
    else
      claude plugin install "$SERVICE" --scope project
      INSTALLED+=("$SERVICE")
    fi
  done
fi

# Commit
if [ ${#INSTALLED[@]} -gt 0 ]; then
  SERVICES_STR=$(IFS=", "; echo "${INSTALLED[*]}")
  COMMIT_MSG="chore: install contracts [$SERVICES_STR]"
else
  COMMIT_MSG="chore: refresh marketplace catalog"
fi

git add "$SETTINGS_JSON" "$CATALOG_JSON" "$CONTRACT_JSON"
git commit -m "$COMMIT_MSG"

echo ""
echo "Run 'claude /reload-plugins' to activate installed contracts in the current session"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x bin/install-contracts.sh
```

- [ ] **Step 3: Syntax check**

```bash
bash -n bin/install-contracts.sh
```

Expected: no output (clean).

- [ ] **Step 4: Lint with shellcheck**

```bash
shellcheck bin/install-contracts.sh
```

Expected: no warnings. If shellcheck flags anything, fix it before continuing.

- [ ] **Step 5: Commit**

```bash
git add bin/install-contracts.sh
git commit -m "feat(bin): add install-contracts.sh to replace install-contracts skill"
```

Expected: 1 file changed.

---

### Task 2: Remove skill and update `plugin.json`

**Files:**
- Delete: `skills/install-contracts/SKILL.md`
- Delete: `skills/install-contracts/` (directory)
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Delete the skill directory**

```bash
rm -rf skills/install-contracts
```

Verify:

```bash
ls skills/
```

Expected: `install-contracts` is gone. Remaining: `generate-feign  java-tdd  java-verify  publish-contract  scenario-gap  scenario-tdd  spec-delta  sql-migration`

- [ ] **Step 2: Remove `install-contracts` from `plugin.json`**

Edit `.claude-plugin/plugin.json` so the `skills` array reads:

```json
{
  "name": "jkit",
  "description": "Spec-driven development workflow for Java/Spring Boot SaaS microservice teams — TDD, coverage, contract testing, service contract publishing",
  "version": "0.3.0",
  "author": { "name": "honghaowu" },
  "license": "UNLICENSED",
  "keywords": ["java", "spring-boot", "microservice", "tdd", "scenario-tdd"],
  "skills": [
    { "name": "spec-delta",        "path": "skills/spec-delta" },
    { "name": "sql-migration",     "path": "skills/sql-migration" },
    { "name": "java-tdd",          "path": "skills/java-tdd" },
    { "name": "scenario-gap",      "path": "skills/scenario-gap" },
    { "name": "scenario-tdd",      "path": "skills/scenario-tdd" },
    { "name": "java-verify",       "path": "skills/java-verify" },
    { "name": "publish-contract",  "path": "skills/publish-contract" },
    { "name": "generate-feign",    "path": "skills/generate-feign" }
  ],
  "hooks": "hooks/hooks.json"
}
```

- [ ] **Step 3: Verify `plugin.json` is valid JSON**

```bash
python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('valid')"
```

Expected: `valid`

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json skills/install-contracts
git commit -m "chore: remove install-contracts skill — replaced by bin/install-contracts.sh"
```

Expected: files changed include `plugin.json` and the deleted `SKILL.md`.
