#!/usr/bin/env bash
# scripts/setup.sh 冒烟测试：覆盖参数校验、dev/prod 的生命周期与 status 语义、
# 未安装服务、SysV/systemd 分发和失败退出码。全部使用 mock systemctl/init 脚本，
# 不依赖真实 systemd 单元或 root 权限，可在任意 Linux 开发机上运行。
#
# 用法: bash tests/smoke_test.sh
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
setup_sh="$repo_root/scripts/setup.sh"

workdir=$(mktemp -d)
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT

pass=0
fail=0

assert_eq() {
	local desc=$1 expected=$2 actual=$3
	if [[ "$expected" == "$actual" ]]; then
		echo "ok   - $desc"
		pass=$((pass + 1))
	else
		echo "FAIL - $desc (期望 $expected, 实际 $actual)" >&2
		fail=$((fail + 1))
	fi
}

run_setup() {
	# 捕获退出码而不让 set -e 中断测试脚本本身
	set +e
	"$setup_sh" "$@" >"$workdir/out.log" 2>&1
	local code=$?
	set -e
	echo "$code"
}

# 同上，但带超时。凡是「期望 run 不进入前台」的用例都得用这个：一旦被测逻辑回退成
# 真的前台跑起来，没有上限的调用会把整个测试挂死，回归就表现为超时而不是 FAIL。
run_setup_bounded() {
	set +e
	timeout 10 "$setup_sh" "$@" >"$workdir/out.log" 2>&1
	local code=$?
	set -e
	echo "$code"
}

echo "=== 1. 参数校验 ==="
code=$(run_setup); assert_eq "无参数 -> usage" 2 "$code"
code=$(run_setup start badsvc dev); assert_eq "不支持的服务" 2 "$code"
code=$(run_setup start ssr foo); assert_eq "环境必须是 dev/prod" 2 "$code"
code=$(run_setup bogus ssr dev); assert_eq "不支持的 action" 2 "$code"
code=$(run_setup run ssr dev); assert_eq "run 缺少已安装服务时失败" 1 "$code"
code=$(run_setup start ssr dev extra); assert_eq "多余参数" 2 "$code"

echo "=== 2. status 默认汇总全部服务与环境（均未安装） ==="
export FUNWALL_RUN_DIR="$workdir/.run"
export FUNWALL_INIT_DIR="$workdir/init.d"
mkdir -p "$FUNWALL_INIT_DIR"
code=$(run_setup status)
assert_eq "全部未安装 -> status 非零退出" 1 "$code"
for svc in ssr ssrmu trojan v2ray; do
	for env in dev prod; do
		grep -q "== ${svc} (${env}) ==" "$workdir/out.log" || {
			echo "FAIL - status 输出缺少 ${svc} (${env}) 分组" >&2
			fail=$((fail + 1))
		}
	done
done

echo "=== 3. dev：未安装时 start/stop/restart 报错且非零退出 ==="
code=$(run_setup start ssr dev); assert_eq "dev 未安装 start" 1 "$code"

echo "=== 4. dev：用假 init 脚本模拟已安装，验证 start/stop/restart 透传 ==="
cat >"$FUNWALL_INIT_DIR/ssr" <<'EOF'
#!/usr/bin/env bash
echo "mock-init ssr $1"
case "$1" in
	start|restart) exit 0 ;;
	stop) exit 0 ;;
	status) exit 3 ;;  # systemd 约定：未运行时 status 返回非 0（如 3）
	*) exit 2 ;;
esac
EOF
chmod +x "$FUNWALL_INIT_DIR/ssr"
cp "$FUNWALL_INIT_DIR/ssr" "$FUNWALL_INIT_DIR/ssrmu"
code=$(run_setup start ssr dev); assert_eq "dev 已安装 start" 0 "$code"
grep -q "mock-init ssr start" "$workdir/out.log" || { echo "FAIL - 未透传到 mock init start" >&2; fail=$((fail + 1)); }
code=$(run_setup stop ssr dev); assert_eq "dev 已安装 stop" 0 "$code"
code=$(run_setup restart ssr dev); assert_eq "dev 已安装 restart" 0 "$code"
code=$(run_setup status ssr dev); assert_eq "dev status 透传非零退出码" 3 "$code"

