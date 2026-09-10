# 第二层：Chrome 内核应用控制

> 本层用于控制基于 Chrome/Electron 的应用内部内容。
> 当 cu plane（AX 树）看不到网页内部 DOM 时，使用本层工具。

---

## 一、技术选型

Chrome 内核应用的控制有 4 种方法，按场景选择：

| 方法 | 能力 | 适用场景 | 工具 |
|------|------|---------|------|
| **bu plane（browser-use）** | 最自动化，自动处理等待/重试/弹窗 | 通用网页操作，复杂交互 | `mac_computer_use_tool(plane="bu")` |
| **Playwright CLI** | 脚本化，连接已运行 Chrome，执行 JS | 批量操作、自动化流程、命令行 | `npx playwright cli` |
| **CDP 直连** | 底层协议，最灵活，支持非标准 Electron App | VS Code、自定义 Electron App、调试 | `curl` / Playwright `connectOverCDP` |
| **Chrome DevTools MCP** | 通过 MCP 控制 Chrome，调试能力强 | 调试、性能分析、DevTools 操作 | chrome-devtools skill |

### 选型决策

```
需要控制 Chrome 内核应用
│
├─ 是通用网页操作（点击、填表、导航）？
│   └─ 是 → bu plane（最自动化，推荐默认）
│
├─ 是脚本化/批量操作（需要在 Bash 脚本中调用）？
│   └─ 是 → Playwright CLI
│
├─ 是 VS Code 或其他非标准 Electron App？
│   └─ 是 → CDP 直连（--remote-debugging-port）
│
└─ 是调试/性能分析/DevTools 操作？
    └─ 是 → Chrome DevTools MCP
```

### 为什么不用 cu plane

cu plane 只能看到浏览器窗口的 AX 树，网页内容区域是一个 `AXWebArea`，内部 DOM 元素不可见。本层工具能读取网页完整 DOM，操作更精准。

---

## 二、bu plane（browser-use）

> 豆包内置的浏览器自动化工具，最自动化，能处理复杂网页交互。

### 基本用法

```python
# 在 mac_computer_use_tool(plane="bu") 中
import seed_browser_use as bu
```

### 适用场景

- 通用网页操作（导航、点击、填表、截图）
- 复杂交互（需要等待元素出现、处理弹窗）
- 多步骤网页任务
- 不需要脚本化的一次性操作

### 注意事项

- bu plane 操作的是豆包内置浏览器或指定的本地浏览器
- 操作前先 `bu.snapshot()` 获取页面状态
- 元素引用（ref）在页面导航后失效，需要重新 snapshot
- 详见系统内置 `browser-use-automation-mac` 技能

---

## 三、Playwright CLI

> 命令行浏览器自动化工具，适合脚本化和批量操作。

### 三种连接模式

| 模式 | 命令 | 适用场景 | 前置条件 |
|------|------|---------|---------|
| **新浏览器** | `open` | 不需要登录态、干净环境 | 无 |
| **Extension 附加** | `attach --extension=chrome` | 复用用户已登录的 Chrome/Edge、用户想观察操作过程 | 用户安装 Playwright Extension 并提供 token |
| **CDP 连接** | `attach --cdp=http://localhost:9222` | VS Code、其他 Electron 应用 | 应用以 `--remote-debugging-port` 启动 |

### 快速开始

#### 模式 1：启动新浏览器

```bash
npx playwright cli open https://example.com
npx playwright cli snapshot
npx playwright cli click e15
npx playwright cli close
```

#### 模式 2：Extension 附加到用户 Chrome

```bash
# 1. 一次性附加（创建名为 ga 的持久会话）
PLAYWRIGHT_MCP_EXTENSION_TOKEN=<token> npx playwright cli -s=ga attach --extension=chrome

# 2. 后续操作复用会话（不需要再传 token）
npx playwright cli -s=ga goto https://example.com
npx playwright cli -s=ga snapshot
npx playwright cli -s=ga click e15

# 3. 断开（浏览器保持打开）
npx playwright cli -s=ga detach
```

#### 模式 3：CDP 连接 VS Code

```bash
# 1. 先完全退出 VS Code（Cmd+Q），再以调试模式启动
code --remote-debugging-port=9222 ~/project
# 或直接用 Electron 二进制：
# "/Applications/Visual Studio Code.app/Contents/MacOS/Electron" --remote-debugging-port=9222 ~/project &

# 2. 验证 CDP 端点
curl -s http://127.0.0.1:9222/json/version

# 3. 附加并操作
npx playwright cli -s=vscode attach --cdp=http://127.0.0.1:9222
npx playwright cli -s=vscode snapshot
npx playwright cli -s=vscode click e3
npx playwright cli -s=vscode detach
```

### 会话管理

- 用 `-s=<session_name>` 指定会话名
- 高顿教育项目用会话名 `ga`
- 连接后所有命令都需指定会话：`playwright cli -s=ga <command>`
- `detach` 断开连接但浏览器保持打开
- `close` 关闭浏览器

### 常用命令

```bash
# 导航
npx playwright cli -s=ga goto "https://example.com"

# 标签页管理
npx playwright cli -s=ga tab-list
npx playwright cli -s=ga tab-select <index>
npx playwright cli -s=ga tab-close <index>
npx playwright cli -s=ga tab-new [url]

# 执行 JavaScript
npx playwright cli -s=ga eval "() => { return document.title; }"

# 点击元素（通过 JS）
npx playwright cli -s=ga eval "() => { document.querySelector('button.submit').click(); }"

# 截图
npx playwright cli -s=ga screenshot

# 等待
npx playwright cli -s=ga wait 3000
npx playwright cli -s=ga wait-for "button.submit"
```

