#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap.XXXXXX")"

cleanup() {
	if [[ -n "${test_root:-}" && "${test_root}" == "${TMPDIR:-/tmp}"/dotfiles-bootstrap.* ]]; then
		rm -rf -- "${test_root}"
	fi
}
trap cleanup EXIT

home_one="${test_root}/home-one"
mkdir -p -- "${home_one}"

"${repo_root}/bootstrap.sh" --target "${home_one}" --dry-run >/dev/null
[[ ! -e "${home_one}/.bash_profile" ]]

"${repo_root}/bootstrap.sh" --target "${home_one}" --yes >/dev/null
[[ -L "${home_one}/.bash_profile" ]]
[[ "$(readlink "${home_one}/.bash_profile")" == "${repo_root}/.bash_profile" ]]
[[ -L "${home_one}/.config/ghostty/config" ]]
[[ ! -e "${home_one}/.claude" ]]

idempotent_output="$("${repo_root}/bootstrap.sh" --target "${home_one}" --yes)"
[[ "${idempotent_output}" == "All managed dotfiles are already linked." ]]

home_two="${test_root}/home-two"
mkdir -p -- "${home_two}"
printf 'existing profile\n' >"${home_two}/.bash_profile"
if "${repo_root}/bootstrap.sh" --target "${home_two}" --yes >/dev/null 2>&1; then
	echo "ERROR: Installer accepted a conflict without --backup." >&2
	exit 1
fi
grep -q "existing profile" "${home_two}/.bash_profile"
[[ ! -e "${home_two}/.aliases" ]]

"${repo_root}/bootstrap.sh" --target "${home_two}" --backup --yes >/dev/null
[[ -L "${home_two}/.bash_profile" ]]
backup_profile="$(find "${home_two}/.dotfiles-backup" -type f -name .bash_profile -print -quit)"
[[ -n "${backup_profile}" ]]
grep -q "existing profile" "${backup_profile}"

home_three="${test_root}/home-three"
mkdir -p -- "${home_three}"
printf 'blocking config file\n' >"${home_three}/.config"
if "${repo_root}/bootstrap.sh" --target "${home_three}" --yes >/dev/null 2>&1; then
	echo "ERROR: Installer accepted a parent-path conflict without --backup." >&2
	exit 1
fi
[[ ! -e "${home_three}/.bash_profile" ]]
grep -q "blocking config file" "${home_three}/.config"

"${repo_root}/bootstrap.sh" --target "${home_three}" --backup --yes >/dev/null
[[ -d "${home_three}/.config" ]]
[[ -L "${home_three}/.config/starship.toml" ]]
backup_config="$(find "${home_three}/.dotfiles-backup" -type f -name .config -print -quit)"
[[ -n "${backup_config}" ]]
grep -q "blocking config file" "${backup_config}"

home_four="${test_root}/home-four"
outside_config="${test_root}/outside-config"
mkdir -p -- "${home_four}" "${outside_config}"
printf 'outside sentinel\n' >"${outside_config}/sentinel"
ln -s -- "${outside_config}" "${home_four}/.config"
"${repo_root}/bootstrap.sh" --target "${home_four}" --backup --yes >/dev/null
[[ -d "${home_four}/.config" && ! -L "${home_four}/.config" ]]
[[ -L "${home_four}/.config/bat/config" ]]
grep -q "outside sentinel" "${outside_config}/sentinel"
backup_config_link="$(find "${home_four}/.dotfiles-backup" -type l -name .config -print -quit)"
[[ "$(readlink "${backup_config_link}")" == "${outside_config}" ]]

echo "bootstrap tests passed"
