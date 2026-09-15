# 第二层：Chrome 内核应用控制（选型 + bu plane + Playwright CLI）

> 本层控制 Chrome/Electron 应用**内部内容**。当 cu plane（AX 树）只看到一个 `AXWebArea`、网页 DOM 不可见时，用本层。
> CDP 直连 / Puppeteer / 复用日常登录态的内容见 [chrome-cdp-puppeteer.md](chrome-cdp-puppeteer.md)；连接失败恢复与注意事项见 [chrome-control-ops.md](chrome-control-ops.md)。

---

## 一、技术选型

对 Chrome 的控制分两层理解：**底层是 CDP（Chrome DevTools Protocol）**，上层有多个"客户端封装"；再加桌面/浏览器辅助通道，一共 5 种入口：

| 方法 | 层次 | 能力 | 适用场景 | 工具 |
|------|------|------|---------|------|
| **bu plane（browser-use）** | 桌面辅助 | 最自动化，自动处理等待/重试/弹窗 | 通用网页操作、复杂交互、一次性任务 | `mac_computer_use_tool(plane="bu")` |
| **Playwright CLI** | CDP 上层封装（微软） | 脚本化，连接已运行 Chrome、执行 JS | 命令行即用即走、批量流程 | `npx playwright cli` |
| **Puppeteer / puppeteer-core** | CDP 上层封装（**Google 官方**） | 长期可维护的 Node 自动化工程，可复用日常登录态 | 项目级脚本/服务 | 见 [chrome-cdp-puppeteer.md](chrome-cdp-puppeteer.md) |
| **CDP 直连（裸协议）** | 底层协议 | 最灵活、可触达全部 CDP 域，支持非标准 Electron | VS Code/Electron、上层库没封装的能力、调试 | 见 [chrome-cdp-puppeteer.md](chrome-cdp-puppeteer.md) |
| **Chrome DevTools MCP** | CDP 上层封装（Google，MCP） | 以 MCP 工具暴露，调试/网络/性能强 | 调试、性能分析、网络与内存审计 | 见 [chrome-control-ops.md](chrome-control-ops.md) |

> **分层关系（关键认知）**：Puppeteer、Playwright、chrome-devtools-mcp **都是架在 CDP 之上的平级客户端封装**，只是出品方与形态不同；上层 API 够不着时都能"穿透"回裸 CDP。此外还有一条**不占调试端口的「扩展通道」**（Playwright Extension，经 `chrome.debugger` 附加标签组），见下文 §三。

### 选型决策

```
需要控制 Chrome 内核应用
│
├─ 是通用网页操作（点击、填表、导航）？
│   └─ 是 → bu plane（最自动化，推荐默认）
├─ 是长期维护的 Node 自动化工程（复用日常 Chrome 登录态、写进项目）？
│   └─ 是 → Puppeteer / puppeteer-core（Google 官方，见 chrome-cdp-puppeteer.md）
├─ 是临时脚本化/批量操作（命令行即用即走）？
│   └─ 是 → Playwright CLI
├─ 是 VS Code 或其他非标准 Electron App？
│   └─ 是 → CDP 直连（chrome-cdp-puppeteer.md）
└─ 是调试/性能分析/DevTools 操作？
    └─ 是 → Chrome DevTools MCP（chrome-control-ops.md）
```

### 为什么不用 cu plane

cu plane 只能看到浏览器窗口的 AX 树，网页内容区域是一个 `AXWebArea`，内部 DOM 元素不可见。本层工具能读取网页完整 DOM，操作更精准。

---

## 二、bu plane（browser-use）

> 豆包内置的浏览器自动化工具，最自动化，能处理复杂网页交互。

```python
# 在 mac_computer_use_tool(plane="bu") 中
import seed_browser_use as bu
```

**适用场景**：通用网页操作（导航、点击、填表、截图）、复杂交互（需等待元素出现、处理弹窗）、多步骤网页任务、不需要脚本化的一次性操作。

**注意事项**：操作前先 `bu.snapshot()` 获取页面状态；元素引用（ref）在页面导航后失效，需重新 snapshot。详见系统内置 `browser-use-automation-mac` 技能。

---

## 三、Playwright CLI

> 命令行浏览器自动化工具，适合脚本化和批量操作。

### 三种连接模式

| 模式 | 命令 | 适用场景 | 前置条件 |
|------|------|---------|---------|
| **新浏览器** | `open` | 不需要登录态、干净环境 | 无 |
| **Extension 附加** | `attach --extension=chrome` | 复用用户已登录的 Chrome/Edge、用户想观察操作过程 | 装好 Playwright Extension，首次在扩展页完成配对（token 动态生成） |
| **CDP 连接** | `attach --cdp=http://localhost:9222` | VS Code、其他 Electron 应用 | 应用以 `--remote-debugging-port` 启动（见 chrome-cdp-puppeteer.md） |

### 快速开始

**模式 1：启动新浏览器**

```bash
npx playwright cli open https://example.com
npx playwright cli snapshot
npx playwright cli click e15
npx playwright cli close
```

**模式 2：Extension 附加到用户 Chrome**

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

**模式 3：CDP 连接 VS Code**（先 `code --remote-debugging-port=9222 ~/project`，详见 chrome-cdp-puppeteer.md）

```bash
curl -s http://127.0.0.1:9222/json/version   # 验证 CDP 端点
npx playwright cli -s=vscode attach --cdp=http://127.0.0.1:9222
npx playwright cli -s=vscode snapshot
npx playwright cli -s=vscode click e3
npx playwright cli -s=vscode detach
```

### 会话管理

- 用 `-s=<session_name>` 指定会话名；不同项目用不同会话名避免冲突。
- 连接后所有命令都需指定会话：`playwright cli -s=ga <command>`。
- `detach` 断开但浏览器保持打开；`close` 关闭浏览器。

### 常用命令

```bash
npx playwright cli -s=ga goto "https://example.com"
npx playwright cli -s=ga tab-list            # 标签页管理：tab-select/tab-close/tab-new
npx playwright cli -s=ga eval "() => document.title"   # 执行 JS
npx playwright cli -s=ga screenshot
npx playwright cli -s=ga wait 3000
npx playwright cli -s=ga wait-for "button.submit"
```

### 登录态复用（storage-state）

```bash
npx playwright cli -s=ga storage-state save /path/to/state.json   # 保存
npx playwright cli open --storage-state /path/to/state.json https://example.com  # 恢复
```

> storage-state 含 cookies 等敏感信息，**不要提交到公开 Git 仓库**；登录态会过期，过期后重登再保存。

### 操作前检查（强制）

每次交互前先 `npx playwright cli -s=ga tab-list`。原则：优先在当前工作页操作；多余页面**从后往前关**（避免索引变化）；页面异常先刷新，不要反复尝试；只保留当前工作页，参考文档可额外留 1 个。

### 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `open --extension=chrome` 报错 | open 不支持 --extension | 用 `attach --extension=chrome` |
| URL 解析错误 | URL 没加引号 | URL 必须加引号 |
| 没有 `navigate` 命令 | 命令名是 `goto` | 用 `goto` 不是 `navigate` |
| 连接失败 | Token 错误或扩展未运行 | 检查 Token，刷新连接 |
| ref 失效 | 页面导航后元素引用过期 | 重新 snapshot/eval |
