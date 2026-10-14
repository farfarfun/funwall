#!/usr/bin/env bash
set -Eeuo pipefail

service=$1
unit=$2
action=$3
environment=$4
base_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
run_dir=${FUNWALL_RUN_DIR:-${FUNSSR_RUN_DIR:-"${base_dir}/.run"}}
lock_file="${run_dir}/${service}.lock"

mkdir -p "$run_dir"
if [[ "$action" == start || "$action" == restart || "$action" == run ]]; then
	exec 9>"$lock_file"
	flock -n 9 || { echo "服务操作正在进行: $service" >&2; exit 1; }
fi

installed_unit() {
	command -v systemctl >/dev/null 2>&1 && systemctl cat "$unit" >/dev/null 2>&1
}

init_script() {
	local init_dir="${FUNWALL_INIT_DIR:-${FUNSSR_INIT_DIR:-/etc/init.d}}"
	printf '%s\n' "$init_dir/$unit"
}

installed_init() {
	local init
	init=$(init_script)
	[[ -x "$init" ]] || { echo "服务尚未安装: $init" >&2; return 1; }
	printf '%s\n' "$init"
}

run_unsupported() {
	echo "run 不可用: 该入口无法前台附着已安装服务，请使用 start" >&2
	exit 2
}

case "$environment" in
	prod)
		[[ "$action" != run ]] || run_unsupported
		if init=$(installed_init 2>/dev/null); then
			case "$action" in
				status) exec "$init" status ;;
				start|stop|restart) exec "$init" "$action" ;;
				*) exit 2 ;;
			esac
		fi
		installed_unit || { echo "prod 服务尚未安装: $unit" >&2; exit 1; }
		case "$action" in
			status) exec systemctl --no-pager --plain --full status "$unit" ;;
			start|stop|restart) exec systemctl "$action" "$unit" ;;
			*) exit 2 ;;
		esac
		;;
	dev)
		case "$action" in
			run) run_unsupported ;;
			status) init=$(installed_init); exec "$init" status ;;
			start|stop|restart) init=$(installed_init); exec "$init" "$action" ;;
			*) exit 2 ;;
		esac
		;;
	*) echo "环境必须是 dev 或 prod" >&2; exit 2 ;;
esac
