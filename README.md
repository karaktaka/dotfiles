# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Features

- **Work/Personal detection** — automatically configures based on email domain
- **Two-repo architecture** — generic dotfiles here (public), work-specific in a private companion repo
- **Claude Code configs** — settings, commands, and reference files
- **Shell enhancements** — modern CLI aliases with tool fallbacks
- **Bitwarden integration** — secrets fetched on-demand, never stored in files
- **Conditional deployment** — work-only files excluded on personal machines
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

For work machines, chezmoi automatically clones the private work-dotfiles repo via `.chezmoiexternal.yaml.tmpl` during apply.

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
| `karaktaka/dotfiles` | GitHub | Public | Generic dotfiles + wrapper templates |
| Private companion | GitLab | Private | Work-specific files (plaintext) |

**Data flow:**
1. `chezmoi init` prompts for email, name, and (if work) the companion repo URL
2. `.chezmoiexternal.yaml.tmpl` clones the companion repo (externals apply before other entries)
3. Wrapper templates `cat` files from the companion repo into target locations
4. Mixed-content files use native includes (SSH `Include`, git `[include]`, zsh `source`)

On personal machines: no companion repo, wrapper templates excluded via `.chezmoiignore`, native includes silently ignore missing files.

## Work vs Personal Mode

You're prompted during `chezmoi init` whether this is a work machine:

| Mode | What's Included |
|------|-----------------|
| Work | Full config: cloud tooling, GitLab, Jira integration |
| Personal | Base config: shell aliases, git, Claude basics |

## Directory Structure

```
~/
├── CLAUDE.md                    # Global Claude instructions
├── .claude/
│   ├── settings.json            # Claude settings (work-conditional)
│   ├── commands/                # Custom slash commands
│   ├── get-flair.sh             # Randomised commit/MR flair generator
│   ├── formatter-reference.md   # Linter/formatter commands
│   └── statusline-command.py    # Custom status line script
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

### Bitwarden unlock prompts

The `ensure_bw_session` function handles this automatically. If it fails:
```bash
bw unlock
export BW_SESSION="<session-key>"
```

## License

Personal dotfiles — feel free to use as inspiration for your own setup.
