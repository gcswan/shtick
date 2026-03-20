# Project: shtick

Create a Git repo called `shtick` — a lightweight framework for sharing useful shell functions and aliases across a small dev team on macOS. The name is a play on `sh` + shtick (your bag of tricks — each function is someone's little productivity bit).

## Design principles

- **Zero friction to use:** one install command, then functions just work in every new shell
- **Zero friction to contribute:** drop a `.sh` file with the right header, push, teammates `git pull`
- **Individually selectable:** users pick which functions to enable, not all-or-nothing
- **Self-documenting:** a built-in `shtick` command lists available and enabled functions with descriptions

## File structure

```
shtick/
├── README.md
├── install.sh           # one-time setup
├── loader.sh            # sourced by .zshrc, loads enabled functions
├── functions/            # one file per function/alias
│   ├── packclip.sh
│   └── packsize.sh
└── .gitignore
```

## Function file convention

Every `.sh` file in `functions/` MUST start with this comment header:

```bash
# @name: packclip
# @description: Package a directory into a .tar.gz and copy it to the macOS clipboard
# @usage: packclip <directory>
```

The header is parsed by the loader and the `shtick` discovery command. Files missing a valid header are skipped with a warning.

## install.sh

A one-time interactive installer that:

1. Detects its own location dynamically (no hardcoded clone path)
2. Scans `functions/` and presents each function with its `@name` and `@description`
3. Lets the user select which functions to enable (multi-select, with an "all" option)
4. Stores selections in a local config file (e.g. `~/.config/shtick/enabled.conf` — one function name per line)
5. Adds a `source <path>/loader.sh` line to `~/.zshrc` if not already present
6. Supports re-running to change selections (detects existing config, shows current state)

Also supports non-interactive usage:

```bash
bash install.sh --enable packclip,packsize
bash install.sh --enable-all
bash install.sh --list
```

## loader.sh

Sourced by `.zshrc` on every shell startup. Must be fast.

1. Resolves its own directory dynamically via `${BASH_SOURCE[0]:-$0}`
2. Reads the enabled functions list from `~/.config/shtick/enabled.conf`
3. Sources only the enabled `.sh` files from `functions/`
4. Defines the `shtick` discovery command

## shtick discovery command

A shell function called `shtick` that supports:

- `shtick` or `shtick list` — list all available functions with descriptions, marking which are enabled
- `shtick enable <name>` — enable a function (add to config, source it immediately)
- `shtick disable <name>` — disable a function (remove from config, note it stays loaded until next shell)
- `shtick help <name>` — show the full header (name, description, usage) for a specific function
- `shtick update` — shortcut for `git -C <shtick_dir> pull`
- `shtick reload` — re-source the loader to pick up changes without restarting the shell

## Seed functions

Include these two starter functions:

### packclip

Package a directory into a timestamped `.tar.gz` in `/tmp` and copy it to the macOS clipboard.

```bash
packclip() {
  local dir="${1:?Usage: packclip <directory>}"
  local name=$(basename "$(realpath "$dir")")
  local tmp="/tmp/${name}-$(date +%s).tar.gz"
  tar czf "$tmp" -C "$dir" --exclude='.git' --exclude='lazy-lock.json' . \
    && osascript -e "set the clipboard to (POSIX file \"$tmp\")" \
    && echo "Copied $tmp to clipboard"
}
alias pc='packclip'
```

### packsize

Estimate compressed size, uncompressed text size, and token count for a directory.

```bash
packsize() {
  local dir="${1:-.}"
  echo "Compressed: $(tar czf - -C "$dir" --exclude='.git' --exclude='lazy-lock.json' . | wc -c | awk '{printf "%.1fKB", $1/1024}')"
  echo "Uncompressed text: $(find "$dir" -not -path '*/.git/*' -not -name 'lazy-lock.json' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.1fKB", $1/1024}')"
  echo "Est. tokens: $(find "$dir" -not -path '*/.git/*' -not -name 'lazy-lock.json' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.0fk", $1/4/1000}')"
}
alias pz='packsize'
```

## Constraints

- macOS only (zsh is the target shell, but keep bash 3.2 compatible where possible since macOS ships it)
- Loader must be fast — no network calls, no subshells where avoidable
- No dependencies beyond coreutils and macOS built-ins
- Config lives in `~/.config/shtick/`, not in the repo (repo stays clean for git)
- `.gitignore` should exclude `.env`, `.DS_Store`, and any local state

## README.md

Write a clean README covering:

- What this is (one paragraph, lean into the name — "your bag of sh tricks")
- Quick start (clone, install, done)
- How to use (`shtick` command reference)
- How to contribute (file convention, header format, push and tell people to `git pull`)
- Example of adding a new function