echo "=== 5. 直接调用服务分发器时，缺少已安装服务会失败 ==="
run_code=$(set +e; bash "$repo_root/scripts/services/service.sh" ssr ssr run dev >"$workdir/run.log" 2>&1; echo $?; set -e)
assert_eq "service.sh run 非零退出" 1 "$run_code"

fake_bin="$workdir/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
	cat)
		[[ "$2" == "v2ray" || "$2" == "trojan" ]] && exit 0 || exit 1
		;;
	start|stop|restart)
		echo "mock-systemctl $1 $2"
		exit 0
		;;
	--no-pager)
		echo "mock-systemctl status $*"
		exit 0
		;;
	*) exit 1 ;;
esac
EOF
chmod +x "$fake_bin/systemctl"
cat >"$fake_bin/python" <<'EOF'
#!/usr/bin/env bash
echo "mock-python $*"
EOF
chmod +x "$fake_bin/python"
export PATH="$fake_bin:$PATH"

echo "=== 6. run：以前台命令执行已安装服务 ==="
mkdir -p "$workdir/ssr/shadowsocks" "$workdir/ssrmu"
touch "$workdir/ssr/shadowsocks/server.py" "$workdir/ssr-config.json" "$workdir/ssrmu/server.py"
cat >"$workdir/trojan" <<'EOF'
#!/usr/bin/env bash
echo "mock-trojan $*"
EOF
cat >"$workdir/v2ray" <<'EOF'
#!/usr/bin/env bash
echo "mock-v2ray $*"
EOF
chmod +x "$workdir/trojan" "$workdir/v2ray"
touch "$workdir/trojan.conf" "$workdir/v2ray.json"
export FUNWALL_SSR_DIR="$workdir/ssr"
export FUNWALL_SSR_CONFIG="$workdir/ssr-config.json"
export FUNWALL_SSRMU_DIR="$workdir/ssrmu"
export FUNWALL_TROJAN_BIN="$workdir/trojan"
export FUNWALL_TROJAN_CONFIG="$workdir/trojan.conf"
export FUNWALL_V2RAY_BIN="$workdir/v2ray"
export FUNWALL_V2RAY_CONFIG="$workdir/v2ray.json"
code=$(run_setup run ssr dev); assert_eq "ssr run 前台执行" 0 "$code"
grep -q "mock-python .*server.py -c .*ssr-config.json a" "$workdir/out.log" || { echo "FAIL - ssr run 未执行前台命令" >&2; fail=$((fail + 1)); }
code=$(run_setup run ssrmu prod); assert_eq "ssrmu run 前台执行" 0 "$code"
code=$(run_setup run trojan prod); assert_eq "trojan run 前台执行" 0 "$code"
grep -q "mock-trojan -c .*trojan.conf" "$workdir/out.log" || { echo "FAIL - trojan run 未执行前台命令" >&2; fail=$((fail + 1)); }
code=$(run_setup run v2ray prod); assert_eq "v2ray run 前台执行" 0 "$code"
grep -q "mock-v2ray run -config .*v2ray.json" "$workdir/out.log" || { echo "FAIL - v2ray run 未执行前台命令" >&2; fail=$((fail + 1)); }

echo "=== 7. prod：SysV 服务优先 init，systemd 服务走 systemctl ==="
code=$(run_setup start ssr prod); assert_eq "prod SysV 已安装 start" 0 "$code"
grep -q "mock-init ssr start" "$workdir/out.log" || { echo "FAIL - prod 未透传到 SysV init start" >&2; fail=$((fail + 1)); }
code=$(run_setup stop ssrmu prod); assert_eq "prod SSRmu SysV 已安装 stop" 0 "$code"
code=$(run_setup run ssr prod); assert_eq "prod run 前台执行" 0 "$code"
code=$(run_setup start v2ray prod); assert_eq "prod systemd 已安装 start" 0 "$code"
grep -q "mock-systemctl start v2ray" "$workdir/out.log" || { echo "FAIL - prod 未透传到 systemctl start" >&2; fail=$((fail + 1)); }
code=$(run_setup restart trojan prod); assert_eq "prod Trojan systemd 已安装 restart" 0 "$code"
code=$(run_setup status ssr prod); assert_eq "prod SysV status 透传非零退出码" 3 "$code"
code=$(run_setup status ssrmu prod); assert_eq "prod SSRmu SysV status 透传非零退出码" 3 "$code"
code=$(run_setup status v2ray prod); assert_eq "prod V2Ray systemd status" 0 "$code"
code=$(run_setup status trojan prod); assert_eq "prod Trojan systemd status" 0 "$code"
rm -f "$FUNWALL_INIT_DIR/ssrmu"
code=$(run_setup start ssrmu prod); assert_eq "prod 未安装服务 start 报错" 1 "$code"

