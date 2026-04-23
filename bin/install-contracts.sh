#!/usr/bin/env bash
set -euo pipefail

CONTRACT_JSON=".jkit/contract.json"
SETTINGS_JSON=".claude/settings.json"
CATALOG_JSON=".jkit/marketplace-catalog.json"
CLONE_DIR=".jkit/marketplace-clone"

trap 'rm -rf "$CLONE_DIR"' EXIT

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
    if [[ " $CATALOG_NAMES " != *" $SERVICE "* ]]; then
      echo "WARNING: '$SERVICE' not found in marketplace catalog — skipping" >&2
    elif ! claude plugin install "$SERVICE" --scope project; then
      echo "WARNING: failed to install '$SERVICE'" >&2
    else
      INSTALLED+=("$SERVICE")
    fi
  done
fi

# Commit
if [ ${#INSTALLED[@]} -gt 0 ]; then
  SERVICES_STR=$(printf "%s, " "${INSTALLED[@]}"); SERVICES_STR="${SERVICES_STR%, }"
  COMMIT_MSG="chore: install contracts [$SERVICES_STR]"
else
  COMMIT_MSG="chore: refresh marketplace catalog"
fi

STAGE_FILES=()
for _f in "$SETTINGS_JSON" "$CATALOG_JSON" "$CONTRACT_JSON"; do
  [ -f "$_f" ] && STAGE_FILES+=("$_f")
done
[ ${#STAGE_FILES[@]} -gt 0 ] && git add "${STAGE_FILES[@]}"
git diff --cached --quiet || git commit -m "$COMMIT_MSG"

echo ""
echo "Run 'claude /reload-plugins' to activate installed contracts in the current session"
