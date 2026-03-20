# shtick

A mixed bag of shell tricks. Each function is a small
productivity hack — a *shtick* — packaged as a sourceable
shell file. No dependency managers, no config DSLs, no magic.
Just `git pull` and `shtick enable`.

---

## Quick start

```bash
git clone <repo-url> ~/shtick
cd ~/shtick
bash install.sh
```

The installer does two things:

1. Adds a `source` line to your `~/.zshrc` so the loader
   runs on every new shell.
2. Writes your initial function selections to
   `~/.config/shtick/enabled.conf`.

You only need to run `install.sh` once per machine.

---

## Day-to-day usage

After install, use the `shtick` command to manage functions:

```bash
shtick list              # list all functions ([*] = enabled)
shtick enable <name>     # enable and source immediately
shtick disable <name>    # disable (takes effect next shell)
shtick help <name>       # show the header for a function
shtick update            # git pull the repo
shtick reload            # re-source the loader
```

`shtick enable` activates a function in your current shell
*and* saves it to config — no restart needed. To pick up new
functions after a `shtick update`, just enable them.

---

## How it works

```
~/.zshrc
  └─ sources loader.sh
       └─ reads ~/.config/shtick/enabled.conf
            └─ sources each enabled function from functions/
```

`loader.sh` reads `enabled.conf` line by line. Each line is a
function name (e.g. `packclip`). If `functions/<name>.sh`
exists, it gets sourced into your shell.

`install.sh` is just the one-time bootstrap that patches
`~/.zshrc` and writes the initial `enabled.conf`. After that,
`shtick enable/disable` manages `enabled.conf` directly.

---

## install.sh flags

For scripted or non-interactive setups:

```bash
bash install.sh --list                   # list available
bash install.sh --enable packclip        # enable one
bash install.sh --enable packclip,killport  # enable several
bash install.sh --enable-all             # enable everything
```

---

## Adding a new function

1. Create a file in `functions/` with the required header:

```bash
# @name: mkcd
# @description: Create a directory and cd into it
# @usage: mkcd <directory>

mkcd() {
  mkdir -p "${1:?Usage: mkcd <directory>}" && cd "$1"
}
alias mc='mkcd'
```

2. Push. On each machine:

```bash
shtick update
shtick enable mkcd
```

Files missing a `@name` header are skipped with a warning.
