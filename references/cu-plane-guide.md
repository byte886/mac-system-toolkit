# 第一层：统一桌面控制

> 本层包含三种工具：cu plane（重武器，多步任务）、axcli（轻量，单步快速操作）、AppleScript（系统弹窗/后台命令）。
> 完整 cu plane 规范见系统内置 `computer-use-automation-mac` 技能，本文是要点提炼 + 使用场景划分。

---

## 一、使用场景划分

### 什么时候用 cu plane（重武器）

cu plane 是 `mac_computer_use_tool(plane="cu")`，每个 cell 是独立 Python 进程，内置观察-行动循环。

**适用场景**：
- **多步完整 GUI 任务**：需要"先看界面在哪，再决定点什么"的任务
- 需要动态定位元素（不知道按钮具体位置，通过 AX 树查找）
- 需要读回操作结果（操作后确认界面状态变化）
- 需要截图/视觉确认
- 复杂表单填写（多个输入框、下拉选择、复选框）

**典型例子**：
- 打开系统设置 → 找到网络 → 切换代理 → 确认生效
- Doubao 桌面端：切换会话 → 点击输入框 → 输入消息 → 发送 → 确认回复
- Finder：打开文件夹 → 选中文件 → 右键 → 选择操作 → 确认对话框

### 什么时候不用 cu plane（用更轻的工具）

| 场景 | 用什么 | 理由 |
|------|--------|------|
| 已知坐标的单步点击（如菜单栏图标） | axcli `mouse click x y` | 命令行直接执行，无进程启动开销 |
| 已知选择器的单步按钮点击 | axcli `click '选择器'` | 轻量快速 |
| 按全局快捷键（Cmd+N、Ctrl+Space） | axcli `press "快捷键"` | 单步操作，不需要观察循环 |
| 系统弹窗单步点击（如"允许"按钮） | AppleScript `AXPress` | 元素级操作最可靠，且轻量 |
| iTerm2 后台发命令（不抢焦点） | AppleScript `write text` | AppleScript 独有能力，不需激活窗口 |
| 窗口精准定位（任意坐标/大小） | AppleScript `set bounds` | 窗口级操作，比 cu 点窗口控件更精准 |
| 快速窗口布局（左半屏/右半屏） | Spectacle 快捷键 | 单键触发，最快 |

**核心原则**：能简单就不复杂。单步操作用 axcli/AppleScript，多步任务才用 cu plane。不要用大炮打蚊子。

---

## 二、cu plane 核心规范

### 基本用法

```python
# 在 mac_computer_use_tool(plane="cu") 中
import seed_computer_use_ax as cu
```

### 核心不变量（必须遵守）

1. **只有 `get_app_state()` 读 AX 树**，动作函数不刷新树
2. **元素索引只用最新观察**，跨 cell、跨 App 切换、任何 UI 变化后必须重新观察
3. **索引是树行首的数字**，不是位置序号；缩进区分父子关系
4. **转换后先观察再行动**：打开菜单/弹窗/切换 tab 后，先 `get_app_state()` 再操作
5. **`get_app_state()` 后不再做 App 绑定动作**，它通常是 cell 最后一个调用

### 工作循环

| 阶段 | 动作 |
|------|------|
| COLD | 已知 Bundle ID 直接 `get_app_state()`；未知用 `list_apps()` 解析 |
| READY | 用最新树的索引执行动作 |
| TRANSITION | 执行转换 → 可选等待 → `get_app_state()` 结束 cell |
| SWITCH | 切换 App 后重新观察该 App |

### 11 个函数速查

| 函数 | 用途 |
|------|------|
| `cu.list_apps()` | 列出已安装 App |
| `cu.get_app_state(app_id, *, window_id, screenshot, pid)` | 激活/启动 App 并读 AX 树 |
| `cu.click(app_id, element_index, *, x, y)` | 点击元素或坐标 |
| `cu.type_text(app_id, element_index, text)` | 输入文本 |
| `cu.press_key(app_id, element_index, key)` | 按键或快捷键（如 `"cmd+s"`） |
| `cu.set_value(app_id, element_index, value)` | 替换 settable 元素的值（优先于 focus-and-type） |
| `cu.scroll(app_id, element_index, direction, *, pages)` | 滚动 |
| `cu.select_text(app_id, element_index, text, *, selection, prefix, suffix)` | 选中文本或定位光标 |
| `cu.drag(app_id, element_index, from_x, from_y, to_x, to_y)` | 拖拽（0-1000 坐标） |
| `cu.perform_secondary_action(app_id, element_index, action)` | 执行次要动作（如 AXShowMenu） |
| `cu.wait(seconds)` | 等待 0-180 秒 |

### 坐标系统

- 坐标是窗口的 **0-1000 归一化**值，不是像素
- `(0,0)` = 窗口左上角，`(500,500)` = 中心，`(1000,1000)` = 右下角
- 坐标点击时，`element_index` 是窗口行的索引（定义坐标框架）
- 多屏环境下，优先用元素级操作，避免坐标偏移

### 截图使用

