# Stephan's dotfiles

Personal, reproducible configuration for an Apple Silicon development Mac running macOS 26 or newer. Bash 5, cmux/Ghostty, Cursor, Git, Homebrew, and a small Vim fallback are the primary supported tools.

These settings are intentionally personal. Review the repository and the dry-run output before installing it on another machine.

## Install

Install Apple's command-line tools and [Homebrew](https://brew.sh/), then clone the repository:

```bash
git clone https://github.com/boennemann/dotfiles.git ~/Projects/boennemann/dotfiles
cd ~/Projects/boennemann/dotfiles
```

The Brewfile is a workstation snapshot, not just a list of shell dependencies. It includes development tools and GUI applications. The `lazyworktree` cask comes from an external tap, so review that tap before trusting it:

```bash
brew trust --cask chmouel/lazyworktree/lazyworktree
```

Cursor, cmux, and 1Password were originally installed outside Homebrew. On an existing machine, adopt their application bundles once before running the bundle:

```bash
brew install --cask --adopt cursor cmux 1password
brew bundle install --file=Brewfile
```

Preview the managed home-directory links. Existing files are never overwritten by default:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh --backup
```

`--backup` moves conflicts to `~/.dotfiles-backup/<timestamp>/` before linking them. On a fresh home with no conflicts, `./bootstrap.sh` is sufficient. Start a new shell afterward.

## Local configuration

Machine-specific or private shell setup belongs in `~/.extra.local`. It is sourced when present but is neither tracked nor installed. Start from the guarded example if useful:

```bash
cp examples/extra.local ~/.extra.local
```

Git email addresses are selected by repository location:

- `~/Projects/boennemann/` uses the personal identity.
- `~/Projects/prosperity/` uses the work identity.

Git commits are signed through the 1Password desktop app.

## macOS defaults

The defaults script changes only keyboard, Finder, Dock, screenshot, and immediate-lock preferences. It does not alter Gatekeeper, quarantine, disk verification, hostnames, Spotlight, or application-specific preferences.

```bash
./.macos --dry-run
./.macos
```

Screenshots are stored in `~/Documents` as PNG files without shadows.

## Maintenance

Run the repository checks before committing:

```bash
./scripts/check.sh
```

Update installed packages explicitly:

```bash
brew update
brew upgrade
brew bundle check --file=Brewfile --no-upgrade
```

Re-running `bootstrap.sh` is idempotent. To uninstall, inspect managed links with `./bootstrap.sh --dry-run` and unlink only targets that point into this checkout. Restore any displaced files from the timestamped backup directory.

The repository is moving from `master` to `main`. After committing this cleanup and authenticating `gh`, complete the migration in this order:

```bash
git branch -m main
git push -u origin main
gh repo edit boennemann/dotfiles --default-branch main
git push origin --delete master
```

## Attribution

This repository began as a fork of [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles) and retains substantial historical work. The original MIT copyright and license remain in [LICENSE-MIT.txt](LICENSE-MIT.txt).
