#!/usr/bin/env bash
set -euo pipefail
SERVICE_NAME=$1
CONTRACT_REPO=$2
STAGE_DIR=".jkit/contract-stage/$SERVICE_NAME"

# Detect first run or URL mismatch — re-init if needed
if [ ! -d "$STAGE_DIR/.git" ] || \
   [ "$(git -C "$STAGE_DIR" remote get-url origin 2>/dev/null)" != "$CONTRACT_REPO" ]; then
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR"
  # Caller has already written SKILL.md, domains/, reference/ into STAGE_DIR
  git -C "$STAGE_DIR" init
  git -C "$STAGE_DIR" remote add origin "$CONTRACT_REPO"
  git -C "$STAGE_DIR" add .
  git -C "$STAGE_DIR" commit -m "chore: publish contract for $SERVICE_NAME"
  git -C "$STAGE_DIR" push -u origin main
else
  git -C "$STAGE_DIR" pull origin main
  # Caller has already overwritten files in STAGE_DIR
  git -C "$STAGE_DIR" add .
  git -C "$STAGE_DIR" commit -m "chore: update contract for $SERVICE_NAME"
  git -C "$STAGE_DIR" push origin main
fi
