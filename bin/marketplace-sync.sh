#!/usr/bin/env bash
set -euo pipefail
MARKETPLACE_REPO=$1
MARKETPLACE_NAME=$2
CLONE_DIR=".jkit/marketplace-clone"
MANIFEST="$CLONE_DIR/.claude-plugin/marketplace.json"

claude plugin marketplace update "$MARKETPLACE_NAME"

rm -rf "$CLONE_DIR"
git clone "$MARKETPLACE_REPO" "$CLONE_DIR"

python3 - <<EOF
import json
from datetime import datetime, timezone
with open("$MANIFEST") as f:
    data = json.load(f)
catalog = {
    "marketplaceName": "$MARKETPLACE_NAME",
    "updatedAt": datetime.now(timezone.utc).isoformat(),
    "contracts": [
        {"name": p["name"], "description": p["description"]}
        for p in data.get("plugins", [])
    ]
}
with open(".jkit/marketplace-catalog.json", "w") as f:
    json.dump(catalog, f, indent=2)
EOF

rm -rf "$CLONE_DIR"
