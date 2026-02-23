#!/bin/bash
# Install Claude Code CLI into ~/.local for rootless operation
# run_once: only runs on first chezmoi apply, not on every apply

set -euo pipefail

if command -v claude &>/dev/null; then
  echo "Claude Code already installed: $(claude --version 2>&1 | head -1)"
  exit 0
fi

if ! command -v npm &>/dev/null; then
  echo "WARNING: npm not found. Install Node.js first, then run:"
  echo "  npm install -g --prefix ~/.local @anthropic-ai/claude-code"
  exit 0
fi

echo "Installing Claude Code into ~/.local..."
npm install -g --prefix ~/.local @anthropic-ai/claude-code

if command -v claude &>/dev/null; then
  echo "Claude Code installed successfully: $(claude --version 2>&1 | head -1)"
else
  echo "WARNING: Claude Code installation failed. Install manually:"
  echo "  npm install -g --prefix ~/.local @anthropic-ai/claude-code"
fi
