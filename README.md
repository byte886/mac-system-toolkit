# Mac System Toolkit — Mac 系统工具箱

## 一、这是什么

一个面向 macOS 的系统级工具箱，整合了原生 App GUI 操作、Chrome 内核应用控制、窗口管理、电源管理、硬件健康检查、VPN/代理控制、文件搜索七大能力。

**核心设计原则**：分层控制，按需选用。默认用最轻量的工具完成任务，只有在轻量工具搞不定时才升级到更重的工具。

---

## 二、架构分层

```
┌─────────────────────────────────────────────────────────────┐
│                    第四层：专项功能                            │
│  电源管理  │  健康检查  │  VPN/代理控制  │  文件搜索          │
├─────────────────────────────────────────────────────────────┤
│                    第三层：窗口管理                            │
│  Spectacle 快速布局  │  AppleScript 精准定位  │  窗口控件点击  │
├─────────────────────────────────────────────────────────────┤
│                  第二层：Chrome 内核应用控制                    │
│  bu plane  │  Playwright CLI  │  CDP 直连  │  DevTools MCP  │
│  （Chrome 网页内容 / VS Code 内部UI / 其他 Electron App）      │
├─────────────────────────────────────────────────────────────┤
│                  第一层：统一桌面控制（默认）                    │
│  computer use（cu plane）  │  axcli 轻量操作  │  AppleScript  │
│  （所有原生 App 的 GUI 操作：Doubao / Finder / 系统设置 / 弹窗） │
└─────────────────────────────────────────────────────────────┘
```

### 各层定位

| 层级 | 工具 | 定位 | 典型场景 |
|------|------|------|---------|
| **第一层：统一桌面控制** | cu plane / axcli / AppleScript | 原生 App GUI 操作的默认入口 | 操作 Doubao、Finder、系统设置、系统弹窗 |
| **第二层：Chrome 内核控制** | bu / Playwright / CDP / MCP | AX 树看不到网页 DOM 时的专用层 | Chrome 网页内容、VS Code 内部 UI、Electron App |
| **第三层：窗口管理** | Spectacle / AppleScript | 窗口级操作（移动/resize/布局） | 双屏布局、窗口对齐、快速分屏 |
| **第四层：专项功能** | 脚本 + 文档 | 特定领域的完整工作流 | 关机重启、硬件体检、VPN 开关、文件搜索 |

---

## 三、使用场景决策树

每次操作前，按以下顺序判断用哪层工具：

```
需要操作 Mac 桌面
│
├─ 1. 是 Chrome/Electron App 的内部内容？
│   （网页内容、VS Code 编辑器、Electron 应用内部）
│   ├─ 是 → 第二层：Chrome 内核应用控制
│   │   ├─ 通用网页操作 → bu plane（最自动化）
│   │   ├─ 脚本化/批量操作 → Playwright CLI
│   │   ├─ VS Code / 非标准 Electron → CDP 直连
│   │   └─ 调试/性能分析 → DevTools MCP
│   └─ 否 → 继续
│
├─ 2. 是窗口级操作？
│   （移动窗口、resize、全屏、分屏布局、双屏排列）
│   ├─ 是 → 第三层：窗口管理
│   │   ├─ 快速布局（左半屏/右半屏/全屏）→ Spectacle 快捷键
│   │   └─ 精确定位（任意坐标/大小）→ AppleScript set bounds
│   └─ 否 → 继续
│
├─ 3. 是单步简单操作，且已知元素位置/坐标/选择器？
│   （点击菜单栏图标、按全局快捷键、触发一个已知按钮）
│   ├─ 是 → 第一层（轻量）：axcli
│   │   例：axcli mouse click 1192 12（点 ClashX 菜单栏图标）
│   │   例：axcli --app "Alfred" press "Control+Space"
│   └─ 否 → 继续
│
├─ 4. 是系统弹窗/原生控件的单步点击，或后台发命令？
│   （Chrome 授权弹窗"允许"、保存对话框、iTerm2 后台执行命令）
│   ├─ 是 → 第一层（轻量）：AppleScript
│   │   例：AppleScript AXPress 点"允许"按钮
│   │   例：AppleScript write text 向 iTerm2 后台发命令
│   └─ 否 → 继续
│
└─ 5. 是多步完整 GUI 任务，需要观察-行动-确认循环？
    （打开系统设置→找网络→切换代理→确认；Doubao 切换会话→发消息→等回复）
    └─ 是 → 第一层（重武器）：computer use（cu plane）
```

