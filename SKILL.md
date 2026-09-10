---
name: mac-system-toolkit
description: "Mac 系统工具箱：一体化整合桌面控制、浏览器自动化、窗口管理、电源管理、硬件健康检查、VPN代理控制、文件搜索七大能力。分层架构：统一桌面控制（cu plane/axcli/AppleScript）、Chrome内核应用控制（bu/Playwright/CDP/MCP）、窗口管理（Spectacle/AppleScript）、专项功能（电源管理/硬件健康检查/VPN代理控制/文件搜索）。当用户要求操作电脑、打开切换应用、点击界面、关机重启、查豆包状态、查温度、电脑健康检查、风扇转速、VPN开关、代理设置、网络检查、窗口管理、双屏布局、分屏、找文件、搜索文件、文件在哪、哪个文件包含、磁盘空间、为什么磁盘满了等任何 Mac 系统相关操作时使用。仅适用于 macOS。"
compatibility: "仅在 macOS(Darwin) 实测可用；Windows/Linux 未适配。执行前先判平台(uname -s 返回 Darwin)，非 macOS 停止并告知需另行适配、不硬跑；将来补齐 Windows 后仍按平台分流并分别标注验证状态。本机依赖：axcli(cargo)、Node.js Playwright、cu plane、iStats、fd/ripgrep/ncdu。"
---

# Mac System Toolkit — Mac 系统工具箱

## 平台适用（执行前先读）
- 本技能当前**仅在 macOS（Darwin）实测可用**，命令、路径、代理端口与系统原生能力均按 Mac。
- 动手前先判平台：`uname -s` 返回 `Darwin` 才走本技能流程；**Windows/Linux 未适配，遇到就停下告知用户“需先做该平台适配”，不要用想当然的等价命令硬跑**。
- 以后补齐 Windows 后也必须保留“先判平台 → 按平台分流”的结构：mac/Windows 的命令与路径分开写、各自标注是否已验证。

## 架构总览

四层分层控制，按需选用。详细说明见 [README.md](README.md)。

| 层级 | 工具 | 适用 |
|------|------|------|
| 第一层：统一桌面控制 | cu plane / axcli / AppleScript | 原生 App GUI 操作（默认入口） |
| 第二层：Chrome 内核控制 | bu / Playwright / CDP / MCP | Chrome 网页、VS Code、Electron App 内部内容 |
| 第三层：窗口管理 | Spectacle / AppleScript | 窗口移动/resize/双屏布局 |
| 第四层：专项功能 | 脚本+文档 | 电源管理、健康检查、VPN控制、文件搜索 |

## 使用场景决策树

每次操作前按顺序判断：

```
需要操作 Mac 桌面
│
├─ 找文件/搜索内容/磁盘空间分析？ → file-search.md
├─ Chrome/Electron App 内部内容？ → 第二层 [chrome-app-control.md]
├─ 窗口级操作（移动/resize/布局）？ → 第三层 [window-management.md]
├─ 单步操作且已知坐标/选择器？ → axcli 轻量操作 [cu-plane-guide.md §轻量操作]
├─ 系统弹窗单步点击/后台发命令？ → AppleScript [cu-plane-guide.md §AppleScript]
└─ 多步完整任务需观察-行动循环？ → cu plane 重武器 [cu-plane-guide.md]
```

**核心原则**：能简单就不复杂；能元素级就不坐标级；cu plane 是重武器，单步操作不要用大炮打蚊子。

## 系统环境

- **显示器**：2× 1920×1200（左屏 x=0-1920，右屏 x=1920-3840）
- **Dock**：底部自动隐藏，预留 ~90px
- **ClashX 代理**：`http://127.0.0.1:7890`（HTTP），`socks5://127.0.0.1:7890`
- **Node.js**：nvm v24.9.0 at `~/.nvm/versions/node/v24.9.0/bin/node`
- **axcli**：`~/.cargo/bin/axcli`
- **技能目录**：`/Users/wenjiechen/Doubao/skills/mac-system-toolkit`

## 快速参考

### 常用脚本

```bash
SKILL_DIR="/Users/wenjiechen/Doubao/skills/mac-system-toolkit"

# 综合健康检查
bash "$SKILL_DIR/scripts/health_check.sh"

# 仅温度检测
bash "$SKILL_DIR/scripts/check_temp.sh"

# 关机（30秒延迟可取消）
bash "$SKILL_DIR/scripts/power.sh shutdown 30"

# 重启（30秒延迟可取消）
bash "$SKILL_DIR/scripts/power.sh restart 30"
```

### 常用命令

```bash
# 激活 App
osascript -e 'tell application "AppName" to activate'

# iTerm2 后台发命令（不抢焦点）
osascript -e 'tell application "iTerm2" to tell current session of current window to write text "CMD"'

# axcli 点击菜单栏图标（已知坐标）
~/.cargo/bin/axcli mouse click <x> <y>

# axcli 可靠点击策略
~/.cargo/bin/axcli --app "AppName" click 'AXButton >> nth=0' --strategy cg --activate --no-visual-cursor

# 前台 App
osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'

# 终端代理（下载时）
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

# 文件搜索（系统级，即时）
mdfind -name "文件名"
# 文件搜索（已知目录）
fd "文件名" /path/to/dir
# 内容搜索
rg "搜索文本" /path/to/dir
# 磁盘空间分析
ncdu /path/to/dir
```

### 各 App 特殊点

| App | 特殊点 | 默认工具 |
|-----|--------|---------|
| Chrome | 网页内容 AX 不可见 | bu / Playwright / CDP |
| VS Code | Electron，内部 DOM 需 CDP | CDP 直连 |
| iTerm2 | 后台发命令不需激活 | AppleScript write text |
| Doubao | Electron 聊天区 AX 不可见，需截图 | cu plane（多步任务） |
| ClashX | 菜单栏-only，位置固定 | axcli（单步点击） |
| 其他原生 App | 无特殊点 | cu plane（默认） |

## 错误恢复速查

| 错误 | 原因 | 处理 |
|------|------|------|
| `user is operating` | 用户正在操作目标 App | 等 2-3s 重试 |
| `CU_AX_ELEMENT_INVALID` | 元素索引过期 | 重新 get_app_state 取新索引 |
| `CU_AX_APP_NOT_SURFACE` | 菜单栏-only App，cu 看不到 | fallback 到 axcli |
| CDP connection refused | VS Code 未带调试端口启动 | Cmd+Q 后用 `--remote-debugging-port=9222` 重启 |
| brew 卡住 | 残留 brew 锁 | `pkill -9 -f brew; rm -f ~/Library/Caches/Homebrew/downloads/*.incomplete` |
| 终端 DNS 超时 | shell 未设代理 | `export https_proxy=http://127.0.0.1:7890` |
| axcli 默认策略冻结 | `--strategy cg-pid` 有问题 | 用 `--strategy cg --activate --no-visual-cursor` |
| 坐标点击多屏偏移 | 硬编码坐标/坐标系混用 | 改用元素级操作，或动态读元素 position 算中心 |

## 注意事项

- **cu plane 完整规范**：见系统内置 `computer-use-automation-mac` 技能，本技能的 cu-plane-guide 是要点提炼
- **敏感 token**：`scripts/power.sh` 含 Cloudflare webhook token，禁止提交到公开 Git 仓库
- **权限**：axcli/cu plane 需要「辅助功能」和「屏幕录制」权限
- **项目特定流程**：高顿课程项目的做题/下载/视频流程在项目文档中，本技能只放通用方法
