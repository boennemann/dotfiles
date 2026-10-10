# shellcheck shell=bash

# Load environment and shell helpers. Machine-local additions belong in
# ~/.extra.local, which is deliberately not managed by this repository.
for file in "${HOME}"/.{path,exports,aliases,functions} "${HOME}/.extra.local"; do
	if [[ -f "${file}" && -r "${file}" ]]; then
		# shellcheck source=/dev/null
		source "${file}"
	fi
done
unset file

[[ $- == *i* ]] || return 0

shopt -s nocaseglob histappend cdspell
for option in autocd globstar; do
	shopt -s "${option}" 2>/dev/null || true
done
unset option

# Bash completion from Homebrew, with a system fallback.
if command -v brew >/dev/null 2>&1; then
	brew_prefix="$(brew --prefix)"
	completion_script="${brew_prefix}/etc/profile.d/bash_completion.sh"
	if [[ -r "${completion_script}" ]]; then
		export BASH_COMPLETION_COMPAT_DIR="${brew_prefix}/etc/bash_completion.d"
		# shellcheck source=/dev/null
		source "${completion_script}"
	fi
	unset brew_prefix completion_script
elif [[ -r /etc/bash_completion ]]; then
	# shellcheck source=/dev/null
	source /etc/bash_completion
fi

if declare -F _git >/dev/null; then
	complete -o default -o nospace -F _git g
fi

if [[ -r "${HOME}/.ssh/config" ]]; then
	ssh_hosts="$(awk '/^Host / { for (i = 2; i <= NF; i++) if ($i !~ /[?*]/) print $i }' "${HOME}/.ssh/config")"
	complete -o default -o nospace -W "${ssh_hosts}" scp sftp ssh
	unset ssh_hosts
fi

complete -W "NSGlobalDomain" defaults
complete -o nospace -W "Calendar Contacts Dock Finder Ghostty Mail Safari SystemUIServer" killall

command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"

# Emit OSC 7 so terminal emulators can inherit the current working directory.
__osc7_cwd() {
	# shellcheck disable=SC1003
	printf '\e]7;file://%s%s\e\\' "${HOSTNAME:-localhost}" "${PWD}"
}
case ";${PROMPT_COMMAND:-};" in
*';__osc7_cwd;'*) ;;
*) PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND};}__osc7_cwd" ;;
esac
