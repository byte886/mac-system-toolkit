# 第二层：Chrome 内核应用控制

> 本层用于控制基于 Chrome/Electron 的应用内部内容。
> 当 cu plane（AX 树）看不到网页内部 DOM 时，使用本层工具。

---

## 一、技术选型

对 Chrome 的控制分两层理解：**底层是 CDP（Chrome DevTools Protocol）**，上层有多个"客户端封装"；再加桌面/浏览器辅助通道，一共 5 种入口，按场景选择：

| 方法 | 层次 | 能力 | 适用场景 | 工具 |
|------|------|------|---------|------|
| **bu plane（browser-use）** | 桌面辅助 | 最自动化，自动处理等待/重试/弹窗 | 通用网页操作、复杂交互、一次性任务 | `mac_computer_use_tool(plane="bu")` |
| **Playwright CLI** | CDP / 扩展上层封装（微软） | 脚本化，连接已运行 Chrome、执行 JS | 命令行即用即走、批量流程 | `npx playwright cli` |
| **Puppeteer / puppeteer-core** | CDP 上层封装（**Google 官方**） | 长期可维护的 Node 自动化工程，可复用日常登录态 | 项目级脚本/服务（完整范例见高顿仓） | `npm i puppeteer-core` |
| **CDP 直连（裸协议）** | 底层协议 | 最灵活、可触达全部 CDP 域，支持非标准 Electron | VS Code/Electron、上层库没封装的能力、调试 | `curl` / WebSocket / `createCDPSession` |
| **Chrome DevTools MCP** | CDP 上层封装（Google，MCP 形态） | 以 MCP 工具暴露，调试/网络/性能强 | 调试、性能分析、网络与内存审计 | chrome-devtools skill |

> **分层关系（关键认知）**：Puppeteer、Playwright、chrome-devtools-mcp **都是架在 CDP 之上的平级客户端封装**，只是出品方与形态不同（Google 的库 / 微软的库 / Google 的 MCP）；上层 API 够不着时都能"穿透"回裸 CDP（见 §四）。此外还有一条**不占调试端口的「扩展通道」**（Playwright Extension，经 `chrome.debugger` 的受限 CDP、一次附加一个标签组），见 §三。

### 选型决策

```
需要控制 Chrome 内核应用
│
├─ 是通用网页操作（点击、填表、导航）？
│   └─ 是 → bu plane（最自动化，推荐默认）
│
├─ 是长期维护的 Node 自动化工程（要复用日常 Chrome 登录态、写进项目）？
│   └─ 是 → Puppeteer / puppeteer-core（Google 官方，见 §四）
│
├─ 是临时脚本化/批量操作（命令行即用即走）？
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
| **Extension 附加** | `attach --extension=chrome` | 复用用户已登录的 Chrome/Edge、用户想观察操作过程 | 装好 Playwright Extension，首次在扩展页完成配对（token 动态生成，见 §四 4.1 通道 C） |
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

## 四、CDP 直连与 Puppeteer

> CDP（Chrome DevTools Protocol）是控制 Chrome/Electron 的底层协议，Puppeteer / Playwright / DevTools-MCP 都封装它。本节先讲怎么"开通道"，再讲用 Puppeteer 连日常 Chrome，最后讲如何穿透回裸 CDP；VS Code 等非标准 Electron 的连法在本节后部。

### 4.1 三条"连上 Chrome"的通道（重点：如何复用日常登录态）

| 通道 | 怎么开 | 能否复用默认 profile 登录态 | 端点形态 |
|------|--------|------------------------------|----------|
| A. 老式命令行 `--remote-debugging-port` | 启动时带参数 + 独立 `--user-data-dir` | 默认 profile 受限，基本要独立目录（需重登） | HTTP：`/json/version`、`/json` 列 target |
| B. Chrome 144+「运行时远程调试」 | `chrome://inspect/#remote-debugging` 按 profile 勾选一次，**持久化、免重启、免独立目录** | **可以，直接复用日常默认 profile** | **仅 WebSocket**，无 `/json`（返回 404 属正常） |
| C. Playwright 扩展通道 | `attach --extension=chrome`，扩展经 `chrome.debugger` 附加标签组 | 可以（就是当前用户 Chrome） | 本地 relay + 动态 token，不走调试端口 |

- **通道 A（老式，适合一次性 / 干净环境 / Electron）**：必须配独立 `--user-data-dir`，否则新版 Chrome 出于安全不给默认 profile 开端口；用 `curl http://127.0.0.1:PORT/json/version` 探活。
- **通道 B（Chrome 144+，日常自动化首选）**：打开 `chrome://inspect/#remote-debugging`，对目标 profile 勾选启用（一次设置长期有效），之后**不用重启 Chrome、不用独立目录、不用重登网站**。端点写在该 profile 根目录的 `DevToolsActivePort` 文件：**第 1 行是端口、第 2 行是 `/devtools/browser/<uuid>`**；UUID 每次重启都变，**禁止硬编码，每次现读**。该通道 WebSocket-only，没有 `/json/version`、`/json/list`（拿它们探活会 404，是正常现象，不代表没开）。每次连接会弹一次「要允许远程调试吗？」——官方刻意保留、无法永久关闭，用 AppleScript 串行 AXPress 代点（见本节末"授权弹窗"）。
- **通道 C（扩展）**：见 §三；token 由 Playwright 端启动时动态生成、经 connect.html 自动带给扩展配对，**不是固定字符串**；新机器首次需在扩展页点一次 "Allow & select"。

