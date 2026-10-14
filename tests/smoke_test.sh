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

echo "=== 1. 参数校验 ==="
code=$(run_setup); assert_eq "无参数 -> usage" 2 "$code"
code=$(run_setup start badsvc dev); assert_eq "不支持的服务" 2 "$code"
code=$(run_setup start ssr foo); assert_eq "环境必须是 dev/prod" 2 "$code"
code=$(run_setup bogus ssr dev); assert_eq "不支持的 action" 2 "$code"
code=$(run_setup run ssr dev); assert_eq "run 不作为生命周期入口" 2 "$code"
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

echo "=== 5. 直接调用服务分发器时也拒绝 run ==="
run_code=$(set +e; bash "$repo_root/scripts/services/service.sh" ssr ssr run dev >"$workdir/run.log" 2>&1; echo $?; set -e)
assert_eq "service.sh run 非零退出" 2 "$run_code"

echo "=== 6. prod：SysV 服务优先 init，systemd 服务走 systemctl ==="
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
export PATH="$fake_bin:$PATH"

code=$(run_setup start ssr prod); assert_eq "prod SysV 已安装 start" 0 "$code"
grep -q "mock-init ssr start" "$workdir/out.log" || { echo "FAIL - prod 未透传到 SysV init start" >&2; fail=$((fail + 1)); }
code=$(run_setup stop ssrmu prod); assert_eq "prod SSRmu SysV 已安装 stop" 0 "$code"
code=$(run_setup run ssr prod); assert_eq "prod run 被拒绝" 2 "$code"
code=$(run_setup start v2ray prod); assert_eq "prod systemd 已安装 start" 0 "$code"
grep -q "mock-systemctl start v2ray" "$workdir/out.log" || { echo "FAIL - prod 未透传到 systemctl start" >&2; fail=$((fail + 1)); }
code=$(run_setup restart trojan prod); assert_eq "prod Trojan systemd 已安装 restart" 0 "$code"
code=$(run_setup status ssr prod); assert_eq "prod SysV status 透传非零退出码" 3 "$code"
code=$(run_setup status ssrmu prod); assert_eq "prod SSRmu SysV status 透传非零退出码" 3 "$code"
code=$(run_setup status v2ray prod); assert_eq "prod V2Ray systemd status" 0 "$code"
code=$(run_setup status trojan prod); assert_eq "prod Trojan systemd status" 0 "$code"
rm -f "$FUNWALL_INIT_DIR/ssrmu"
code=$(run_setup start ssrmu prod); assert_eq "prod 未安装服务 start 报错" 1 "$code"

echo
echo "=== 汇总: $pass 通过, $fail 失败 ==="
[[ "$fail" -eq 0 ]]
