# 第四层：VPN / 代理控制（环境检测 + 终端代理设置）

> 网络环境检测与代理管理。执行需要网络访问的操作前，先检测网络环境，根据目标资源决定是否需要代理。
> 代理客户端（ClashX/ClashVerge）菜单栏点击、系统 VPN、故障排查见 [proxy-client-control.md](proxy-client-control.md)。

---

## 一、核心原则

> **"什么目标该挂代理、什么必须直连"的分流原则不属本篇**：按 security-baseline 安全基线执行，本篇不复述、不另立政策（避免多处配置）。本篇只管"怎么探端口、怎么设环境变量、怎么操作客户端"。

1. **终端代理按需设置**：只在需要的命令前设置代理环境变量，不全局持久化（除非用户要求）。
2. **操作代理客户端前先确认状态**：通过菜单栏菜单读取当前代理状态和节点（见 proxy-client-control.md）。
3. **端口与客户端不写死（双机不同，关键）**：代理客户端可能是 ClashX Pro（常用混合端口 7890）或 ClashVerge（常用 7897）；下文命令统一写 `127.0.0.1:${PROXY_PORT:-7890}`——先按第二节「端口约定」`export PROXY_PORT=<实测端口>`，没 export 时回退 7890。客户端名称与 bundle id 以本机实际安装为准。

---

## 二、网络环境检测

### 端口约定（先做这步，双机端口不同）

```bash
# 1) 探测本机谁在监听常见混合端口（ClashX 多为 7890、ClashVerge 多为 7897）
for p in 7890 7897 1087 7891; do nc -z -w1 127.0.0.1 $p 2>/dev/null && echo "在用端口: $p"; done
# 或按进程名查（ClashX / ClashVerge / mihomo）
lsof -nP -iTCP -sTCP:LISTEN | grep -iE 'clash|mihomo|verge'

# 2) 本会话固定一次，下文命令自动使用（想持久化就写进 ~/.zshrc）
export PROXY_PORT=7897     # 换成上一步探测到的端口
```

> 下文所有 `127.0.0.1:${PROXY_PORT:-7890}` 含义相同：export 过就用本机端口、没 export 回退 7890，两台机照抄都不会错。唯一例外是 `~/.cargo/config.toml` 这类**静态配置文件，不支持 shell 变量展开**，那里必须填端口字面量（见下文 §三）。

### 快速检测（3秒内出结果）

```bash
# 检测直连（用于"未被墙境外站点"判断；Google 等已知被墙站点跳过本步，直接跑下一条代理检测）
curl -s --connect-timeout 3 -o /dev/null -w "直连Google: code=%{http_code} time=%{time_total}s\n" https://www.google.com 2>&1
# 检测代理是否可用（端口用 $PROXY_PORT，未设则回退 7890）
curl -s --connect-timeout 3 -x http://127.0.0.1:${PROXY_PORT:-7890} -o /dev/null -w "代理Google: code=%{http_code} time=%{time_total}s\n" https://www.google.com 2>&1
```

### 完整检测（含国内/国外对比）

```bash
echo "=== 国内资源（直连）==="
curl -s --connect-timeout 3 -o /dev/null -w "百度: code=%{http_code} time=%{time_total}s\n" https://www.baidu.com 2>&1
echo "=== 国外资源（直连）==="
curl -s --connect-timeout 5 -o /dev/null -w "GitHub直连: code=%{http_code} time=%{time_total}s\n" https://github.com 2>&1
echo "=== 国外资源（代理）==="
curl -s --connect-timeout 5 -x http://127.0.0.1:${PROXY_PORT:-7890} -o /dev/null -w "GitHub代理: code=%{http_code} time=%{time_total}s\n" https://github.com 2>&1
```

### 决策逻辑

| 检测结果 | 决策 |
|---------|------|
| 目标是已知被墙站点（Google/YouTube/X 等，清单以安全基线与各技能实测台账为准） | **跳过直连检测**，直接导代理后测代理连通性；代理不可用转国内渠道 |
| 未被墙境外资源：直连 code=200 且 time<2s | 直连可用，不需要代理 |
| 未被墙境外资源：直连超时或 code=000 | 需要代理 |
| 代理可用但直连也可用（限未被墙资源） | 优先直连（更快、更稳定），大文件下载用代理 |
| 代理不可用 | 检查代理客户端是否运行、端口（第二节探测）是否正确、节点是否有效（见 proxy-client-control.md） |

---

## 三、终端代理设置

### 临时设置（推荐，只影响当前命令）

```bash
# 方式1：命令前缀
https_proxy=http://127.0.0.1:${PROXY_PORT:-7890} http_proxy=http://127.0.0.1:${PROXY_PORT:-7890} brew install tree

# 方式2：export 后执行（当前 shell 会话有效）
export https_proxy=http://127.0.0.1:${PROXY_PORT:-7890} http_proxy=http://127.0.0.1:${PROXY_PORT:-7890} all_proxy=socks5://127.0.0.1:${PROXY_PORT:-7890}
brew install tree && npm install && cargo build

# 取消代理
unset https_proxy http_proxy all_proxy
```

### 常用工具的代理配置

```bash
# git
git config --global http.proxy http://127.0.0.1:${PROXY_PORT:-7890}
git config --global --unset http.proxy   # 取消

# npm
npm config set proxy http://127.0.0.1:${PROXY_PORT:-7890}

# cargo（已配中科大镜像，通常不需要代理；~/.cargo/config.toml 是静态配置不展开变量，须填端口字面量）
# [http]
# proxy = "http://127.0.0.1:7890"

# pip
pip install --proxy http://127.0.0.1:${PROXY_PORT:-7890} package
```

---

## 四、何时需要 VPN/代理的判断清单

> 本表是开发类工具的**实测操作台账**（含国内替代），随实测更新；"什么操作默认要不要代理"的分流原则按 security-baseline，本篇不重复。

执行以下操作前，先检测网络：

| 操作 | 默认需要代理？ | 国内替代 |
|------|--------------|---------|
| Google 搜索 | 是 | 百度/必应国内版 |
| GitHub 访问/克隆 | 通常是 | Gitee 镜像（部分项目） |
| Homebrew 安装 | 下载bottles时是 | 中科大/清华镜像 |
| cargo 依赖 | 索引下载时是 | 中科大镜像（已配置） |
| npm 安装 | 官方源时是 | npmmirror 淘宝镜像 |
| pip 安装 | 官方源时是 | 清华/阿里镜像 |
| Docker 拉取 | 是 | 国内镜像加速器 |
| 国内网站访问 | 否 | — |
| 飞书/微信 API | 否 | — |
| Apple 服务 | 通常否 | — |

---

## 五、系统环境

- **代理端口**：不写死，以本机实测为准（ClashX 多为 7890、ClashVerge 多为 7897），见第二节「端口约定」
- **代理客户端**：ClashX Pro bundle id `com.west2online.ClashXPro`（ClashVerge 另计），菜单栏控制见 proxy-client-control.md
- **axcli 路径**：`~/.cargo/bin/axcli`
- **cargo 镜像**：已配置中科大源（`~/.cargo/config.toml`）
- **终端 DNS**：直连经常超时，建议走代理
