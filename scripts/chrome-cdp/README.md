# chrome-cdp · Chrome 远程调试连接与自动化

> 连接"用户正在使用的日常 Chrome"（不是另开一个浏览器），并提供授权、标签页清理、人味浏览等基础能力。
> 其他需要操作 Chrome 的脚本统一从这里连接，不各自重复实现连接逻辑。

---

## 脚本清单

| 脚本 | 作用 |
|---|---|
| `connect_browser.js` | **核心连接库**：连接用户日常 Chrome，自动处理授权弹窗；提供 `connectDailyChrome / safeDisconnect / findPage` |
| `cdp_consent_guard.sh` | 全局单例的「Chrome 远程调试授权」兜底守护（技能通用版） |
| `press_allow.applescript` | 用 AppleScript 自动点击 Chrome 的远程调试授权弹窗 |
| `press_allow_locked.sh` | 跨进程串行化 `press_allow.applescript` 的薄包装（防止并发点击冲突） |
| `tab_hygiene.js` | 关闭"本流程产生"的标签页，保持 Chrome 整洁（安全第一，不碰用户原有标签） |
| `human_browse_xhs.js` | 模拟真人节奏刷小红书（随机滚动/鼠标移动，防风控） |

---

## 典型用法

```js
const { connectDailyChrome, safeDisconnect, findPage } = require('./connect_browser.js');

(async () => {
  const browser = await connectDailyChrome();   // 自动连接+处理授权
  const page = await findPage(browser, 'example.com');
  // ... 操作 page ...
  await safeDisconnect(browser);
})();
```

---

## 约定

- 只连接用户**已有的日常 Chrome**，不启动/重启/替换 Chrome。
- 自动化操作要模拟真人节奏（随机间隔、滚动、鼠标轨迹），避免触发风控。
- 清理标签页时只关"本流程打开的"，绝不关闭用户原有标签。