**关键原则**：
- **能简单就不复杂**：单步操作用 axcli/AppleScript，多步任务才用 cu plane
- **能元素级就不坐标级**：优先用 AX 树元素定位，坐标点击仅作为兜底
- **cu plane 是重武器**：不要用大炮打蚊子
- **axcli 是轻量工具**：适合已知坐标/选择器的快速操作

---

## 四、目录结构与文件说明

```
mac-system-toolkit/
│
├── README.md                          # 本文件：技能说明、架构、决策树、目录说明
├── SKILL.md                           # 技能主入口：触发后首先加载，含功能总览和快速参考
│
├── references/                        # 按需加载的模块文档（仅在需要时读取）
│   │
│   ├── cu-plane-guide.md              # 第一层：统一桌面控制
│   │                                    内容：cu plane 操作规范、什么时候用 cu plane、
│   │                                          axcli 轻量操作（fallback）、AppleScript 系统弹窗
│   │                                    来源：系统技能 computer-use-automation-mac 提炼 + 项目经验
│   │
│   ├── chrome-app-control.md          # 第二层：Chrome 内核应用控制
│   │                                    内容：技术选型（bu/Playwright/CDP/MCP）、Chrome 网页控制、
│   │                                          VS Code 内部 UI（CDP）、其他 Electron App、连接恢复
│   │                                    来源：项目 playwright-cli-guide 提炼 + 新增 CDP/bu/MCP 选型
│   │
│   ├── window-management.md           # 第三层：窗口管理
│   │                                    内容：Spectacle 快捷键映射、双屏布局模板、
│   │                                          AppleScript 精准定位、窗口管理决策流程
│   │                                    来源：原 mac-desktop-control 拆分
│   │
│   ├── power-management.md            # 第四层：电源管理
│   │                                    内容：豆包会话忙碌检测、关机/重启（延迟可取消）、
│   │                                          取消机制、安全注意事项
│   │                                    来源：mac-power-control 迁移
│   │
│   ├── health-check.md                # 第四层：硬件健康检查
│   │                                    内容：CPU温度/负载、内存压力、硬盘空间/SMART、
│   │                                          网络连通性、风扇状态、温度范围速查、健康度评分、降温建议
│   │                                    来源：mac-hardware-temp 扩展
│   │
│   ├── vpn-control.md                 # 第四层：VPN/代理控制
│   │                                    内容：网络环境检测与决策逻辑、ClashX Pro 菜单栏交互、
│   │                                          代理环境变量设置/取消、各工具代理配置（git/npm/cargo/pip）、
│   │                                          增强模式(TUN)、系统 VPN 配置、常见问题排查、判断清单
│   │                                    来源：原 mac-desktop-control 零散内容 + proxy-manager 整合
│   │
│   └── file-search.md                 # 第四层：文件搜索
│                                        内容：工具矩阵（mdfind/fd/rg/ncdu）、系统级搜索、
│                                              已知目录搜索、内容搜索、磁盘空间分析、决策流程、最佳实践
│                                        来源：mac-file-search 迁移
│
└── scripts/                           # 可执行脚本
    ├── power.sh                        # 关机/重启（Cloudflare webhook，默认30秒延迟可取消）
    ├── check_temp.sh                   # 温度检测（iStats 自动安装 + CPU/GPU/风扇温度）
    └── health_check.sh                 # 综合健康检查（一键体检，支持 --full / --json）
```

### 文件清单表

