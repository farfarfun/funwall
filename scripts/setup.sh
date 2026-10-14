#!/usr/bin/env bash
set -Eeuo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

usage() {
	cat <<'EOF'
用法:
  scripts/setup.sh {start|stop|restart} {ssr|ssrmu|trojan|v2ray} {dev|prod}
  scripts/setup.sh status [ssr|ssrmu|trojan|v2ray] [dev|prod]

参数顺序为 action、service、environment。未指定参数的 status 会汇总所有服务和环境。
EOF
}

services=(ssr ssrmu trojan v2ray)
environments=(dev prod)
valid_service() {
	local candidate=$1 service
	for service in "${services[@]}"; do
		[[ "$candidate" == "$service" ]] && return 0
	done
	return 1
}

dispatch() {
	local action=$1 service=$2 environment=$3
	# FUNSSR_RUN_DIR 是 funSSR 并入 funwall 前的旧名，保留作兜底以免已部署的 VPS 失效。
	export FUNWALL_RUN_DIR="${FUNWALL_RUN_DIR:-${FUNSSR_RUN_DIR:-${root_dir}/.run}}"
	export FUNSSR_RUN_DIR="$FUNWALL_RUN_DIR"
	mkdir -p "$FUNWALL_RUN_DIR"
	exec bash "$root_dir/scripts/services/${service}.sh" "$action" "$environment"
}

[[ $# -ge 1 && $# -le 3 ]] || { usage >&2; exit 2; }
action=$1

if [[ "$action" == status ]]; then
	if [[ $# -ge 2 ]] && ! valid_service "$2"; then
		echo "不支持的服务: $2" >&2
		exit 2
	fi
	if [[ $# -eq 3 && "$3" != dev && "$3" != prod ]]; then
		echo "环境必须是 dev 或 prod" >&2
		exit 2
	fi
	selected_services=("${2:-${services[@]}}")
	selected_environments=("${3:-${environments[@]}}")
	if [[ ${#selected_services[@]} -eq 1 && ${#selected_environments[@]} -eq 1 ]]; then
		# 单一明确目标：原样透传真实退出码（例如区分"未运行"与"未知"），
		# 不汇总成 0/1，供脚本化调用判断具体状态。
		exec bash "$root_dir/scripts/services/${selected_services[0]}.sh" status "${selected_environments[0]}"
	fi
	result=0
	for service in "${selected_services[@]}"; do
		for environment in "${selected_environments[@]}"; do
			echo "== ${service} (${environment}) =="
			if ! bash "$root_dir/scripts/services/${service}.sh" status "$environment"; then
				result=1
			fi
		done
	done
	exit "$result"
fi

[[ $# -eq 3 ]] || { usage >&2; exit 2; }
case "$action" in start|stop|restart) ;; *) usage >&2; exit 2 ;; esac
valid_service "$2" || { echo "不支持的服务: $2" >&2; exit 2; }
[[ "$3" == dev || "$3" == prod ]] || { echo "环境必须是 dev 或 prod" >&2; exit 2; }
dispatch "$action" "$2" "$3"
