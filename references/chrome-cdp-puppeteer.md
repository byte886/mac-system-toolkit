# CDP 直连与 Puppeteer（连接日常 Chrome / 复用登录态 / VS Code·Electron）

> CDP（Chrome DevTools Protocol）是控制 Chrome/Electron 的底层协议，Puppeteer / Playwright / DevTools-MCP 都封装它。
> 选型与 bu/Playwright CLI 见 [chrome-control-overview.md](chrome-control-overview.md)；连接失败恢复与注意事项见 [chrome-control-ops.md](chrome-control-ops.md)。

---

## 一、三条"连上 Chrome"的通道（重点：如何复用日常登录态）

| 通道 | 怎么开 | 能否复用默认 profile 登录态 | 端点形态 |
|------|--------|------------------------------|----------|
| A. 老式命令行 `--remote-debugging-port` | 启动时带参数 + 独立 `--user-data-dir` | 默认 profile 受限，基本要独立目录（需重登） | HTTP：`/json/version`、`/json` 列 target |
| B. Chrome 144+「运行时远程调试」 | `chrome://inspect/#remote-debugging` 按 profile 勾选一次，**持久化、免重启、免独立目录** | **可以，直接复用日常默认 profile** | **仅 WebSocket**，无 `/json`（返回 404 属正常） |
| C. Playwright 扩展通道 | `attach --extension=chrome`，扩展经 `chrome.debugger` 附加标签组 | 可以（就是当前用户 Chrome） | 本地 relay + 动态 token，不走调试端口 |

- **通道 A（老式，适合一次性 / 干净环境 / Electron）**：必须配独立 `--user-data-dir`，否则新版 Chrome 出于安全不给默认 profile 开端口；用 `curl http://127.0.0.1:PORT/json/version` 探活。
- **通道 B（Chrome 144+，日常自动化首选）**：打开 `chrome://inspect/#remote-debugging`，对目标 profile 勾选启用（一次设置长期有效），之后**不用重启 Chrome、不用独立目录、不用重登网站**。端点写在该 profile 根目录的 `DevToolsActivePort` 文件：**第 1 行是端口、第 2 行是 `/devtools/browser/<uuid>`**；UUID 每次重启都变，**禁止硬编码，每次现读**。该通道 WebSocket-only，没有 `/json/version`、`/json/list`（探活会 404，是正常现象）。每次连接弹一次「要允许远程调试吗？」——官方刻意保留、无法永久关闭，用 AppleScript 串行 AXPress 代点（见本节末"授权弹窗"）。
- **通道 C（扩展）**：见 [chrome-control-overview.md](chrome-control-overview.md) §三；token 由 Playwright 端启动时动态生成、经 connect.html 自动配对，**不是固定字符串**；新机器首次需在扩展页点一次 "Allow & select"。

> 默认 profile 根目录：`~/Library/Application Support/Google/Chrome/`，`DevToolsActivePort` 位于其下（多 profile 时以实际 profile 目录为准）。

---

## 二、用 Puppeteer 连"已经开着"的日常 Chrome（项目工程首选）

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
- **完整可运行的工程范例（授权弹窗代点、target 选择、健壮重连）不在本技能复制**，见对应业务仓的 `scripts/cdp/connect_browser.js` 与决策记录 ADR；本技能只沉淀通用方法（DRY）。

---

## 三、上层 API 不够时，穿透回裸 CDP

Puppeteer 高级 API 没覆盖的能力，用 `createCDPSession()` 直接发 CDP 命令；例如开一个**后台标签、不抢前台焦点**：

```javascript
const page = await browser.newPage();                  // 高级 API
const client = await page.target().createCDPSession(); // 穿透到裸 CDP
await client.send('Target.createTarget', { url: 'about:blank', background: true });
```

Playwright 侧等价物是 `connectOverCDP` 与 CDPSession；DevTools-MCP 把 CDP 包成 MCP 工具。**三者底层是同一套 CDP 命令。**

---

## 四、VS Code CDP 设置

```bash
# 先完全退出 VS Code（Cmd+Q），然后：
"/Applications/Visual Studio Code.app/Contents/MacOS/Electron" --remote-debugging-port=9222 ~/project &
curl -s http://127.0.0.1:9222/json/version   # 验证
```

**注意**：`--remote-debugging-port` 只在首次启动时生效；VS Code 已运行时打开新窗口不会启用 CDP。

CDP 连接示例（Playwright）：

```javascript
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
  for (const ctx of browser.contexts())
    for (const page of ctx.pages())
      if (page.url().startsWith('vscode-file://')) {
        const buttons = await page.locator('.action-item').allInnerTexts();
        console.log(buttons);   // VS Code workbench 页面
      }
  await browser.close();
})();
```

### 其他 Electron App

任何基于 Electron 的 App 都可通过 `--remote-debugging-port` 启用 CDP：

```bash
"/Applications/AppName.app/Contents/MacOS/Electron" --remote-debugging-port=9223 &
# 然后 Playwright connectOverCDP('http://127.0.0.1:9223')
```

---

## 五、Chrome 远程调试授权弹窗

连接 Chrome CDP（尤其通道 B，**每次连接都会弹一次**，官方刻意设计、无法永久关闭）时，用 AppleScript AXPress 自动点掉：

```bash
osascript /path/to/scripts/cdp/press_allow.applescript
```

经验：只遍历**授权 sheet 本身**去点"允许"，**不要遍历网页 AXWebArea**（会上万节点导致超时）；多次连接必须**串行**点按，避免 System Events 拥塞。详见 [cu-plane-guide.md](cu-plane-guide.md) 的 AppleScript 部分。

---

## 六、CDP / Puppeteer 专属注意事项

- **端点现读**：`DevToolsActivePort` 里的 uuid 每次重启都变，禁止硬编码；通道 B 是 WebSocket-only，`/json` 返回 404 属正常，别误判成"没开调试"。
- **双机路径解耦**：自动化脚本一律用 `os.homedir()` / `$HOME` 拼路径，不写死 `/Users/<用户名>`（两台机家目录名不同）。
- **断开别关窗**：接管用户已开的 Chrome 时收尾用 `disconnect()`/`detach`，不要 `close()`/`kill`，避免关掉用户正在用的窗口。
