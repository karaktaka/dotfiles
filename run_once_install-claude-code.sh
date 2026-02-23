#!/bin/bash
# Install Claude Code CLI using the native installer
# run_once: only runs on first chezmoi apply, not on every apply

set -euo pipefail

if command -v claude &>/dev/null; then
  echo "Claude Code already installed: $(claude --version 2>&1 | head -1)"
  exit 0
fi

if ! command -v curl &>/dev/null; then
  echo "WARNING: curl not found. Install curl first, then run:"
  echo "  curl -fsSL https://claude.ai/install.sh | bash"
  exit 0
fi

echo "Installing Claude Code via native installer..."
curl -fsSL https://claude.ai/install.sh | bash

if command -v claude &>/dev/null; then
  echo "Claude Code installed successfully: $(claude --version 2>&1 | head -1)"
else
  echo "WARNING: Claude Code installation may need a new shell. Install manually:"
  echo "  curl -fsSL https://claude.ai/install.sh | bash"
fi
