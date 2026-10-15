
# funwall

funwall 是科学上网资源索引，汇总代理服务端安装脚本、跨平台客户端与机场信息，
并维护自建服务端脚本与统一的服务生命周期入口。
Python 包仅提供版本信息，方便从 PyPI 跟踪索引版本。

## 安装

```bash
pip install funwall
```

## 最小示例

```python
import funwall

print(funwall.__version__)
```

## 服务端推荐

下列项目是 233boy 维护的第三方脚本，适用于 Linux 服务器，安装和管理服务通常需要 root 权限。
安装命令会联网下载并执行远程代码；请先在代码仓库中审阅脚本，核对文档中的系统要求，并尽量固定到已审阅的提交版本后再执行。

| 工具 | 安装与使用文档 | 代码仓库 |
| :--- | :--- | :--- |
| V2Ray | [V2Ray 一键安装脚本](https://233boy.com/v2ray/v2ray-script/) | [233boy/v2ray](https://github.com/233boy/v2ray) |
| sing-box | [sing-box 一键安装脚本](https://233boy.com/sing-box/sing-box-script/) | [233boy/sing-box](https://github.com/233boy/sing-box) |
| Xray | [Xray 一键安装脚本](https://233boy.com/xray/xray-script/) | [233boy/Xray](https://github.com/233boy/Xray) |

## 自建服务端脚本

`darkssr/server/` 下是本仓库自己维护的一批历史遗留交互式安装/管理器。
请只在隔离的 VPS 上以 root 运行，并先审阅脚本；它们会安装软件、修改系统配置和服务单元。

| 入口 | 用途 | 支持系统 | 调用方式 |
| --- | --- | --- | --- |
| `ssr.sh` | ShadowsocksR 单用户服务的安装和管理 | CentOS 6+、Debian 6+、Ubuntu 14+ | `bash darkssr/server/ssr.sh` |
| `ssrmu.sh` | ShadowsocksR mudbjson 多用户服务的安装和管理 | CentOS 6+、Debian 6+、Ubuntu 14+ | `bash darkssr/server/ssrmu.sh` |
| `tcp.sh` | BBR/加速内核安装与管理 | CentOS 6/7、Debian 8/9、Ubuntu 16+ | `bash darkssr/server/tcp.sh` |
| `trojan_centos7.sh` | Trojan 服务安装 | CentOS 7 | `bash darkssr/server/trojan_centos7.sh` |
| `v2ray_ws_tls.sh` | V2Ray WebSocket/TLS 服务安装 | CentOS 7 | `bash darkssr/server/v2ray_ws_tls.sh` |

这些安装器的依赖、配置输出和卸载选项由各自的交互菜单显示。它们包含历史第三方代码，
不保证适配现代发行版；生产使用前应在目标系统上验证，并保留安装输出中的配置和凭据。
端口必须在 `1-65535` 范围内，建议使用未占用的高位端口（例如 `10001`）；密码留空时脚本会安全随机生成，
不要使用公开示例密码。

远程安装 ShadowsocksR 多用户版：

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/farfarfun/funwall/master/darkssr/server/ssrmu.sh && chmod +x ssrmu.sh && bash ssrmu.sh
```

客户端安装包不再随仓库分发，请从上游项目的正式发布页下载并校验发布者提供的校验值
（见下方「客户端推荐」，以及 [ShadowsocksR Android](https://github.com/shadowsocksrr/shadowsocksr-android/releases)、
[ShadowsocksX-NG](https://github.com/shadowsocks/ShadowsocksX-NG/releases)、
[ShadowsocksR Windows](https://github.com/shadowsocksrr/shadowsocksr-csharp/releases)）。

### 运行服务

统一入口按 `action service environment` 指定环境：

```bash
scripts/setup.sh start ssrmu dev     # 启动已安装的开发 init 服务
scripts/setup.sh start ssrmu prod    # 启动已安装的生产服务（SysV 或 systemd）
scripts/setup.sh run ssrmu prod      # 以前台方式运行已安装服务（容器部署、看实时日志）
scripts/setup.sh status ssrmu prod   # 单一目标：原样返回底层真实退出码
scripts/setup.sh status              # 非交互汇总全部服务和环境，退出码归一为 0/1
```

`run` 是 `start` 的前台版本。它不去解析 systemd 的 `ExecStart`（里面可能带未展开的变量，
直接 exec 会静默丢参数），而是按服务分别 `exec` 已安装服务自己的前台命令。从 `setup.sh`
到 `services/<service>.sh`、`service.sh`，再到最终的服务进程，全程都是 `exec`，始终是
同一个 PID，因此：

- 进程阻塞在前台，既不 daemonize，也不提前返回；
- `Ctrl-C`（SIGINT）和 SIGTERM 直达服务本身，不会出现「包装 shell 挨了信号、服务却变成孤儿」；
- 服务的退出码原样透传，不会被折叠成 0/1；
- 日志直接走 stdout/stderr，运行期间就看得到，而不是只写进日志文件。

`run` 不接管已有进程：服务已经在运行时会直接报错并提示先 `stop`。否则前台这份会和后台
那份抢同一个端口，而抢端口报出来的错往往跟端口无关，很难查。缺少服务二进制或配置时会
明确报错；生产环境不会下载或临时安装软件。

`start`、`stop`、`restart` 在生产环境会优先使用已安装的 `/etc/init.d/<service>`；没有 SysV
脚本时才使用 systemd 单元。

服务日志和其他运行时文件放在仓库 `.run/` 目录；可通过 `FUNWALL_RUN_DIR` 指定独立目录；
`/etc/init.d` 的查找路径可通过 `FUNWALL_INIT_DIR` 覆盖（供测试用 mock 注入）。
`run` 查找服务二进制和配置的路径同样可以覆盖：`FUNWALL_SSR_DIR`、`FUNWALL_SSR_CONFIG`、
`FUNWALL_SSRMU_DIR`、`FUNWALL_TROJAN_BIN`、`FUNWALL_TROJAN_CONFIG`、`FUNWALL_V2RAY_BIN`、
`FUNWALL_V2RAY_CONFIG`。
以上变量把前缀换成 `FUNSSR_` 的同名形式也会被识别，优先级低于 `FUNWALL_` 前缀。

### 脚本测试

```bash
bash tests/smoke_test.sh
```

冒烟测试覆盖参数校验、`run` 前台命令分发、`status` 默认汇总与单目标透传退出码、
dev 环境 start/stop/restart、prod 环境的 SysV/systemd 已安装与未安装分支；全部通过 mock 的
`systemctl`/`init.d` 脚本执行，不依赖真实服务或 root 权限。

其中「`run` 的真前台语义」一节用一个长驻的假服务实测上面那四条保证——阻塞在前台、
服务 PID 与 `setup.sh` 的 PID 相同、SIGINT/SIGTERM 直达并透传退出码、运行期间就有输出、
退出后不留孤儿进程——再加上「不接管已有进程」。`Ctrl-C` 用例依赖
`env --default-signal`（GNU coreutils ≥ 8.31）来复位信号处置，因为 bash 会给后台作业屏蔽
SIGINT；没有这个选项的机器上该用例会自动跳过，SIGTERM 用例照跑。

## 客户端推荐

| 客户端 | Windows | Linux | MAC | Android | IOS |
| :--- | :---: | :---: | :---: | :---: | :--:| 
| [Flclash(推荐)](https://github.com/chen08209/FlClash)|支持  | 支持 | 支持 | 支持 | 支持 |
| [v2rayA](https://v2raya.org) | 支持  | 支持 | 支持 | 支持 | 支持 |
| [v2ray](https://github.com/bwgvps/v2ray-tutorial) | 支持  | - | 支持 | 支持 | 支持 |
| [NekoBox](https://matsuridayo.github.io/) | [支持](https://github.com/MatsuriDayo/nekoray) | [支持](https://github.com/MatsuriDayo/nekoray) | - | [支持](https://github.com/MatsuriDayo/NekoBoxForAndroid) | - |
https://github.com/nelvko/clash-for-linux-install


## 机场推荐

| 条目 | 官网或来源 | 测评 | 特色 |
| :--- | :--- | :--- | :--- |
| 汇总机场1 | [来源](https://9.234456.xyz/abc.html) | - | - |
| 汇总机场2 | [来源](https://github.com/DiningFactory/panda-vpn-pro) | - | - |
| 汇总机场3 | [来源](https://www.ermao.net/posts/vpn/#flybit) | - | - |
| 汇总机场4 | [来源](https://jichangtuijian.com/ssr-v2ray%E4%B8%93%E7%BA%BF%E6%9C%BA%E5%9C%BA%E6%8E%A8%E8%8D%90.html#%E6%9C%BA%E5%9C%BA%E4%BC%98%E6%83%A0) | - | - |
| 光速机场 | [官网](https://gsgs.nxxbbf.com/#/register?code=jM8I7LU2) | [测评](https://duangks.com/archives/208/) | 12 元年付：120 GB/月 |
| 性价比机场 | [官网](https://xn--6nq44r2uh9rhj7f.net/#/plan) | - | - |
| 良心云 | [官网](https://xn--9kqz23b19z.com/#/register?code=2ijKyMLp) | [测评](https://duangks.com/archives/204/) | 2 元月付：100 GB/月，21 元：1 TB/永久 |
| 中国国际机场 | [官网](https://hi.hanamaki.dev/public) | - | - |
| matcha | [官网](https://matcha.su/#/dashboard) | - | - |

## 开发

需要 Python 3.10 或更高版本以及 [uv](https://docs.astral.sh/uv/)。

```bash
uv sync
uv run pytest
uv run ruff check .
uv run ruff format --check .
```

## 第三方代码与授权

本仓库 `darkssr/` 下的安装/管理脚本移植自以下第三方项目，本项目保留上游版权声明。其中 `doubi` 明确采用
MIT License，移植并修改自它的代码（`ssr.sh`、`ssrmu.sh`）按本仓库 LICENSE 发布；`ladderbackup` 当前上游仓库
未提供 LICENSE 文件，许可证状态为未声明，其移植代码（`v2ray_ws_tls.sh`）**不**纳入本仓库 MIT 授权，
继续沿用上游未声明许可证的状态，使用者应自行核实并承担相应风险：

- [ToyoDAdoubi/doubi](https://github.com/ToyoDAdoubi/doubi)（MIT License，原始版权归 ToyoDAdoubi）
- [luyiming1016/ladderbackup](https://github.com/luyiming1016/ladderbackup)（许可证未声明，原始来源归 luyiming1016）

---

## 关于 farfarfun

[farfarfun](https://github.com/farfarfun) 是一个专注于实用工具库的开源组织，
涵盖云存储、数据处理、AI、多媒体与开发工具链等方向。

- 🏠 组织主页：<https://github.com/farfarfun>
- 📦 PyPI：<https://pypi.org/user/niuliangtao/>
- 📧 联系：farfarfun@qq.com

本项目基于 [MIT](LICENSE) 协议开源；`darkssr/server/v2ray_ws_tls.sh` 例外，见上文
[第三方代码与授权](#第三方代码与授权)。
