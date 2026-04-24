#!/usr/bin/env bash
set -euo pipefail

MSG=$(git log -1 --pretty=%s)

if echo "$MSG" | grep -qE '^(feat|fix|chore)\(impl\):'; then
  # Find the most recent run directory under .jkit/
  RUN_DIR=$(ls -dt .jkit/????-??-??-*/ 2>/dev/null | head -1)

  if [ -z "$RUN_DIR" ]; then
    echo "jkit: no run directory found under .jkit/ — skipping change-file move" >&2
    exit 0
  fi

  CHANGE_FILES="${RUN_DIR}.change-files"

  if [ ! -f "$CHANGE_FILES" ]; then
    echo "jkit: no .change-files in ${RUN_DIR} — skipping" >&2
    exit 0
  fi

  mkdir -p docs/changes/done

  STAGED=0
  while IFS= read -r fname; do
    [ -z "$fname" ] && continue
    src="docs/changes/pending/${fname}"
    dst="docs/changes/done/${fname}"
    if [ -f "$src" ]; then
      mv "$src" "$dst"
      STAGED=1
    fi
  done < "$CHANGE_FILES"

  if [ "$STAGED" -eq 1 ]; then
    git add docs/changes/
    if ! git diff --cached --quiet; then
      git commit --amend --no-edit || {
        echo "ERROR: Failed to amend commit." >&2
        echo "Recover: run 'git commit --amend --no-edit' or 'git reset HEAD docs/changes/'" >&2
        exit 1
      }
    fi
  fi
fi
