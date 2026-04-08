#!/usr/bin/env bash
set -euo pipefail

MSG=$(git log -1 --pretty=%s)

if echo "$MSG" | grep -qE '^(feat|fix|chore)\(impl\):'; then
  # Ensure docs/ directory exists
  mkdir -p docs

  # Write current HEAD SHA to .spec-sync
  git rev-parse HEAD > docs/.spec-sync || {
    echo "ERROR: Failed to write docs/.spec-sync" >&2
    exit 1
  }

  git add docs/.spec-sync

  # Only amend if .spec-sync actually changed
  if ! git diff --cached --quiet; then
    git commit --amend --no-edit || {
      echo "ERROR: Failed to amend commit with .spec-sync update." >&2
      echo "To recover: run 'git commit --amend --no-edit' manually," >&2
      echo "or 'git reset HEAD docs/.spec-sync' to unstage and skip." >&2
      exit 1
    }
  fi
fi
