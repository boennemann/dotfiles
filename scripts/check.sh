#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "${repo_root}"

shell_files=(
	.aliases
	.bash_profile
	.bashrc
	.exports
	.functions
	.macos
	.path
	bootstrap.sh
	examples/extra.local
	scripts/check.sh
	scripts/test-bootstrap.sh
)

for file in "${shell_files[@]}"; do
	bash -n "${file}"
done

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck -x -S warning "${shell_files[@]}"
else
	echo "warning: shellcheck is not installed; skipping" >&2
fi

if command -v shfmt >/dev/null 2>&1; then
	shfmt -d "${shell_files[@]}"
else
	echo "warning: shfmt is not installed; skipping" >&2
fi

git diff --check
git config -f .gitconfig --list >/dev/null
ruby -c Brewfile >/dev/null

fence_count="$(grep -c '^```' README.md)"
if ((fence_count % 2 != 0)); then
	echo "ERROR: README.md contains an unmatched Markdown fence." >&2
	exit 1
fi

if command -v starship >/dev/null 2>&1; then
	STARSHIP_CONFIG="${repo_root}/.config/starship.toml" starship timings >/dev/null
fi

if command -v ghostty >/dev/null 2>&1; then
	if ! ghostty_output="$(GHOSTTY_DISABLE_SENTRY=1 ghostty +validate-config --config-file="${repo_root}/.config/ghostty/config" 2>&1)"; then
		printf '%s\n' "${ghostty_output}" >&2
		exit 1
	fi
fi

if command -v vim >/dev/null 2>&1; then
	vim_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-vim.XXXXXX")"
	mkdir -p -- "${vim_home}/.vim/colors"
	ln -s -- "${repo_root}/.vim/colors/solarized.vim" "${vim_home}/.vim/colors/solarized.vim"
	if ! HOME="${vim_home}" vim -Nu "${repo_root}/.vimrc" -n -es '+qall'; then
		rm -rf -- "${vim_home}"
		exit 1
	fi
	rm -rf -- "${vim_home}"
fi

if command -v tmux >/dev/null 2>&1; then
	tmux -L dotfiles-check -f "${repo_root}/.tmux.conf" new-session -d -s dotfiles-check
	tmux -L dotfiles-check kill-server
fi

"${repo_root}/.macos" --dry-run >/dev/null
"${repo_root}/scripts/test-bootstrap.sh"

echo "all checks passed"
