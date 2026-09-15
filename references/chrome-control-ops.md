# Chrome 内核控制：调试 / 连接恢复 / 通用注意事项

> 选型、bu plane、Playwright CLI 见 [chrome-control-overview.md](chrome-control-overview.md)；CDP 直连与 Puppeteer 见 [chrome-cdp-puppeteer.md](chrome-cdp-puppeteer.md)。本篇管"出问题怎么恢复、以及全局红线"。

---

## 一、Chrome DevTools MCP

> 通过 MCP 协议控制 Chrome DevTools，适合调试和性能分析。

**适用场景**：调试网页（控制台日志、网络请求）、性能分析（Lighthouse、性能面板）、DevTools 操作（元素检查、源代码调试）、移动端模拟。

详见系统内置 `chrome-devtools` skill，调用前先读取其 SKILL.md。

---

## 二、连接失败恢复

### Playwright 连接失败

1. 检查连接状态：`npx playwright cli -s=ga tab-list`
2. 如果报错，自动刷新 Token 后重连
3. 检查当前页面 URL：`npx playwright cli -s=ga eval "() => window.location.href"`
4. 连接失败时**禁止直接要求用户手动操作**，先尝试自动恢复

### CDP 连接失败

| 错误 | 原因 | 解决 |
|------|------|------|
| `connection refused` | App 未带调试端口启动 | Cmd+Q 完全退出，用 `--remote-debugging-port` 重启 |
| 授权弹窗卡住 | Chrome 远程调试授权未确认 | 用 AppleScript AXPress 点"允许"（见 chrome-cdp-puppeteer.md §五） |
| 页面找不到 | URL 变化或页面关闭 | 重新 `curl http://127.0.0.1:9222/json` 列出页面 |

---

## 三、Chrome Gemini 按钮启用 / 修复（直接查飞书，不重复造轮子）

- 涉及 Chrome「Gemini in Chrome」按钮的**启用 / 修复**操作，**直接参考飞书知识库文档，不再重复创建本地 Skill 或脚本**：
  - <https://zcnjheoajxng.feishu.cn/wiki/LrqqwwVZiiIaAXk9C7vcOFM0nsf>
- 该规则与全局 `~/Doubao/AGENTS.md` 第五章一致；飞书文档是唯一维护处，本技能只放指针（DRY，不复制内容）。

---

## 四、通用注意事项（Playwright / bu / CDP 共通）

1. **Token 安全**：`PLAYWRIGHT_MCP_EXTENSION_TOKEN` 是敏感信息，不要硬编码到公开脚本。
2. **会话隔离**：不同项目用不同会话名，避免冲突。
3. **页面加载**：导航后等待页面加载完成再操作，用 `wait-for` 或 `wait`。
4. **ref 失效**：页面刷新或导航后，之前的元素引用失效，需要重新获取。
5. **超时处理**：命令超时移到后台时，用 TaskOutput 等待结果。
6. **关闭多余 tab**：操作前清理多余标签页，从后往前关闭。
7. **登录态保护**：storage-state 文件含敏感信息，不要提交到公开仓库。
8. **端点现读 / 双机路径 / 断开别关窗**：这三条 CDP·Puppeteer 专属，见 [chrome-cdp-puppeteer.md](chrome-cdp-puppeteer.md) §六。