echo "=== 8. run 的真前台语义：阻塞、exec 链、信号、退出码、实时输出 ==="
# 前面几节的 mock 命令立刻就退出，只能证明 run 把命令分发对了，证明不了它真的留在
# 前台。这一节换成长驻的假服务，验证 run 不 daemonize、信号直达服务进程、退出码
# 原样透传、日志在运行期间就看得到——也就是 run 和 start 的本质区别。
fg_svc="$workdir/fg-svc"
cat >"$fg_svc" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${FG_SVC_EXIT:-}" ]]; then
	echo "fg-svc exiting ${FG_SVC_EXIT}"
	exit "${FG_SVC_EXIT}"
fi
echo "fg-svc pid=$$ args=$*"
echo "fg-svc stderr" >&2
trap 'echo "fg-svc caught TERM"; exit 143' TERM
trap 'echo "fg-svc caught INT"; exit 130' INT
while :; do sleep 0.2; done
EOF
chmod +x "$fg_svc"
export FUNWALL_TROJAN_BIN="$fg_svc"
export FUNWALL_V2RAY_BIN="$fg_svc"

# 数一下还活着的假服务进程，用来确认前台退出后没留下孤儿。$fg_svc 在本次 mktemp
# 目录下，不会和别的测试或并发运行撞名。
count_fg_procs() {
	local proc cmd total=0
	for proc in /proc/[0-9]*; do
		# 2>/dev/null 必须写在输入重定向之前：进程随时可能在 glob 和读取之间退出，
		# 而「打不开 cmdline」是 shell 自己报的错，重定向按顺序生效才压得住。
		cmd=$(tr '\0' ' ' 2>/dev/null <"$proc/cmdline") || continue
		[[ "$cmd" == *"$fg_svc"* ]] && total=$((total + 1))
	done
	echo "$total"
}

# 终端里真正的前台进程不会继承 SIG_IGN，但 bash 会给后台作业屏蔽 SIGINT，
# 脚本里直接 kill -INT 是打不进去的。env --default-signal 把处置复位，
# 才能如实模拟 Ctrl-C；没有这个选项的机器上只跑 SIGTERM 用例。
defsig=(env)
has_defsig=0
if env --default-signal=INT true 2>/dev/null; then
	defsig=(env --default-signal=INT,TERM)
	has_defsig=1
fi

fg_log="$workdir/fg.log"