### 登录态复用（storage-state）

Playwright 可以保存和恢复浏览器的登录状态（cookies、localStorage），避免重复登录。

```bash
# 保存当前登录状态
npx playwright cli -s=ga storage-state save /path/to/state.json

# 恢复登录状态（启动新浏览器时加载）
npx playwright cli open --storage-state /path/to/state.json https://example.com
```

**适用场景**：
- 需要多次访问需要登录的网站
- 自动化测试中复用登录态
- 避免每次都手动登录

**注意**：
- storage-state 文件包含敏感信息（cookies），不要提交到公开 Git 仓库
- 登录态可能过期，过期后需要重新登录并保存

### 操作前检查（强制）

每次交互前先检查标签页状态：

```bash
npx playwright cli -s=ga tab-list
```

**处理原则**：
- 优先在当前工作页操作
- 多余页面从后往前关闭（避免索引变化）
- 页面异常先刷新，不要反复尝试
- 只保留当前工作页，参考文档可额外保留 1 个

### 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `open --extension=chrome` 报错 | open 不支持 --extension | 用 `attach --extension=chrome` |
| URL 解析错误 | URL 没加引号 | URL 必须加引号 |
| 没有 `navigate` 命令 | 命令名是 `goto` | 用 `goto` 不是 `navigate` |
| 连接失败 | Token 错误或扩展未运行 | 检查 Token，刷新连接 |
| ref 失效 | 页面导航后元素引用过期 | 重新 snapshot/eval |

---

## 四、CDP 直连

> Chrome DevTools Protocol 底层协议，用于控制非标准 Electron App（如 VS Code）。

### VS Code CDP 设置

#### 启动带 CDP 的 VS Code

```bash
# 先完全退出 VS Code（Cmd+Q），然后：
"/Applications/Visual Studio Code.app/Contents/MacOS/Electron" --remote-debugging-port=9222 ~/project &

# 或用别名（已配置 code-d）
code-d ~/project
```

**验证**：
```bash
curl -s http://127.0.0.1:9222/json/version
```

**注意**：`--remote-debugging-port` 只在首次启动时生效；VS Code 已运行时打开新窗口不会启用 CDP。

#### CDP 连接示例（Playwright）

```javascript
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
  const contexts = browser.contexts();
  for (const ctx of contexts) {
    for (const page of ctx.pages()) {
      if (page.url().startsWith('vscode-file://')) {
        // VS Code workbench 页面
        const buttons = await page.locator('.action-item').allInnerTexts();
        console.log(buttons);
      }
    }
  }
  await browser.close();
})();
```

### 其他 Electron App

任何基于 Electron 的 App 都可以通过 `--remote-debugging-port` 启用 CDP：

```bash
"/Applications/AppName.app/Contents/MacOS/Electron" --remote-debugging-port=9223 &
```

然后用 Playwright `connectOverCDP('http://127.0.0.1:9223')` 连接。

### Chrome 远程调试授权弹窗

连接 Chrome CDP 时可能弹出「要允许远程调试吗？」弹窗，用 AppleScript AXPress 自动点掉：

```bash
osascript /path/to/scripts/cdp/press_allow.applescript
```

详见 [cu-plane-guide.md](cu-plane-guide.md) 的 AppleScript 部分。

---

## 五、Chrome DevTools MCP

> 通过 MCP 协议控制 Chrome DevTools，适合调试和性能分析。

### 适用场景

- 调试网页（查看控制台日志、网络请求）
- 性能分析（Lighthouse、性能面板）
- DevTools 操作（元素检查、源代码调试）
- 移动端模拟

### 使用方式

详见 `chrome-devtools` skill（系统内置），调用前先读取其 SKILL.md。

---

## 六、连接失败恢复

### Playwright 连接失败

1. 检查连接状态：`npx playwright cli -s=ga tab-list`
2. 如果报错，自动刷新 Token 后重连
3. 检查当前页面 URL：`npx playwright cli -s=ga eval "() => window.location.href"`
4. 连接失败时**禁止直接要求用户手动操作**，先尝试自动恢复

### CDP 连接失败

| 错误 | 原因 | 解决 |
|------|------|------|
| `connection refused` | App 未带调试端口启动 | Cmd+Q 完全退出，用 `--remote-debugging-port` 重启 |
| 授权弹窗卡住 | Chrome 远程调试授权未确认 | 用 AppleScript AXPress 点"允许" |
| 页面找不到 | URL 变化或页面关闭 | 重新 `curl http://127.0.0.1:9222/json` 列出页面 |

---

## 七、注意事项

1. **Token 安全**：`PLAYWRIGHT_MCP_EXTENSION_TOKEN` 是敏感信息，不要硬编码到公开脚本
2. **会话隔离**：不同项目用不同会话名，避免冲突
3. **页面加载**：导航后等待页面加载完成再操作，用 `wait-for` 或 `wait`
4. **ref 失效**：页面刷新或导航后，之前的元素引用失效，需要重新获取
5. **超时处理**：命令超时移到后台时，用 TaskOutput 等待结果
6. **关闭多余 tab**：操作前清理多余标签页，从后往前关闭
7. **登录态保护**：storage-state 文件包含敏感信息，不要提交到公开仓库
