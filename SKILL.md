---
name: mac-system-toolkit
description: "Mac 系统工具箱：桌面/GUI 自动化、Chrome 内核应用控制、窗口管理、电源与硬件健康、VPN 与代理控制、文件搜索，以及 Git submodule 多仓库群维护。当用户要操作 Mac、打开/切换/点击应用、关机重启、查温度或电脑健康、VPN 开关与代理设置、窗口分屏双屏、找文件或查磁盘，或提到 git submodule、子模块、多仓库批量管理、gita 时使用。仅 macOS。"
compatibility: "仅 macOS(Darwin) 实测；执行前先 `uname -s` 判平台，非 macOS 停步告知不硬跑。依赖 axcli(cargo)、Node Playwright、cu plane、iStats、fd/ripgrep/ncdu。"
---

# Mac System Toolkit — Mac 系统工具箱

> 一句话：把"操作 Mac 系统 + 维护技能仓库群"这件事，按四层控制与一份 Git 规范收齐；具体怎么做全部下沉 references，本文件只做路由与红线。

## 平台适用（执行前先读）
- 当前**仅 macOS（Darwin）实测可用**。动手前 `uname -s` 返回 `Darwin` 才继续；**Windows/Linux 未适配，遇到就停下告知"需先做平台适配"，不要用想当然的等价命令硬跑**。
- 将来补齐 Windows 后仍保留"先判平台 → 按平台分流"结构，命令与路径分开写、分别标注验证状态。

## 何时用 / 反触发
- **用**：操作 Mac 桌面（开/切/点 App、关机重启、查温度健康、风扇）；Chrome/Electron 内部网页内容；窗口移动/分屏/双屏布局；VPN 开关、代理设置、网络不通；找文件、磁盘空间；维护 `~/Doubao/skills` 这套 git submodule 仓库群（子模块增删升级、指针漂移、多仓批量、gita 总览）。
- **反触发**：纯网页取数已有专用抓取技能、纯文本任务无需本技能；别用 cu plane 做单步轻量操作（大炮打蚊子）。

## 四层架构（按这个选层）

| 层 | 工具 | 适用 |
|------|------|------|
| 一 统一桌面控制 | cu plane / axcli / AppleScript | 原生 App GUI 操作（默认入口） |
| 二 Chrome 内核控制 | bu / Playwright / Puppeteer / CDP | Chrome 网页、VS Code、Electron 内部内容 |
| 三 窗口管理 | Spectacle / AppleScript | 窗口移动/resize/双屏布局 |
| 四 专项功能 | 脚本+文档 | 电源、健康、VPN代理、文件搜索、Git 规范 |

**核心原则**：能简单就不复杂；能元素级就不坐标级；cu plane 是重武器，单步操作用 axcli/AppleScript。

## 按需加载索引（要做 X → 读这篇）

| 你要做 | 读 |
|------|------|
| 多步桌面 GUI 任务、cu plane/axcli/AppleScript 怎么选 | [references/cu-plane-guide.md](references/cu-plane-guide.md) |
| Chrome/Electron 内部：bu、Playwright CLI、选型 | [references/chrome-control-overview.md](references/chrome-control-overview.md) |
| CDP 直连、Puppeteer 复用日常 Chrome 登录态、VS Code/Electron | [references/chrome-cdp-puppeteer.md](references/chrome-cdp-puppeteer.md) |
| Chrome 调试、连接失败恢复、Gemini 按钮 | [references/chrome-control-ops.md](references/chrome-control-ops.md) |
| 窗口移动/分屏/双屏布局、坐标 | [references/window-management.md](references/window-management.md) |
| 找文件/内容/磁盘空间 | [references/file-search.md](references/file-search.md) |
| 电源管理（关机/重启/睡眠） | [references/power-management.md](references/power-management.md) |
| 硬件健康、温度、风扇 | [references/health-check.md](references/health-check.md) |
| VPN/代理：环境检测、终端代理设置、是否走代理判断 | [references/vpn-control.md](references/vpn-control.md) |
| 代理客户端菜单栏控制、系统 VPN、网络故障排查 | [references/proxy-client-control.md](references/proxy-client-control.md) |
| 密码/token/密钥加密存取 | [references/secret-encryption.md](references/secret-encryption.md) |
| git submodule 规范（克隆、增删升级、指针漂移、新机器） | [references/git-submodule-workflow.md](references/git-submodule-workflow.md) |
| gita 多仓一屏总览与批量遥控 | [references/gita-multi-repo.md](references/gita-multi-repo.md) |

## 硬红线（当场可见，不靠跳转）

- **权限**：axcli / cu plane 需要「辅助功能」和「屏幕录制」权限。
- **坐标先实测**：显示器分辨率/排列因机而异，涉及坐标前先 `system_profiler SPDisplaysDataType`，勿照抄他机坐标；Dock 底部自动隐藏预留 ~90px。
- **代理端口不写死**：ClashX 多 7890、ClashVerge 多 7897；先按 vpn-control.md 探测并 `export PROXY_PORT=...`，命令统一 `127.0.0.1:${PROXY_PORT:-7890}`。
- **凭证唯一权威源**：密码/token/密钥一律用全局命令 `secrets` 加密存取、`audit-secrets.sh` 巡检，明文不进 git/日志；主密码只从 `ENC_PASS` 或交互输入，**不硬编码、不猜测，用户没给就问**（详见 secret-encryption.md）。
- **Git 先子后父**：改技能仓库群 = 子仓一次提交 + 父仓一次指针提交，先子后父。
- **路径可移植**：示例一律 `~`/`$HOME`/`os.homedir()`，不写死 `/Users/<用户名>`。
- **接管别关窗**：操作用户已开的 Chrome 收尾用 `disconnect()`/`detach`，不要 `close()`/`kill`。

## 常用命令速记

```bash
SKILL_DIR="$HOME/Doubao/skills/mac-system-toolkit"
bash "$SKILL_DIR/scripts/health_check.sh"                 # 综合健康检查
bash "$SKILL_DIR/scripts/power.sh shutdown 30"            # 关机/重启（30s 可取消，restart 同理）
bash "$SKILL_DIR/scripts/setup-git-submodule-global.sh"   # 新机器 git submodule 全局默认项（幂等）
bash "$SKILL_DIR/scripts/audit-secrets.sh" ~/Doubao       # 多仓明文密钥巡检
secrets get <name>                                        # 全局取凭证（详见 secret-encryption.md）

# 代理
export https_proxy=http://127.0.0.1:${PROXY_PORT:-7890} http_proxy=http://127.0.0.1:${PROXY_PORT:-7890}

# 文件
mdfind -name "文件名"; fd "文件名" /path; rg "文本" /path; ncdu /path
```

## 与其他技能边界
- cu plane 完整规范在系统内置 `computer-use-automation-mac`；本技能 cu-plane-guide 只是要点提炼。
- 凭证规则/泄漏应急按 security-baseline；双机台账按 dual-machine-manager；本技能只提供动作（`secrets`、`audit-secrets.sh`、代理开关）。
- 项目特定流程（做题/下载/视频等）归项目文档，本技能只放通用方法。
