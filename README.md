
# funwall

funwall 是科学上网资源索引，汇总代理服务端安装脚本、跨平台客户端与机场信息。
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

---

## 关于 farfarfun

[farfarfun](https://github.com/farfarfun) 是一个专注于实用工具库的开源组织，
涵盖云存储、数据处理、AI、多媒体与开发工具链等方向。

- 🏠 组织主页：<https://github.com/farfarfun>
- 📦 PyPI：<https://pypi.org/user/niuliangtao/>
- 📧 联系：farfarfun@qq.com

本项目基于 [MIT](LICENSE) 协议开源。