# assert_foreground <service> <signal> <期望退出码>
assert_foreground() {
	local svc=$1 signal=$2 expected=$3 waited=0 fg_pid svc_pid code watchdog
	: >"$fg_log"
	# env 直接 execvp，不另开进程，所以 $! 就是最终服务进程的 PID
	"${defsig[@]}" "$setup_sh" run "$svc" prod >"$fg_log" 2>&1 &
	fg_pid=$!
	while ((waited < 100)); do
		grep -q 'fg-svc pid=' "$fg_log" && break
		sleep 0.1
		waited=$((waited + 1))
	done

	# (1) 没有 daemonize：发信号之前进程还活着，没有立即返回
	if kill -0 "$fg_pid" 2>/dev/null; then
		echo "ok   - ${svc} run 阻塞在前台（未 daemonize、未立即返回）"
		pass=$((pass + 1))
	else
		echo "FAIL - ${svc} run 立即返回，不是前台语义" >&2
		fail=$((fail + 1))
	fi

	# (2) exec 链完整：服务自报的 PID 就是 setup.sh 自己的 PID。只要这条成立，
	#     就不可能存在“包装 shell 挨了信号、服务变成孤儿”的情况。
	svc_pid=$(sed -n 's/^fg-svc pid=\([0-9]*\).*/\1/p' "$fg_log" | head -1)
	assert_eq "${svc} run 的服务进程即 setup.sh 自身（exec 链完整）" "$fg_pid" "$svc_pid"

	# (3) 前台语义要求日志直接进 stdout/stderr，而且运行期间就能看到
	if grep -q 'fg-svc stderr' "$fg_log"; then
		echo "ok   - ${svc} run 运行期间就把 stdout/stderr 透给了终端"
		pass=$((pass + 1))
	else
		echo "FAIL - ${svc} run 运行期间没有把 stderr 透给终端" >&2
		fail=$((fail + 1))
	fi

	# (4) 信号直达服务进程，退出码原样透传。
	#     看门狗兜底：万一信号到不了服务（比如有人把 exec 去掉，信号只打到包装
	#     shell 上，而 bash 会等子进程跑完才处理），别把测试挂死在 wait 上；
	#     10s 后强杀，让断言以 FAIL 收场而不是一直卡住。
	(sleep 10 && kill -KILL "$fg_pid" 2>/dev/null) &
	watchdog=$!
	kill -"$signal" "$fg_pid" 2>/dev/null
	set +e
	wait "$fg_pid"
	code=$?
	kill "$watchdog" 2>/dev/null
	wait "$watchdog"
	set -e
	assert_eq "${svc} run 透传服务收到 SIG${signal} 后的退出码" "$expected" "$code"
	if grep -q "fg-svc caught ${signal}" "$fg_log"; then
		echo "ok   - ${svc} run 的 SIG${signal} 送到了服务进程本身"
		pass=$((pass + 1))
	else
		echo "FAIL - ${svc} run 的 SIG${signal} 没有送到服务进程" >&2
		fail=$((fail + 1))
	fi

	# (5) 前台退出后不留孤儿
	assert_eq "${svc} run 退出后没有残留孤儿进程" 0 "$(count_fg_procs)"
}

assert_foreground trojan TERM 143
if ((has_defsig)); then
	assert_foreground v2ray INT 130
else
	echo "skip - 本机 env 不支持 --default-signal，跳过 SIGINT(Ctrl-C) 用例"
fi

# (6) 服务自己退出时退出码也要透传，不能被包装脚本吞成 0/1
export FG_SVC_EXIT=42
code=$(run_setup_bounded run trojan prod); assert_eq "run 透传服务自身的退出码 42" 42 "$code"
unset FG_SVC_EXIT

echo "=== 9. run 不接管已有进程 ==="
# 已经在跑的时候再 run 一份，两份会抢同一个端口，而报出来的错往往跟端口无关。
# 所以 run 必须先明确拒绝，并告诉用户先 stop。
cat >"$FUNWALL_INIT_DIR/trojan" <<'EOF'
#!/usr/bin/env bash
case "$1" in
	status) echo "mock-init trojan 正在运行"; exit 0 ;;
	*) exit 0 ;;
esac
EOF
chmod +x "$FUNWALL_INIT_DIR/trojan"
code=$(run_setup_bounded run trojan prod); assert_eq "已在运行时 run 拒绝接管" 1 "$code"
grep -q "run 不接管已有进程" "$workdir/out.log" || { echo "FAIL - 缺少拒绝接管的提示" >&2; fail=$((fail + 1)); }

# init 报告未运行（上游 doubi 的 init 脚本用 1 表示未运行）时，run 照常前台执行
cat >"$FUNWALL_INIT_DIR/trojan" <<'EOF'
#!/usr/bin/env bash
case "$1" in
	status) echo "mock-init trojan 未运行"; exit 1 ;;
	*) exit 0 ;;
esac
EOF
chmod +x "$FUNWALL_INIT_DIR/trojan"
export FG_SVC_EXIT=0
code=$(run_setup_bounded run trojan prod); assert_eq "init 报告未运行时 run 照常前台执行" 0 "$code"
unset FG_SVC_EXIT
rm -f "$FUNWALL_INIT_DIR/trojan"

echo
echo "=== 汇总: $pass 通过, $fail 失败 ==="
[[ "$fail" -eq 0 ]]
