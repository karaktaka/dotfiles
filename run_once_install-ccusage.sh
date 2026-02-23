#!/bin/bash
# Install ccusage (Claude Code usage analysis) into ~/.local for rootless operation
# run_once: only runs on first chezmoi apply, not on every apply

set -euo pipefail

if command -v ccusage &>/dev/null; then
  echo "ccusage already installed: $(ccusage --version 2>&1 | head -1)"
  exit 0
fi

if ! command -v npm &>/dev/null; then
  echo "WARNING: npm not found. Install Node.js first, then run:"
  echo "  npm install -g --prefix ~/.local ccusage"
  exit 0
fi

echo "Installing ccusage into ~/.local..."
npm install -g --prefix ~/.local ccusage

if command -v ccusage &>/dev/null; then
  echo "ccusage installed successfully: $(ccusage --version 2>&1 | head -1)"
else
  echo "WARNING: ccusage installation failed. Install manually:"
  echo "  npm install -g --prefix ~/.local ccusage"
fi
