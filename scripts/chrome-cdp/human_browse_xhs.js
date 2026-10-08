/**
 * human_browse_xhs.js — 人味刷小红书
 * 用 connectDailyChrome() 自动处理授权弹窗，模拟真人节奏浏览
 */
const { connectDailyChrome, safeDisconnect, findPage } = require('./connect_browser.js');

const sleep = (min, max) => new Promise(r => setTimeout(r, Math.floor(Math.random() * (max - min) + min)));

async function humanScroll(page, times = 3) {
  for (let i = 0; i < times; i++) {
    await page.mouse.wheel({ deltaY: Math.floor(Math.random() * 300) + 200 });
    await sleep(2500, 5000);
  }
}

async function humanMouse(page) {
  await page.mouse.move(Math.floor(Math.random() * 800) + 100, Math.floor(Math.random() * 600) + 100, { steps: 10 });
}

(async () => {
  const browser = await connectDailyChrome();
  console.log('已连接 Chrome');

  // 找小红书标签
  let page = await findPage(browser, 'xiaohongshu.com');
  if (!page) {
    page = await browser.newPage();
  }

  // 1. 先停在首页像真人
  console.log('浏览首页...');
  await page.goto('https://www.xiaohongshu.com/explore', { waitUntil: 'domcontentloaded', timeout: 20000 });
  await sleep(5000, 8000);
  await humanScroll(page, 2);
  await humanMouse(page);
  await sleep(3000, 5000);

  // 2. 搜索
  console.log('搜索翡翠手镯怎么选...');
  await page.goto('https://www.xiaohongshu.com/search_result?keyword=翡翠手镯怎么选&type=51', { waitUntil: 'domcontentloaded', timeout: 20000 });
  await sleep(4000, 7000);
  await humanScroll(page, 3);
  await humanMouse(page);
  await sleep(3000, 5000);

  // 3. 提取
  const results = await page.evaluate(() => {
    const items = [];
    document.querySelectorAll('section.note-item').forEach((el, i) => {
      if (i >= 10) return;
      items.push({
        title: el.querySelector('.title')?.textContent?.trim() || '',
        author: el.querySelector('.author .name')?.textContent?.trim() || '',
        likes: el.querySelector('.like-wrapper .count')?.textContent?.trim() || ''
      });
    });
    return items;
  });
  console.log(JSON.stringify(results, null, 2));

  await safeDisconnect(browser);
  console.log('完成');
})();
