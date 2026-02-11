# Formatter & Linter Reference

Quick reference for file formatting and linting commands by language/file type.

---

## By File Type

| File Type | Lint/Check | Format |
|-----------|------------|--------|
| **Python** | `ruff check <files>` | `ruff format <files>` |
| **Terraform** | `terraform validate` | `terraform fmt` or `terraform fmt -recursive` |
| **YAML** | `yamllint <files>` | `prettier --write "**/*.yaml"` or `yamlfmt <file>` |
| **JSON** | `prettier --check "**/*.json"` | `prettier --write "**/*.json"` or `jq . <file>` |
| **JavaScript/TypeScript** | `eslint <files>` | `prettier --write <files>` |
| **Go** | `go vet ./...` | `go fmt ./...` or `gofmt -w <file>` |
| **Rust** | `cargo clippy` | `cargo fmt` |
| **Shell/Bash** | `shellcheck <files>` | `shfmt -w <files>` |
| **Markdown** | `markdownlint <files>` | `prettier --write "**/*.md"` |
| **CSS/SCSS** | `stylelint <files>` | `prettier --write "**/*.css"` |
| **HTML** | `htmlhint <files>` | `prettier --write "**/*.html"` |
| **SQL** | `sqlfluff lint <files>` | `sqlfluff fix <files>` |
| **Dockerfile** | `hadolint <file>` | N/A (manual formatting) |
| **TOML** | `taplo check <file>` | `taplo fmt <file>` |

---

## Common Workflows

### Check before commit
```bash
# Python
ruff check . && ruff format --check .

# Terraform
terraform fmt -check -recursive && terraform validate

# Node.js projects
npm run lint && npm run format:check

# Go
go fmt ./... && go vet ./...
```

### Auto-fix everything
```bash
# Python
ruff check --fix . && ruff format .

# JS/TS with prettier + eslint
eslint --fix . && prettier --write .

# Terraform
terraform fmt -recursive
```

---

## Editor Integration Tips

Most of these tools have editor plugins for format-on-save:
- **VS Code**: Install language-specific extensions (Ruff, Prettier, ESLint, etc.)
- **Neovim**: Use null-ls or conform.nvim for formatting
- **JetBrains**: Built-in formatters + external tool configuration

---

## Notes

- When in doubt about a project's formatter, check for config files or `package.json` scripts
- Some projects use pre-commit hooks — run `pre-commit run --all-files` to check everything
