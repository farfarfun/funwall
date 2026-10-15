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

require_file() {
	local path=$1 description=$2
	[[ -f "$path" ]] || { echo "run 不可用: 未找到已安装的${description}: $path" >&2; exit 1; }
}

# 只在能明确判定“正在运行”时返回 0。判不出来一律按未运行处理：容器里常常只装了
# 服务二进制，既没有 init 脚本也没有 systemd 单元，那种场景下 run 必须照跑。
service_running() {
	local init
	if init=$(installed_init 2>/dev/null); then
		# 上游 doubi 的 init 脚本用 0 表示运行中、1 表示未运行，systemd 的
		# status 同样用 0 表示活跃，所以这里只认 0。
		if "$init" status >/dev/null 2>&1; then
			return 0
		fi
		return 1
	fi
	if installed_unit && systemctl is-active --quiet "$unit"; then
		return 0
	fi
	return 1
}

# run 与 start 的分工：run 只在当前终端里跑一份，不接管已有进程。少了这道检查，
# 前台这份会和后台那份抢同一个端口，而报出来的错往往跟端口无关，很难查。
reject_takeover() {
	service_running || return 0
	echo "run 不接管已有进程: ${service} 已经在运行。" >&2
	echo "要前台运行，请先停掉它: scripts/setup.sh stop ${service} ${environment}" >&2
	exit 1
}

# run 不是“附着”到已经跑着的服务上——那确实做不到——而是照该服务自己的前台命令在
# 当前终端里跑一份。所以这里不解析 systemd 的 ExecStart（里面可能带未展开的变量，
# 直接 exec 会静默丢参数），而是按服务分别写出已安装服务的前台命令。
#
# 全部分支都以 exec 收尾：setup.sh、services/<service>.sh、service.sh 和最终的
# 服务进程始终是同一个 PID，因此信号、退出码、stdout/stderr 都直达服务本身，
# 不会出现“包装 shell 收到 Ctrl-C 而服务变成孤儿”的情况。
run_foreground() {
	local ssr_dir ssr_config binary config
	reject_takeover
	case "$service" in
	ssr)
		ssr_dir=${FUNWALL_SSR_DIR:-${FUNSSR_SSR_DIR:-/usr/local/shadowsocksr}}
		if [[ -n ${FUNWALL_SSR_CONFIG:-${FUNSSR_SSR_CONFIG:-}} ]]; then
			ssr_config=${FUNWALL_SSR_CONFIG:-$FUNSSR_SSR_CONFIG}
		elif [[ -f "${ssr_dir}/user-config.json" ]]; then
			ssr_config="${ssr_dir}/user-config.json"
		else
			ssr_config=/etc/shadowsocksr/user-config.json
		fi
		require_file "${ssr_dir}/shadowsocks/server.py" "ShadowsocksR 服务"
		require_file "$ssr_config" "ShadowsocksR 配置"
		command -v python >/dev/null 2>&1 || { echo "run 不可用: 未找到 python" >&2; exit 1; }
		cd "${ssr_dir}/shadowsocks"
		# 末尾的 a 跟上游 init 脚本保持一致（见 doubi 的 service/ssr_debian），
		# 只是去掉了它的 nohup 和 &。
		exec python "${ssr_dir}/shadowsocks/server.py" -c "$ssr_config" a
		;;
	ssrmu)
		ssr_dir=${FUNWALL_SSRMU_DIR:-${FUNSSR_SSRMU_DIR:-/usr/local/shadowsocksr}}
		require_file "${ssr_dir}/server.py" "ShadowsocksR MuJSON 服务"
		command -v python >/dev/null 2>&1 || { echo "run 不可用: 未找到 python" >&2; exit 1; }
		cd "$ssr_dir"
		exec python "${ssr_dir}/server.py" a
		;;
	trojan)
		binary=${FUNWALL_TROJAN_BIN:-${FUNSSR_TROJAN_BIN:-/usr/src/trojan/trojan}}
		config=${FUNWALL_TROJAN_CONFIG:-${FUNSSR_TROJAN_CONFIG:-/usr/src/trojan/server.conf}}
		require_file "$binary" "Trojan 服务"
		require_file "$config" "Trojan 配置"
		[[ -x "$binary" ]] || { echo "run 不可用: Trojan 服务不可执行: $binary" >&2; exit 1; }
		exec "$binary" -c "$config"
		;;
	v2ray)
		binary=${FUNWALL_V2RAY_BIN:-${FUNSSR_V2RAY_BIN:-/usr/local/bin/v2ray}}
		config=${FUNWALL_V2RAY_CONFIG:-${FUNSSR_V2RAY_CONFIG:-/usr/local/etc/v2ray/config.json}}
		require_file "$binary" "V2Ray 服务"
		require_file "$config" "V2Ray 配置"
		[[ -x "$binary" ]] || { echo "run 不可用: V2Ray 服务不可执行: $binary" >&2; exit 1; }
		exec "$binary" run -config "$config"
		;;
	*) echo "不支持的服务: $service" >&2; exit 2 ;;
	esac
}

case "$environment" in
	prod)
		[[ "$action" != run ]] || run_foreground
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
			run) run_foreground ;;
			status) init=$(installed_init); exec "$init" status ;;
			start|stop|restart) init=$(installed_init); exec "$init" "$action" ;;
			*) exit 2 ;;
		esac
		;;
	*) echo "环境必须是 dev 或 prod" >&2; exit 2 ;;
esac
