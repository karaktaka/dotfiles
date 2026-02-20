#!/bin/bash
# Install RTK (Rust Token Killer) for Claude Code token optimization
# run_once: only runs on first chezmoi apply, not on every apply

set -euo pipefail

if command -v rtk &>/dev/null; then
  echo "RTK already installed: $(rtk --version 2>&1 | head -1)"
  exit 0
fi

echo "Installing RTK..."
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

if command -v rtk &>/dev/null; then
  echo "RTK installed successfully: $(rtk --version 2>&1 | head -1)"
  echo "Run 'rtk init -g --hook-only' to set up the Claude Code hook."
else
  echo "WARNING: RTK installation failed. Install manually:"
  echo "  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
fi
