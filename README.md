> **Note:** This project has moved to [Codeberg](https://codeberg.org/karaktaka/dotfiles).
> This GitHub repository is no longer actively maintained.> **Note:** This project has moved to [Codeberg](https://codeberg.org/karaktaka/dotfiles).
> This GitHub repository is no longer actively maintained.# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Features

- **Work/Personal detection** — prompted during `chezmoi init`, conditionally deploys work-specific files
- **Two-repo architecture** — generic dotfiles here (public), work-specific in a private companion repo
- **Symlink overlay** — work files mapped into chezmoi source as symlinks, deployed transparently
- **Age encryption** — sensitive files (SSH config) encrypted at rest, key bootstrapped from Bitwarden
- **Claude Code configs** — settings, commands, skills, hooks (safety enforcement), and reference files
- **Shell enhancements** — zsh (oh-my-zsh) and fish with modern CLI aliases and tool fallbacks
- **Bitwarden integration** — secrets fetched on-demand, never stored in files
- **Native includes** — SSH `Include`, git `[include]`, zsh `source` for mixed-content files

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
brew install chezmoi bitwarden-cli
```

**Linux (Debian/Ubuntu):**
```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Install Bitwarden CLI
sudo snap install bw
```

#### 2. Initialize Chezmoi

```bash
chezmoi init karaktaka/dotfiles
```

You'll be prompted for:
- **Email address** — used in git config
- **Name** — used in git config
- **Is this a work machine?** — determines work/personal mode
- **Work dotfiles repo URL** — (work mode only) SSH URL for the private companion repo

#### 3. Preview and Apply

```bash
# Preview what will be changed
chezmoi diff

# Dry run (no changes made)
chezmoi apply --dry-run --verbose

# Apply changes
chezmoi apply
```

For work machines, chezmoi automatically clones the private work-dotfiles repo via `.chezmoiexternal.yaml.tmpl` during apply. The bootstrap script provisions the age decryption key from Bitwarden.

#### 4. Set Up Bitwarden (for work machines)

```bash
# Login to Bitwarden
bw login

# The shell functions will auto-unlock when needed
```

## Architecture

### Two-Repo Split

| Repo | Host | Visibility | Purpose |
|------|------|------------|---------|
| `karaktaka/dotfiles` | GitHub | Public | Generic dotfiles, templates, overlay stubs |
| Private companion | GitLab | Private | Work-specific files (plaintext) |

### Data Flow

1. `chezmoi init` prompts for email, name, and (if work) the companion repo URL
2. `.chezmoiexternal.yaml.tmpl` clones the companion repo to `~/.local/share/work-dotfiles/`
3. **Symlink overlay** (primary): `chezmoi-overlay.map` in the work repo maps files into the chezmoi source directory as symlinks — chezmoi follows them transparently. Git hooks (`post-commit`, `post-merge`) auto-sync on every commit.
4. **Include wrappers** (few remaining): mixed-content templates that combine personal + work content via `{{ include }}`
5. **Native includes**: SSH `Include config.d/*`, git `[include]`, zsh `source` for files with both personal and work sections

On personal machines: no companion repo, work-only targets excluded via `.chezmoiignore`, native includes silently ignore missing files.

### Age Encryption

Sensitive files use chezmoi's built-in age encryption (`encrypted_` prefix + `.age` extension). The decryption key lives at `~/.config/chezmoi/key.txt` and is provisioned from a Bitwarden secure note during bootstrap.

## Work vs Personal Mode

You're prompted during `chezmoi init` whether this is a work machine:

| Mode | What's Included |
|------|-----------------|
| Work | Full config: cloud tooling, GitLab, Jira, k8s, overlay-deployed work files |
| Personal | Base config: shell aliases, git, Claude basics, fish, vim |

## Directory Structure

```
~/
├── .claude/
│   ├── CLAUDE.md               # Global Claude instructions (template)
│   ├── settings.json           # Claude settings (template, work-conditional)
│   ├── agents/                 # Custom agent definitions (helm-reviewer, etc.)
│   ├── hooks/                  # Safety enforcement hooks
│   ├── rules/                  # Path-scoped rule files (chezmoi, k8s, GitLab, etc.)
│   ├── skills/                 # Reusable skill definitions
│   ├── keybindings.json        # Claude Code keybindings
│   ├── get-flair.sh            # Randomised commit/MR flair generator
│   ├── statusline-command.py   # Custom status line script (template)
│   ├── branch-naming.md        # Branch naming conventions
│   ├── chezmoi.md              # Chezmoi operational gotchas
│   ├── formatter-reference.md  # Linter/formatter commands
│   └── macos-config.md         # macOS path quirks
├── .config/
│   ├── fish/                   # Fish shell config + Bitwarden functions
│   ├── fastfetch/              # Fastfetch config (Catppuccin theme)
│   ├── git/ignore              # Global gitignore
│   └── lazygit/config.yml      # Lazygit config (template)
├── .oh-my-zsh/custom/
│   ├── aliases.zsh             # Modern CLI aliases (template)
│   └── bitwarden.zsh           # Bitwarden helper functions
├── .ssh/config                 # SSH config (age-encrypted)
├── .gitconfig                  # Git configuration (template)
├── .zshrc                      # Zsh config (template)
├── .zprofile                   # Zsh profile (template)
├── .zlogin                     # Zsh login (fortune | cowsay)
└── .vimrc                      # Vim config + Catppuccin theme
```

Work-only files (deployed via symlink overlay on work machines):
```
├── .claude/{kubernetes,observability,work-environment,gitlab-mr-api}.md
├── .claude/hooks/{infra-safety,permissions-bash-{k8s,cloud,glab,infra,collab},permissions-webfetch}.sh
├── .claude/bin/gitlab-post-review-note.sh
├── .oh-my-zsh/custom/{aws,k8s,sso,confluence}.zsh
├── .zshrc.d/{pre,post}.zsh
├── .ssh/config.d/work
├── .gitconfig.d/work
├── .local/bin/workspace-init
└── Library/Application Support/{mark.toml, k9s/}
```

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

# Add a sensitive file with encryption
chezmoi add --encrypt ~/.some-secret

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

The age key must be at `~/.config/chezmoi/key.txt`. If missing, re-run the bootstrap or manually copy from Bitwarden (`Chezmoi Age Encryption Key` secure note):
```bash
mkdir -p ~/.config/chezmoi
bw get notes "Chezmoi Age Encryption Key" > ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
```

### Bitwarden unlock prompts

The `ensure_bw_session` function handles this automatically. If it fails:
```bash
bw unlock
export BW_SESSION="<session-key>"
```

## License

Personal dotfiles — feel free to use as inspiration for your own setup.