| 文件 | 用途 | 行数 | 何时读取 |
|------|------|------|---------|
| `README.md` | 技能说明与架构 | 218行 | 想了解技能全貌时 |
| `SKILL.md` | 主入口，触发后首先加载 | 126行 | 每次触发技能时 |
| `references/cu-plane-guide.md` | 统一桌面控制规范 | 222行 | 操作原生 App GUI 时 |
| `references/chrome-app-control.md` | Chrome 内核应用控制 | 316行 | 操作 Chrome/VSCode/Electron 内部内容时 |
| `references/window-management.md` | 窗口管理 | 139行 | 需要移动/resize/布局窗口时 |
| `references/power-management.md` | 电源管理 | 125行 | 关机/重启/查豆包状态时 |
| `references/health-check.md` | 硬件健康检查 | 212行 | 查温度/硬件状态/电脑健康时 |
| `references/vpn-control.md` | VPN/代理控制 | 355行 | 开关 VPN/设置代理/查网络时 |
| `references/file-search.md` | 文件搜索 | 183行 | 找文件/搜索内容/磁盘空间分析时 |
| `scripts/power.sh` | 关机重启脚本 | 24行 | 执行关机/重启时 |
| `scripts/check_temp.sh` | 温度检测脚本 | 83行 | 检测温度时 |
| `scripts/health_check.sh` | 综合体检脚本 | 276行 | 一键健康检查时 |

---

## 五、快速上手

### 常用场景

```bash
SKILL_DIR="/Users/wenjiechen/Doubao/skills/mac-system-toolkit"

# 1. 综合健康检查（温度+CPU+内存+硬盘+网络+风扇）
bash "$SKILL_DIR/scripts/health_check.sh"

# 2. 仅温度检测
bash "$SKILL_DIR/scripts/check_temp.sh"

# 3. 关机（30秒延迟，可取消）
bash "$SKILL_DIR/scripts/power.sh shutdown 30"

# 4. 重启（30秒延迟，可取消）
bash "$SKILL_DIR/scripts/power.sh restart 30"
```

### 触发词

说以下关键词会自动触发本技能：
- 操作电脑、打开/切换应用、点击界面
- 关机、重启、豆包忙吗、检查豆包状态
- 查温度、电脑健康检查、硬件状态、风扇转速
- VPN 开关、代理设置、网络检查、ClashX
- 找文件、搜索文件、文件在哪、哪个文件包含、磁盘空间、为什么磁盘满了
- 窗口管理、双屏布局、分屏

---

## 六、常见问题

**Q：cu plane 和 axcli 有什么区别？**
A：底层都是 macOS Accessibility API。cu plane 是重武器，适合多步完整任务（观察-行动-确认循环）；axcli 是轻量命令行工具，适合已知坐标/选择器的单步快速操作。能简单就不复杂。

**Q：为什么 Chrome 不用 cu plane？**
A：cu plane 只能看到浏览器窗口的 AX 树，网页内容区域是一个 AXWebArea，内部 DOM 元素不可见。Chrome 内核控制（bu/Playwright/CDP）能读取网页完整 DOM，操作更精准。

**Q：为什么 VS Code 用 CDP？**
A：VS Code 是 Electron App，内部 UI 用 Web 技术写的。CDP 能读取 VS Code 内部完整 DOM（按钮、编辑器、侧边栏），cu plane 只能看到窗口外壳。

**Q：关机为什么要延迟 30 秒？**
A：给用户取消的机会。关机/重启是不可逆操作，延迟执行可以防止误触。说"取消"即可停止。

**Q：健康检查包含哪些项目？**
A：CPU 温度/负载、内存压力、硬盘空间/SMART、网络连通性（局域网/互联网/DNS/代理）、风扇转速、系统运行时间。

---

## 七、维护说明

- 本技能采用分层架构，新增能力时先判断属于哪一层，放入对应模块
- 新增 App 控制方法时，优先考虑是否能用现有层覆盖，不需要为每个 App 单独建模块
- 脚本修改后需实际运行测试
- 敏感信息（如 power.sh 中的 token）禁止提交到公开 Git 仓库
