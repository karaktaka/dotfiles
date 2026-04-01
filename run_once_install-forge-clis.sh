#!/usr/bin/env bash
# Install forge CLIs: gh (GitHub), glab (GitLab), tea (Gitea), berg (Codeberg/Forgejo)
# run_once: only runs on first chezmoi apply per machine

set -euo pipefail

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ -f /etc/arch-release ]]; then
  OS="arch"
elif [[ -f /etc/debian_version ]]; then
  OS="debian"
fi

install_arch() {
  local pkgs=()
  command -v gh   &>/dev/null || pkgs+=(github-cli)
  command -v glab &>/dev/null || pkgs+=(glab)
  command -v tea  &>/dev/null || pkgs+=(tea)
  command -v berg &>/dev/null || pkgs+=(codeberg-cli)

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    echo "All forge CLIs already installed."
    return
  fi

  echo "Installing via pacman: ${pkgs[*]}"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_macos() {
  if ! command -v brew &>/dev/null; then
    echo "WARNING: Homebrew not found. Install forge CLIs manually."
    return
  fi

  local formulae=()
  command -v gh   &>/dev/null || formulae+=(gh)
  command -v glab &>/dev/null || formulae+=(glab)
  command -v tea  &>/dev/null || formulae+=(tea)

  if [[ ${#formulae[@]} -gt 0 ]]; then
    echo "Installing via Homebrew: ${formulae[*]}"
    brew install "${formulae[@]}"
  fi

  # berg (codeberg-cli) — not in Homebrew core; install via cargo if available
  if ! command -v berg &>/dev/null; then
    if command -v cargo &>/dev/null; then
      echo "Installing berg via cargo..."
      cargo install codeberg-cli
    else
      echo "WARNING: berg (codeberg-cli) not available via Homebrew. Install manually:"
      echo "  cargo install codeberg-cli"
      echo "  or download from https://codeberg.org/RobWalt/codeberg-cli/releases"
    fi
  fi
}

install_debian() {
  local missing=()
  command -v gh   &>/dev/null || missing+=(gh)
  command -v glab &>/dev/null || missing+=(glab)
  command -v tea  &>/dev/null || missing+=(tea)
  command -v berg &>/dev/null || missing+=(berg)

  for tool in "${missing[@]}"; do
    case "$tool" in
      gh)
        echo "Installing gh..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
          | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update && sudo apt install -y gh
        ;;
      glab)
        echo "Installing glab via latest release..."
        GLAB_VER=$(curl -fsSL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['tag_name'])" 2>/dev/null || echo "v1.90.0")
        curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/${GLAB_VER}/downloads/glab_${GLAB_VER#v}_linux_amd64.deb" \
          -o /tmp/glab.deb && sudo dpkg -i /tmp/glab.deb && rm /tmp/glab.deb
        ;;
      tea)
        echo "Installing tea via latest release..."
        TEA_VER=$(curl -fsSL https://gitea.com/api/v1/repos/gitea/tea/releases?limit=1 | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['tag_name'])" 2>/dev/null || echo "v0.12.0")
        curl -fsSL "https://dl.gitea.com/tea/${TEA_VER}/tea-${TEA_VER}-linux-amd64" \
          -o ~/.local/bin/tea && chmod +x ~/.local/bin/tea
        ;;
      berg)
        echo "WARNING: berg (codeberg-cli) has no Debian package. Install manually:"
        echo "  cargo install codeberg-cli"
        echo "  or download from https://codeberg.org/RobWalt/codeberg-cli/releases"
        ;;
    esac
  done
}

case "$OS" in
  arch)    install_arch ;;
  macos)   install_macos ;;
  debian)  install_debian ;;
  *)
    echo "WARNING: Unsupported OS. Install forge CLIs manually:"
    echo "  gh: https://github.com/cli/cli"
    echo "  glab: https://gitlab.com/gitlab-org/cli"
    echo "  tea: https://gitea.com/gitea/tea"
    echo "  berg: https://codeberg.org/RobWalt/codeberg-cli"
    ;;
esac

echo "Forge CLI install complete."