- 默认不截图；只有图像/图表/Canvas/无标签组等 AX 树无法命名的目标才请求 `screenshot=True`
- 截图是临时观察，不授权创建文件；除非用户明确要求保存，否则不调用 `Frame.save()`
- 请求截图后，整 App 索引失效，下一 cell 用窗口行作为坐标锚点

### 用户接管

遇到登录、验证码、MFA、授权同意等必须用户本人操作的步骤，调用 `interaction.request_action` 请求接管，不要重试或绕过。

### 错误恢复

| 错误 | 处理 |
|------|------|
| `CU_AX_ELEMENT_INVALID` | 重新观察，用新索引 |
| `CU_AX_ACTION_REFUSED` | 检查是否有模态 sheet、disabled、非前台 App |
| `CU_AX_APP_NOT_RUNNING` | `get_app_state()` 启动 |
| `CU_AX_APP_NOT_SURFACE` | 菜单栏-only App，fallback 到 axcli |
| `CU_AX_ENVIRONMENT` | 辅助功能权限不可用，报告并停止 |
| `status=timeout` | 重新观察，不先重试（部分动作可能已执行） |

---

## 三、axcli 轻量快速操作

> axcli 是命令行 AX 工具，底层与 cu plane 相同（macOS Accessibility API），但更轻量。
> 适用于已知坐标/选择器的单步快速操作，以及 cu plane 搞不定的菜单栏-only App。

### 基本信息

- 路径：`~/.cargo/bin/axcli`
- 可靠策略：`--strategy cg --activate --no-visual-cursor`（默认 `cg-pid` 会冻结）

### 常用命令

```bash
AXCLI=~/.cargo/bin/axcli

# 1. 全局坐标点击（菜单栏图标，位置相对固定）
$AXCLI mouse click <x> <y>

# 2. 按全局快捷键
$AXCLI --app "AppName" press "Command+n"
$AXCLI --app "Alfred" press "Control+Space"

# 3. 通过选择器点击元素
$AXCLI --app "AppName" click 'AXButton >> nth=0' --strategy cg --activate --no-visual-cursor

# 4. 读取 AX 树（调试/定位元素）
$AXCLI --app "AppName" snapshot --depth 3

# 5. 填充文本
$AXCLI --app "Alfred" fill 'textfield[title="Alfred Search Field"]' "search term"

# 6. 关闭菜单
$AXCLI --app "AppName" press "Escape"
```

### 典型场景

axcli 适用于已知坐标/选择器的单步快速操作。具体 App 的完整操作流程见对应模块：
- **ClashX Pro 菜单栏交互** → 见 [vpn-control.md](vpn-control.md)
- **Alfred 搜索** → 通用示例：

```bash
AXCLI=~/.cargo/bin/axcli
$AXCLI --app "Alfred" press "Control+Space"
sleep 1
$AXCLI --app "Alfred" fill 'textfield[title="Alfred Search Field"]' "search term"
```

### axcli 已知问题

| 问题 | 解决 |
|------|------|
| 默认 `--strategy cg-pid` 冻结 | 用 `--strategy cg --activate --no-visual-cursor` |
| `screenshot` 在 macOS 13.x 崩溃 | 用 cu plane 截图，或升级 macOS 14+ |
| 属性选择器 `[title="xxx"]` 不匹配 | 用 `>> nth=N`（0-indexed） |
| Electron App 窗口内容 AX 不可见 | 用 CDP/Playwright，或 cu plane 截图+坐标 |
| 菜单栏 App cu plane 报 `NOT_SURFACE` | 用 axcli 全局坐标点击 |

---

## 四、AppleScript 系统弹窗与后台命令

> AppleScript 用于系统原生弹窗的元素级点击，以及 iTerm2 后台命令发送。
> 这些场景用 AppleScript 比 cu plane 更轻量、更可靠。

### 系统弹窗元素级点击

**核心方法**：通过 System Events 遍历 AX 树，找到按钮后执行 `AXPress`。

```bash
# 示例：点击 Chrome 远程调试授权弹窗的"允许"按钮
osascript /path/to/press_allow.applescript
```

**关键技巧**：
- 只遍历弹窗 `sheet`，不递归整窗（网页 AXWebArea 节点海量，会慢 30 倍）
- 按钮文字可能在 `AXDescription` 而非 `AXTitle`，拼接多属性匹配
- 点中即停，避免访问已失效元素报错
- 串行执行，不并发多个 osascript

### iTerm2 后台发命令（不抢焦点）

```bash
# 发送命令到 iTerm2，不激活窗口
osascript -e 'tell application "iTerm2"
  tell current session of current window
    write text "echo hello"
  end tell
end tell'
```

**优势**：不需激活 iTerm2 窗口，后台执行，不抢用户焦点。

### 激活 App

```bash
osascript -e 'tell application "AppName" to activate'
```

> **窗口精准定位**（set bounds / position / size）见 [window-management.md](window-management.md)。

---

## 五、结果验证

- `status=ok` 只证明 cell 返回，`ok=True` 只证明服务器接受
- 用 AX 树证明 UI 状态，用文件系统证明持久化
- 确认预期值/选择/窗口/控件存在，且无错误/阻塞弹窗
- 系统弹窗点击后，以业务状态为准（不只是弹窗消失）
