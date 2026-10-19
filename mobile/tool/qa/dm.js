const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
const fs = require('fs');
fs.mkdirSync(process.env.OUT || __dirname + '/out', { recursive: true }); const sleep = ms => new Promise(r => setTimeout(r, ms));
const BASE = process.env.BASE || 'http://localhost:8080';
const out = [];
async function bgAt(p, ms) { await sleep(ms); return p.evaluate(() => getComputedStyle(document.documentElement).backgroundColor + ' / ' + getComputedStyle(document.body).backgroundColor); }
(async () => {
  const b = await chromium.launch();
  for (const [scheme, saved, want] of [['dark', null, 'rgb(16, 25, 18)'], ['light', null, 'rgb(251, 246, 234)'], ['light', 'dark', 'rgb(16, 25, 18)'], ['dark', 'light', 'rgb(251, 246, 234)']]) {
    const ctx = await b.newContext({ colorScheme: scheme, viewport: { width: 390, height: 844 } });
    if (saved) await ctx.addInitScript(v => localStorage.setItem('flutter.agro_theme_mode', JSON.stringify(v)), saved);
    const p = await ctx.newPage();
    await p.goto(BASE + '/welcome', { waitUntil: 'commit' });
    const early = await bgAt(p, 150);
    await sleep(6000);
    // Flutter chizgan birinchi kadr: kanvasdagi markaziy piksel o'rniga skrinshotdan burchak rangi
    const buf = await p.screenshot({ clip: { x: 2, y: 840, width: 1, height: 1 } });
    out.push({ scheme, saved, early, want, ok: early.startsWith(want) });
    console.log(early.startsWith(want) ? 'PASS' : 'FAIL', 'DM01/02', `tizim=${scheme} tanlov=${saved}`, early);
    await ctx.close();
  }
  await b.close();
  fs.writeFileSync((process.env.OUT || __dirname + '/out') + '/dm.json', JSON.stringify(out, null, 1));
})();
