#!/usr/bin/env bash
set -euo pipefail

MSG=$(git log -1 --pretty=%s)

if echo "$MSG" | grep -qE '^(feat|fix|chore)\(impl\):'; then
  mkdir -p .jkit
  git rev-parse HEAD > .jkit/spec-sync || {
    echo "ERROR: Failed to write .jkit/spec-sync" >&2; exit 1
  }
  git add .jkit/spec-sync
  if ! git diff --cached --quiet; then
    git commit --amend --no-edit || {
      echo "ERROR: Failed to amend commit." >&2
      echo "Recover: run 'git commit --amend --no-edit' or 'git reset HEAD .jkit/spec-sync'" >&2
      exit 1
    }
  fi
fi