> 默认 profile 根目录：`~/Library/Application Support/Google/Chrome/`，`DevToolsActivePort` 位于其下（多 profile 时以实际 profile 目录为准）。

### 4.2 用 Puppeteer 连"已经开着"的日常 Chrome（项目工程首选）

Puppeteer 是 **Google Chrome DevTools 团队官方维护**的 "high-level API to control Chrome over the DevTools Protocol"。项目里用 **`puppeteer-core`**：它不下载自带 Chromium，只连接你已经打开的 Chrome，体积小、不会出现浏览器版本打架。

```bash
npm i puppeteer-core   # 只装库，不下载浏览器
```

最小连接（通道 B：从 DevToolsActivePort 动态取 WebSocket 端点）：

```javascript
const fs = require('fs');
const os = require('os');
const path = require('path');
const puppeteer = require('puppeteer-core');

// 每次现读，禁止硬编码 uuid
const profileRoot = path.join(os.homedir(), 'Library/Application Support/Google/Chrome');
const [port, wsPath] = fs.readFileSync(path.join(profileRoot, 'DevToolsActivePort'), 'utf8').trim().split('\n');
const browserWSEndpoint = `ws://127.0.0.1:${port}${wsPath}`;

(async () => {
  const browser = await puppeteer.connect({
    browserWSEndpoint,
    defaultViewport: null,        // 复用真实窗口尺寸
    targetFilter: () => true,     // 连同 background / service worker 等全部 target
    handleDevToolsAsPage: true,
  });
  console.log('已接管标签数:', (await browser.pages()).length);
  // ...业务操作...
  await browser.disconnect();     // 断开但保留用户的 Chrome（别用 browser.close()）
})();
```

要点：
- 连**已开的日常 Chrome 用 `puppeteer.connect` + `browserWSEndpoint`**，不要 launch 新浏览器；收尾用 `disconnect()`（保留用户窗口），不要 `close()`。
- 通道 A（有 HTTP 端点）也可用 `puppeteer.connect({ browserURL: 'http://127.0.0.1:9222' })`。
- **完整可运行的工程范例（授权弹窗代点、target 选择、健壮重连）不在本技能复制**，见高顿课程仓 `scripts/cdp/connect_browser.js` 与决策记录 ADR-010；本技能只沉淀通用方法（DRY）。

### 4.3 上层 API 不够时，穿透回裸 CDP

Puppeteer 高级 API 没覆盖的能力，用 `createCDPSession()` 直接发 CDP 命令；例如开一个**后台标签、不抢前台焦点**：

```javascript
const page = await browser.newPage();                  // 高级 API
const client = await page.target().createCDPSession(); // 穿透到裸 CDP
await client.send('Target.createTarget', { url: 'about:blank', background: true });
```

Playwright 侧等价物是 `connectOverCDP`（见下）与 CDPSession；DevTools-MCP 把 CDP 包成 MCP 工具。**三者底层是同一套 CDP 命令。**

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

连接 Chrome CDP（尤其通道 B，**每次连接都会弹一次**，官方刻意设计、无法永久关闭）时，用 AppleScript AXPress 自动点掉：

```bash
osascript /path/to/scripts/cdp/press_allow.applescript
```

经验：只遍历**授权 sheet 本身**去点"允许"，**不要遍历网页 AXWebArea**（会上万节点导致超时）；多次连接必须**串行**点按，避免 System Events 拥塞。详见 [cu-plane-guide.md](cu-plane-guide.md) 的 AppleScript 部分。

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

## 七、Chrome Gemini 按钮启用 / 修复（直接查飞书，不重复造轮子）

- 涉及 Chrome「Gemini in Chrome」按钮的**启用 / 修复**操作，**直接参考飞书知识库文档，不再重复创建本地 Skill 或脚本**：
  - <https://zcnjheoajxng.feishu.cn/wiki/LrqqwwVZiiIaAXk9C7vcOFM0nsf>
- 该规则与全局 `~/Doubao/AGENTS.md` 第五章一致；飞书文档是唯一维护处，本技能只放指针（DRY，不复制内容）。

---

## 八、注意事项

1. **Token 安全**：`PLAYWRIGHT_MCP_EXTENSION_TOKEN` 是敏感信息，不要硬编码到公开脚本
2. **会话隔离**：不同项目用不同会话名，避免冲突
3. **页面加载**：导航后等待页面加载完成再操作，用 `wait-for` 或 `wait`
4. **ref 失效**：页面刷新或导航后，之前的元素引用失效，需要重新获取
5. **超时处理**：命令超时移到后台时，用 TaskOutput 等待结果
6. **关闭多余 tab**：操作前清理多余标签页，从后往前关闭
7. **登录态保护**：storage-state 文件包含敏感信息，不要提交到公开仓库
8. **端点现读**：`DevToolsActivePort` 里的 uuid 每次重启都变，禁止硬编码；通道 B 是 WebSocket-only，`/json` 返回 404 属正常，别误判成"没开调试"
9. **双机路径解耦**：自动化脚本一律用 `os.homedir()` / `$HOME` 拼路径，不写死 `/Users/wenjiechen` 或 `/Users/chenwenjie`（两台黑苹果家目录名不同）
10. **断开别关窗**：接管用户已开的 Chrome 时收尾用 `disconnect()`/`detach`，不要 `close()`/`kill`，避免关掉用户正在用的窗口
