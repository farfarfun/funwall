# Changelog

## 未发布

### 新增

- 并入 [funSSR](https://github.com/farfarfun/funSSR) 全部内容（该仓库随之归档）：
  - `darkssr/server/` —— 自维护的 ShadowsocksR / Trojan / V2Ray(ws+tls) / BBR 交互式安装管理器；
  - `darkssr/client/config.json` —— 客户端配置样例（敏感字段为占位符）；
  - `scripts/setup.sh` 与 `scripts/services/` —— 统一的 `start`/`stop`/`restart`/`status` 生命周期入口，按 `action → service → environment` 解析参数；
  - `tests/smoke_test.sh` —— 23 项冒烟测试，用 mock `systemctl`/`init.d` 执行，不依赖真实服务或 root；
  - `.github/FUNDING.yml`。
- README 增加「自建服务端脚本（原 funSSR）」与「第三方代码与授权」两节。
- 恢复 `run` 子命令，并实现真正的前台运行语义（容器部署和看实时日志用）。并入时它被整体
  去掉了，理由写的是「无法前台附着已安装服务」——「附着」到一个已经跑着的进程上确实做不到，
  但 `run` 要的不是附着，而是照该服务自己的前台命令在当前终端里跑一份，这是做得到的。
  实现上不解析 systemd 的 `ExecStart`（里面可能带未展开的变量，直接 exec 会静默丢参数），
  而是按服务分别写出前台命令：`ssr`/`ssrmu` 走 `python server.py`（与上游 init 脚本一致，
  只去掉 `nohup` 和 `&`），`trojan`/`v2ray` 直接 exec 已安装的二进制。
- `run` 不接管已有进程：服务已经在运行时直接报错并提示先 `stop`，不会再起第二份去抢同一个
  端口（抢端口报出来的错往往跟端口无关，很难查）。判不出状态时（容器里只装了二进制、
  既无 init 脚本也无 systemd 单元）仍照常前台运行。
- `run` 查找服务二进制和配置的路径可用 `FUNWALL_SSR_DIR`、`FUNWALL_SSR_CONFIG`、
  `FUNWALL_SSRMU_DIR`、`FUNWALL_TROJAN_BIN`、`FUNWALL_TROJAN_CONFIG`、`FUNWALL_V2RAY_BIN`、
  `FUNWALL_V2RAY_CONFIG` 覆盖；对应的 `FUNSSR_` 旧名同样作为兜底被识别。
- 冒烟测试新增「`run` 的真前台语义」与「`run` 不接管已有进程」两节（共 42 项）：用长驻的
  假服务实测 `run` 阻塞在前台、服务 PID 与 `setup.sh` 的 PID 相同（`exec` 链完整）、
  SIGINT/SIGTERM 直达服务并透传退出码、运行期间就有 stdout/stderr 输出、退出后不留孤儿进程。
  只用立刻退出的 mock 是测不出前台语义的——那样把 `exec` 换成 `nohup ... &` 也照样全绿。

### 变更

- 运行时环境变量由 `FUNSSR_RUN_DIR` / `FUNSSR_INIT_DIR` 改名为 `FUNWALL_RUN_DIR` / `FUNWALL_INIT_DIR`；
  旧名仍作为兜底被识别，已部署的机器无需改动。
- 远程安装命令的 raw 地址由 `farfarfun/funSSR` 改为 `farfarfun/funwall`。
- 许可证声明细化：`darkssr/server/v2ray_ws_tls.sh` 源自上游未声明许可证的 `ladderbackup`，
  明确排除在本仓库 MIT 授权之外。

## 1.1.7

### 新增

- 增加 `py.typed` 类型标记及包导入与版本测试。

### 修复

- 修复构建产物未声明许可证和类型标记的问题。

### 变更

- 使用 Hatchling 构建并通过 uv 管理开发依赖；本地 `uv.lock` 不提交。
- 补充准确的项目元数据、安装说明、最小示例及组织介绍。

### 废弃

（无）

## 1.1.6

### 修复

- 补上此前发布到 PyPI 的空包问题：新增最小可导入的 `funwall/__init__.py`，
  pip 安装后可正常 `import funwall` 并读取版本号。

## 1.1.5

### 新增

- 机场推荐表新增“中国国际机场”条目。

## 1.1.4

### 变更

- 精简统一 README 表格格式，补充 v2rayA 客户端支持说明。
- 更新项目依赖声明与版本号。

## 1.1.2

### 新增

- README 补充 sing-box 服务端一键安装说明。

## 1.1.1

### 新增

- 首个正式发布版本：补全 `pyproject.toml` 项目配置并完善 README 索引内容。

以上历史版本（1.1.1-1.1.6）系补记，依据 git 提交历史与 PyPI 发布记录整理；
期间未发生破坏性变更，无需迁移说明。

---

## 附：funSSR 并入前的变更历史

以下为 [funSSR](https://github.com/farfarfun/funSSR) 归档前的变更记录，随内容一并并入本仓库留档。
funSSR 从未发布过版本，故全部条目归于「未发布」。其中提到的 `FUNSSR_INIT_DIR` 在并入后
已改名为 `FUNWALL_INIT_DIR`（旧名仍兜底）。

### 新增

- 增加 `scripts/setup.sh`，统一服务的 `start`、`stop`、`restart`、`status` 入口，并明确 `dev`/`prod` 环境。
- 增加 `.run/` 运行时目录约定。
- `scripts/setup.sh` 按 `action → service → environment` 的统一顺序解析参数；`scripts/services/<service>.sh` 拆分为各服务独立的分发脚本，`scripts/services/service.sh` 负责公共的 dev/prod 分发逻辑。
- `run` 不再作为生命周期入口；无法前台附着服务时会明确拒绝。
- `status` 不带参数时默认遍历全部服务与 `dev`/`prod` 环境；生产服务优先走已安装的 SysV init 脚本，否则使用 systemd。
- 新增 `tests/smoke_test.sh`：覆盖参数校验、`status` 默认汇总/单目标透传退出码、dev 环境 start/stop/restart、prod 环境 SysV/systemd 已安装与未安装分支，全部用 mock `systemctl`/`init.d` 脚本执行。
- `scripts/services/service.sh` 新增 `FUNSSR_INIT_DIR` 环境变量，可覆盖 dev 环境查找 `/etc/init.d/<unit>` 的目录（默认不变，供测试注入 mock）。

### 修复

- 直接执行 `ssr.sh` 或 `ssrmu.sh` 时，运行时 PID 和日志目录现在同样由脚本位置解析到仓库根 `.run/`；统一入口和直接调用不再使用不同目录。
- 空密码改为安全随机值，避免使用公开的固定默认密码。
- 不支持的系统和失败路径返回非零退出码。
- `ssr.sh`/`ssrmu.sh` 启停改为专属 PID 文件 + `kill -0`/`/proc/<pid>/cmdline` 校验进程身份，不再用模糊的 `ps -ef | grep` 判断重复启动。
- `Update_Shell` 更新流程中下载、读取新版本号、`chmod` 任一步失败都返回非零退出码，不再误报“脚本已更新”。
- 移除 `darkssr/client/config.json` 中硬编码的共享认证 ID 和示例邮箱，改为需要替换的占位符。
- `scripts/setup.sh status` 不带参数时环境默认值从单个字符串 `“dev prod”` 改为真正的数组展开，修复此前恒定失败（`环境必须是 dev 或 prod`）、无法汇总全部环境状态的问题。
- `scripts/services/service.sh` 不再将后台启动或交互安装菜单伪装为 `run`；该操作会返回非零退出码。
- `scripts/setup.sh status <service> <env>`（单一明确目标）此前会把底层真实退出码统一折叠成 0/1，丢失具体状态信息；现在单目标直接透传真实退出码，仅在聚合多个目标时才归一为 0/1。
- README「感谢」区块不再笼统声称全部移植代码都按本仓库 MIT 发布：`ladderbackup` 来源的 `v2ray_ws_tls.sh` 上游许可证未声明，明确排除在本仓库 MIT 授权之外。

### 变更

- README 补充全部遗留交互式安装器的用途、支持系统、调用方式及系统修改风险，并明确它们不属于 `scripts/setup.sh` 的服务生命周期入口。
- 客户端安装包改由 GitHub Releases 或上游项目发布，仓库不再保存二进制文件。
- 安装文档中的端口范围统一为 `1-65535`。
- 仓库 description 更新为描述当前实际内容（服务端安装/管理脚本，不再提及已移除的客户端安装包）。

### 废弃

- 废弃从仓库直接下载客户端安装包的链接。
