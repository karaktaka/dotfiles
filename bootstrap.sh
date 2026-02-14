#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Dotfiles Bootstrap                        ║"
echo "║                    github.com/karaktaka/dotfiles             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ -f /etc/debian_version ]]; then
    OS="debian"
elif [[ -f /etc/redhat-release ]]; then
    OS="redhat"
elif [[ -f /etc/arch-release ]]; then
    OS="arch"
fi

echo -e "${BLUE}▶ Detected OS:${NC} $OS"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Install Homebrew (macOS)
# ─────────────────────────────────────────────────────────────────────────────
install_homebrew() {
    if ! command_exists brew; then
        echo -e "${YELLOW}▶ Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add to PATH for this session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        echo -e "${GREEN}✓ Homebrew already installed${NC}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Install dependencies
# ─────────────────────────────────────────────────────────────────────────────
install_dependencies() {
    echo ""
    echo -e "${BLUE}▶ Installing dependencies...${NC}"

    case $OS in
        macos)
            install_homebrew

            # Install required packages
            PACKAGES="chezmoi age bitwarden-cli"
            for pkg in $PACKAGES; do
                if brew list "$pkg" &>/dev/null; then
                    echo -e "${GREEN}✓ $pkg already installed${NC}"
                else
                    echo -e "${YELLOW}▶ Installing $pkg...${NC}"
                    brew install "$pkg"
                fi
            done
            ;;

        debian)
            echo -e "${YELLOW}▶ Installing chezmoi...${NC}"
            if ! command_exists chezmoi; then
                sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
                export PATH="$HOME/.local/bin:$PATH"
            fi

            echo -e "${YELLOW}▶ Installing age...${NC}"
            if ! command_exists age; then
                sudo apt update && sudo apt install -y age
            fi

            echo -e "${YELLOW}▶ Installing Bitwarden CLI...${NC}"
            if ! command_exists bw; then
                if command_exists snap; then
                    sudo snap install bw
                else
                    echo -e "${RED}⚠ Please install Bitwarden CLI manually: https://bitwarden.com/help/cli/${NC}"
                fi
            fi
            ;;

        arch)
            echo -e "${YELLOW}▶ Installing packages...${NC}"
            sudo pacman -S --needed chezmoi age bitwarden-cli
            ;;

        *)
            echo -e "${RED}⚠ Unsupported OS. Please install manually:${NC}"
            echo "  - chezmoi: https://www.chezmoi.io/install/"
            echo "  - age: https://github.com/FiloSottile/age"
            echo "  - bitwarden-cli: https://bitwarden.com/help/cli/"
            exit 1
            ;;
    esac

    # Configure Bitwarden to use self-hosted server
    if command_exists bw; then
        bw config server https://passwords.ethernerd.net
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Initialize chezmoi
# ─────────────────────────────────────────────────────────────────────────────
init_chezmoi() {
    echo ""
    echo -e "${BLUE}▶ Initializing chezmoi...${NC}"
    echo ""
    echo -e "${YELLOW}You will be prompted for:${NC}"
    echo "  • Email address (determines work/personal mode)"
    echo "  • Name (used in git config)"
    echo ""

    if [[ -d ~/.local/share/chezmoi ]]; then
        echo -e "${YELLOW}⚠ Chezmoi already initialized. Updating...${NC}"
        chezmoi update --init
    else
        chezmoi init --ssh karaktaka/dotfiles
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Setup age key
# ─────────────────────────────────────────────────────────────────────────────
setup_age_key() {
    echo ""
    echo -e "${BLUE}▶ Checking age encryption key...${NC}"

    KEY_PATH="$HOME/.config/chezmoi/key.txt"

    if [[ -f "$KEY_PATH" ]]; then
        echo -e "${GREEN}✓ Age key already present${NC}"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}⚠ Age key not found at $KEY_PATH${NC}"
    echo ""
    mkdir -p ~/.config/chezmoi

    # Try Bitwarden first (recommended)
    if command_exists bw; then
        echo -e "${BLUE}▶ Attempting to fetch key from Bitwarden...${NC}"
        echo ""

        # Check if logged in
        BW_STATUS=$(bw status | jq -r '.status')

        if [[ "$BW_STATUS" == "unauthenticated" ]]; then
            echo -e "${YELLOW}Please login to Bitwarden:${NC}"
            bw login
            BW_STATUS="locked"
        fi

        if [[ "$BW_STATUS" == "locked" ]]; then
            echo -e "${YELLOW}Please unlock Bitwarden:${NC}"
            export BW_SESSION=$(bw unlock --raw)
            bw sync --quiet
        fi

        # Fetch the key
        KEY_CONTENT=$(bw get notes "Chezmoi Age Encryption Key" 2>/dev/null)

        if [[ -n "$KEY_CONTENT" ]]; then
            echo "$KEY_CONTENT" > "$KEY_PATH"
            chmod 600 "$KEY_PATH"
            echo -e "${GREEN}✓ Age key fetched from Bitwarden${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Key not found in Bitwarden (item: 'Chezmoi Age Encryption Key')${NC}"
        fi
    fi

    # Fallback: manual setup
    echo ""
    echo "The repo uses age encryption for sensitive files."
    echo ""
    echo "Options:"
    echo "  1. Copy from another machine:"
    echo "     scp other-machine:~/.config/chezmoi/key.txt ~/.config/chezmoi/key.txt"
    echo ""
    echo "  2. Restore from backup:"
    echo "     cp /path/to/backup/key.txt ~/.config/chezmoi/key.txt"
    echo ""

    read -p "Do you have the key available now? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter path to key file: " key_source
        if [[ -f "$key_source" ]]; then
            cp "$key_source" "$KEY_PATH"
            chmod 600 "$KEY_PATH"
            echo -e "${GREEN}✓ Key copied successfully${NC}"
        else
            echo -e "${RED}✗ File not found: $key_source${NC}"
            echo "You can set up the key later and run: chezmoi apply"
        fi
    else
        echo -e "${YELLOW}⚠ Skipping key setup. Some encrypted files won't be available.${NC}"
        echo "Set up the key later and run: chezmoi apply"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Apply dotfiles
# ─────────────────────────────────────────────────────────────────────────────
apply_dotfiles() {
    echo ""
    echo -e "${BLUE}▶ Applying dotfiles...${NC}"
    echo ""

    # Show what will be changed
    echo -e "${YELLOW}Preview of changes:${NC}"
    chezmoi diff --no-pager | head -50 || true
    echo ""

    read -p "Apply these changes? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        chezmoi apply
        echo -e "${GREEN}✓ Dotfiles applied successfully!${NC}"
    else
        echo -e "${YELLOW}⚠ Skipped. Run 'chezmoi apply' when ready.${NC}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Post-install info
# ─────────────────────────────────────────────────────────────────────────────
show_post_install() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Setup Complete! 🎉                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check work mode
    IS_WORK=$(chezmoi execute-template '{{ .isWork }}' 2>/dev/null || echo "unknown")

    if [[ "$IS_WORK" == "true" ]]; then
        echo -e "${BLUE}Mode:${NC} Work (Work)"
        echo ""
        echo -e "${YELLOW}Next steps for work setup:${NC}"
        echo "  1. Login to Bitwarden:  bw login"
        echo "  2. Login to AWS:        login_aws"
        echo "  3. Set GitLab token:    set_gitlab_token"
        echo "  4. Set Jira token:      set_jira_token"
    else
        echo -e "${BLUE}Mode:${NC} Personal"
    fi

    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  chezmoi diff      # Preview pending changes"
    echo "  chezmoi apply     # Apply changes"
    echo "  chezmoi update    # Pull and apply latest"
    echo "  chezmoi data      # View config data"
    echo ""
    echo -e "${YELLOW}Reload your shell to pick up changes:${NC}"
    echo "  source ~/.zshrc   # or restart terminal"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
    install_dependencies
    init_chezmoi
    setup_age_key
    apply_dotfiles
    show_post_install
}

main "$@"
