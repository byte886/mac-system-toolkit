/**
 * tab_hygiene.js — 关闭「本流程产生」的标签页，保持 Chrome 整洁
 *
 * 规则（安全第一）：
 *   - 只关闭 URL 命中给定模式的标签；不匹配的用户标签一律不动；
 *   - 典型用法：开启新工作页前，按工作页 URL 特征清理上轮残留；收工时关闭本轮打开的页；
 *   - 至少保留一个标签（Chrome 不允许最后一个标签关闭，会变成新标签页，无需特殊处理）。
 *
 * CLI：
 *   node tab_hygiene.js <URL包含串1> [包含串2 ...]
 *   例：node tab_hygiene.js "act=Display/image"
 *
 * 库：
 *   const { closeTabsByUrl } = require('./tab_hygiene');
 *   const closed = await closeTabsByUrl(browser, ['act=Display/image']);
 */
'use strict';

async function closeTabsByUrl(browser, patterns) {
  const pages = await browser.pages();
  let closed = 0;
  for (const p of pages) {
    let u = '';
    try { u = p.url(); } catch { continue; }
    if (patterns.some((s) => u.includes(s))) {
      try { await p.close(); closed += 1; } catch { /* 目标页受保护则忽略 */ }
    }
  }
  return closed;
}

module.exports = { closeTabsByUrl };

if (require.main === module) {
  (async () => {
    const patterns = process.argv.slice(2);
    if (!patterns.length) {
      console.error('用法: node tab_hygiene.js <URL包含串1> [包含串2 ...]');
      process.exit(1);
    }
    const { connectDailyChrome, safeDisconnect } = require('./connect_browser');
    const browser = await connectDailyChrome({ ensureRunning: false });
    try {
      const n = await closeTabsByUrl(browser, patterns);
      console.log(`closed ${n} tab(s)`);
    } finally {
      await safeDisconnect(browser);
    }
  })().catch((e) => { console.error(e); process.exit(1); });
}
