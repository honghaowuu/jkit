#!/usr/bin/env bash
set -euo pipefail
MARKETPLACE_REPO=$1
SERVICE_NAME=$2
DESCRIPTION=$3
CONTRACT_REPO=$4
CLONE_DIR=".jkit/marketplace-clone"
MANIFEST="$CLONE_DIR/.claude-plugin/marketplace.json"

rm -rf "$CLONE_DIR"
git clone "$MARKETPLACE_REPO" "$CLONE_DIR"

python3 - <<EOF
import json, sys
with open("$MANIFEST") as f:
    data = json.load(f)
entry = {
    "name": "$SERVICE_NAME",
    "description": "$DESCRIPTION",
    "source": {"source": "url", "url": "$CONTRACT_REPO"}
}
plugins = data.get("plugins", [])
idx = next((i for i, p in enumerate(plugins) if p["name"] == "$SERVICE_NAME"), None)
if idx is not None:
    plugins[idx] = entry
else:
    plugins.append(entry)
data["plugins"] = plugins
with open("$MANIFEST", "w") as f:
    json.dump(data, f, indent=2)
EOF

git -C "$CLONE_DIR" add .claude-plugin/marketplace.json
git -C "$CLONE_DIR" commit -m "chore: register/update $SERVICE_NAME contract"
git -C "$CLONE_DIR" push origin main
rm -rf "$CLONE_DIR"
