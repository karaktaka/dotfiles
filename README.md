# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Features

- **Work/Personal detection** — automatically configures based on email domain
- **Claude Code configs** — settings, commands, and reference files
- **Shell enhancements** — modern CLI aliases with tool fallbacks
- **Bitwarden integration** — secrets fetched on-demand, never stored in files
- **Conditional deployment** — work-only files excluded on personal machines

## Quick Start

### One-liner Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/karaktaka/dotfiles/main/bootstrap.sh | bash
```

Or with wget:
```bash
wget -qO- https://raw.githubusercontent.com/karaktaka/dotfiles/main/bootstrap.sh | bash
```

### Manual Installation

#### 1. Install Dependencies

**macOS (Homebrew):**
```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install chezmoi age bitwarden-cli
```

**Linux (Debian/Ubuntu):**
```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Install age
sudo apt install age

# Install Bitwarden CLI
sudo snap install bw
```

#### 2. Initialize Chezmoi

```bash
chezmoi init karaktaka/dotfiles
```

You'll be prompted for:
- **Email address** — determines work/personal mode (`@example.com` = work)
- **Name** — used in git config

#### 3. Set Up Age Key

The repo uses age encryption for sensitive files. The key is stored in Bitwarden.

**Option A: Fetch from Bitwarden (Recommended)**
```bash
# Login and unlock Bitwarden
bw login
export BW_SESSION=$(bw unlock --raw)

# Fetch the key
mkdir -p ~/.config/chezmoi
bw get notes "Chezmoi Age Encryption Key" > ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
```

**Option B: Copy from another machine**
```bash
scp other-machine:~/.config/chezmoi/key.txt ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
```

> **Note:** The bootstrap script will attempt to fetch from Bitwarden automatically.

#### 4. Preview and Apply

```bash
# Preview what will be changed
chezmoi diff

# Dry run (no changes made)
chezmoi apply --dry-run --verbose

# Apply changes
chezmoi apply
```

#### 5. Set Up Bitwarden (for work machines)

```bash
# Login to Bitwarden
bw login

# The shell functions will auto-unlock when needed
```

## Work vs Personal Mode

The setup automatically detects work/personal based on your email:

| Email Domain | Mode | What's Included |
|--------------|------|-----------------|
| `@example.com` | Work | Full config: AWS, K8s, GitLab, Jira integration |
| Any other | Personal | Base config: shell aliases, git, Claude basics |

**Work-only files** (excluded on personal machines):
- `~/.oh-my-zsh/custom/aws.zsh`
- `~/.oh-my-zsh/custom/k8s.zsh`
- AWS/Bedrock environment variables in Claude settings

## Directory Structure

```
~/
├── CLAUDE.md                    # Global Claude instructions
├── .claude/
│   ├── settings.json            # Claude settings (work-conditional)
│   ├── commands/                # Custom slash commands
│   ├── commit-flair.md          # Co-author characters reference
│   ├── formatter-reference.md   # Linter/formatter commands
│   └── statusline-command.sh    # Custom status line script
├── .oh-my-zsh/custom/
│   ├── aliases.zsh              # Modern CLI aliases
│   ├── bitwarden.zsh            # Bitwarden helper functions
│   ├── generic.zsh              # General shell functions
│   ├── aws.zsh                  # AWS helpers (work-only)
│   └── k8s.zsh                  # Kubernetes helpers (work-only)
├── .gitconfig                   # Git configuration
├── .zprofile                    # Zsh profile
└── .zlogin                      # Zsh login
```

## Bitwarden Items Required

### Universal (All Machines)

| Item Name | Type | Used By |
|-----------|------|---------|
| `Chezmoi Age Encryption Key` | Secure Note | Bootstrap script, age decryption |

### Work Mode Only

| Item Name | Fields | Used By |
|-----------|--------|---------|
| `Gitlab Personal Token` | password | `set_gitlab_token()` |
| `Jira API Token` | password | `set_jira_token()` |
| `SSO Admin Credentials Test` | client_id, client_secret | `sso_admin_auth test` |
| `SSO Admin Credentials Prod` | client_id, client_secret | `sso_admin_auth prod` |

## Daily Usage

### Update Dotfiles

```bash
# Pull latest changes
chezmoi update

# Or pull and review before applying
chezmoi git pull
chezmoi diff
chezmoi apply
```

### Add New Files

```bash
# Add a file to chezmoi management
chezmoi add ~/.some-config

# Edit the source directly
chezmoi edit ~/.some-config

# Apply changes
chezmoi apply
```

### Useful Commands

```bash
chezmoi data          # View template data (email, isWork, etc.)
chezmoi diff          # Preview pending changes
chezmoi doctor        # Check for issues
chezmoi managed       # List all managed files
chezmoi cd            # CD into source directory
```

## Troubleshooting

### "map has no entry for key isWork"

Run `chezmoi init` to regenerate config with new variables:
```bash
chezmoi init
```

### Age decryption fails

Ensure your key is in place:
```bash
ls -la ~/.config/chezmoi/key.txt
```

### Bitwarden unlock prompts

The `ensure_bw_session` function handles this automatically. If it fails:
```bash
bw unlock
export BW_SESSION="<session-key>"
```

## License

Personal dotfiles — feel free to use as inspiration for your own setup.
