#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
target_home="${HOME}"
dry_run=false
backup_conflicts=false
assume_yes=false

usage() {
	cat <<'EOF'
Usage: ./bootstrap.sh [--dry-run] [--backup] [--yes] [--target HOME]

Create symlinks for the dotfiles managed by this repository.

  --dry-run      Print the planned changes without modifying anything
  --backup       Move conflicting targets to a timestamped backup first
  --yes          Do not prompt before applying changes
  --target HOME  Install into another home directory (primarily for testing)
EOF
}

while (($#)); do
	case "$1" in
	--dry-run) dry_run=true ;;
	--backup) backup_conflicts=true ;;
	--yes) assume_yes=true ;;
	--target)
		shift
		if (($# == 0)); then
			echo "ERROR: --target requires a directory." >&2
			exit 2
		fi
		target_home="$1"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "ERROR: Unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	esac
	shift
done

if [[ -z "${target_home}" || "${target_home}" == "/" ]]; then
	echo "ERROR: Refusing to use an unsafe target home: ${target_home:-<empty>}" >&2
	exit 2
fi
if [[ ! -d "${target_home}" ]]; then
	echo "ERROR: Target home does not exist: ${target_home}" >&2
	exit 2
fi
target_home="$(cd -- "${target_home}" && pwd -P)"

managed_files=(
	.aliases
	.bash_profile
	.bashrc
	.curlrc
	.editorconfig
	.exports
	.functions
	.gitattributes
	.gitconfig
	.gitconfig-personal
	.gitconfig-prosperity
	.hushlogin
	.inputrc
	.path
	.tmux.conf
	.vimrc
	.wgetrc
	.config/bat/config
	.config/ghostty/config
	.config/git/ignore
	.config/starship.toml
	.vim/colors/solarized.vim
)

conflicts=()
changes=()

record_conflict() {
	local candidate="$1"
	local existing
	for existing in "${conflicts[@]}"; do
		[[ "${existing}" == "${candidate}" ]] && return 0
	done
	conflicts+=("${candidate}")
}

for relative_path in "${managed_files[@]}"; do
	source_path="${repo_root}/${relative_path}"
	target_path="${target_home}/${relative_path}"
	if [[ ! -f "${source_path}" ]]; then
		echo "ERROR: Managed source is missing: ${source_path}" >&2
		exit 1
	fi
	if [[ -L "${target_path}" && "$(readlink "${target_path}")" == "${source_path}" ]]; then
		continue
	fi
	changes+=("${relative_path}")
	if [[ -e "${target_path}" || -L "${target_path}" ]]; then
		record_conflict "${relative_path}"
	fi

	parent_path="$(dirname -- "${target_path}")"
	while [[ "${parent_path}" != "${target_home}" && "${parent_path}" != "/" ]]; do
		if [[ -L "${parent_path}" ]]; then
			record_conflict "${parent_path#"${target_home}/"}"
			break
		elif [[ -e "${parent_path}" ]]; then
			[[ -d "${parent_path}" ]] || record_conflict "${parent_path#"${target_home}/"}"
			break
		fi
		parent_path="$(dirname -- "${parent_path}")"
	done
done

if ((${#changes[@]} == 0)); then
	echo "All managed dotfiles are already linked."
	exit 0
fi

echo "Target home: ${target_home}"
for relative_path in "${changes[@]}"; do
	if [[ -e "${target_home}/${relative_path}" || -L "${target_home}/${relative_path}" ]]; then
		if [[ "${backup_conflicts}" == true ]]; then
			printf '  backup + link  %s\n' "${relative_path}"
		else
			printf '  conflict       %s\n' "${relative_path}"
		fi
	else
		printf '  link           %s\n' "${relative_path}"
	fi
done
for relative_path in "${conflicts[@]}"; do
	if [[ ! " ${changes[*]} " == *" ${relative_path} "* ]]; then
		if [[ "${backup_conflicts}" == true ]]; then
			printf '  backup parent  %s\n' "${relative_path}"
		else
			printf '  blocked parent %s\n' "${relative_path}"
		fi
	fi
done

if ((${#conflicts[@]} > 0)) && [[ "${backup_conflicts}" == false ]]; then
	echo "ERROR: Conflicts found. Re-run with --backup to preserve and replace them." >&2
	exit 1
fi
if [[ "${dry_run}" == true ]]; then
	echo "Dry run complete; no files were changed."
	exit 0
fi
if [[ "${assume_yes}" == false ]]; then
	if [[ ! -t 0 ]]; then
		echo "ERROR: Non-interactive installation requires --yes." >&2
		exit 2
	fi
	read -r -p "Apply these changes? [y/N] " reply
	if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
		echo "Cancelled."
		exit 0
	fi
fi

backup_root=""
if ((${#conflicts[@]} > 0)); then
	backup_root="${target_home}/.dotfiles-backup/$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi
created_links=()
backed_up_targets=()
backup_paths=()
created_dirs=()

ensure_target_parent() {
	local target_path="$1"
	local parent_path cursor existing
	local missing_dirs=()
	parent_path="$(dirname -- "${target_path}")"
	cursor="${parent_path}"
	while [[ "${cursor}" != "${target_home}" && ! -e "${cursor}" && ! -L "${cursor}" ]]; do
		missing_dirs+=("${cursor}")
		cursor="$(dirname -- "${cursor}")"
	done
	mkdir -p -- "${parent_path}"
	for cursor in "${missing_dirs[@]}"; do
		for existing in "${created_dirs[@]}"; do
			[[ "${existing}" == "${cursor}" ]] && continue 2
		done
		created_dirs+=("${cursor}")
	done
}

rollback() {
	local status=$?
	local index pass
	trap - ERR INT TERM
	for ((index = ${#created_links[@]} - 1; index >= 0; index--)); do
		[[ -L "${created_links[index]}" ]] && unlink "${created_links[index]}"
	done
	for ((pass = 0; pass < ${#created_dirs[@]}; pass++)); do
		for ((index = 0; index < ${#created_dirs[@]}; index++)); do
			rmdir -- "${created_dirs[index]}" 2>/dev/null || true
		done
	done
	for ((index = ${#backed_up_targets[@]} - 1; index >= 0; index--)); do
		mkdir -p -- "$(dirname -- "${backed_up_targets[index]}")"
		mv -- "${backup_paths[index]}" "${backed_up_targets[index]}"
	done
	if [[ -n "${backup_root}" && "${backup_root}" == "${target_home}/.dotfiles-backup/"* ]]; then
		rm -rf -- "${backup_root}"
		rmdir -- "${target_home}/.dotfiles-backup" 2>/dev/null || true
	fi
	echo "ERROR: Installation failed; completed changes were rolled back." >&2
	exit "${status}"
}
trap rollback ERR INT TERM

for relative_path in "${conflicts[@]}"; do
	target_path="${target_home}/${relative_path}"
	backup_path="${backup_root}/${relative_path}"
	mkdir -p -- "$(dirname -- "${backup_path}")"
	mv -- "${target_path}" "${backup_path}"
	backed_up_targets+=("${target_path}")
	backup_paths+=("${backup_path}")
done

for relative_path in "${changes[@]}"; do
	source_path="${repo_root}/${relative_path}"
	target_path="${target_home}/${relative_path}"
	ensure_target_parent "${target_path}"
	ln -s -- "${source_path}" "${target_path}"
	created_links+=("${target_path}")
done

trap - ERR INT TERM
echo "Installed ${#changes[@]} managed dotfile link(s)."
if [[ -n "${backup_root}" ]]; then
	echo "Backups: ${backup_root}"
fi
echo "Start a new shell to load the updated configuration."
if [[ -f "${target_home}/.extra" && ! -e "${target_home}/.extra.local" ]]; then
	echo "NOTE: Legacy ~/.extra is no longer sourced; migrate needed settings to ~/.extra.local." >&2
fi
