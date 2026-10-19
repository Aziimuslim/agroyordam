// QA crawler: har route × o'lcham × mavzu; konsoldagi Flutter xatolari (overflow, exception) yig'iladi.
const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
const fs = require('fs'); const sleep = ms => new Promise(r => setTimeout(r, ms));
const ids = JSON.parse(fs.readFileSync(process.env.IDS || __dirname + '/ids.json'));
const BASE = process.env.BASE || 'http://127.0.0.1:8090';
const OUT = (process.env.OUT || __dirname + '/out') + '/';
fs.mkdirSync(OUT, { recursive: true });
const ROUTES = [
  ['S01', '/home'], ['S02', '/garden'], ['S03', '/diagnose'], ['S04', `/garden/${ids.crop}/care`], ['S05', '/garden/add'],
  ['S06', `/garden/${ids.crop}`], ['S06d', `/garden/${ids.crop}?tab=diary`], ['S07', '/diagnoses'], ['S08', `/diagnosis/${ids.diag}`],
  ['S09', '/help?tab=ai'], ['S10', '/assistant'], ['S11', '/help?tab=comm'], ['S12', '/community/new'], ['S13', `/community/${ids.post}`],
  ['S14', `/users/${ids.author}`], ['S15', '/messages'], ['S16', `/messages/${ids.conv}`], ['S17', '/catalog'], ['S18', '/catalog?tab=diseases'],
  ['S19', '/catalog?tab=medicines'], ['S20', `/catalog/plant/${ids.plant}`], ['S21', `/catalog/disease/${ids.disease}`], ['S22', `/catalog/medicine/${ids.medicine}`],
  ['S23', '/profile'], ['S24', '/profile/edit'], ['S25', '/reminders'], ['S26', '/reminders/add'], ['S27', '/notifications'], ['S28', '/profile/password'],
  ['S29', '/premium'], ['S30', '/premium/payments'], ['S31', '/settings/appearance'], ['S32', '/settings/language'],
  ['A02', '/saved'], ['A04', `/garden/${ids.crop}/log`], ['A05', '/settings/about'], ['A05n', '/settings/notifications'], ['A06', '/weather'],
  ['A07', '/users/search'], ['A08', '/settings/blocked'], ['H', '/help'],
];
const AUTH = [['S33', '/auth/login'], ['S34', '/auth/register'], ['S35', '/auth/verify'], ['S36', '/auth/recovery'], ['W', '/welcome']];
const ONLY = process.env.ONLY ? process.env.ONLY.split(',') : null; // masalan ONLY=S12,S13,S15,S16
const SIZES = (process.env.SIZES || '320,390,768,1440').split(',').map(Number);
const SCHEMES = (process.env.SCHEMES || 'light,dark').split(',');
const SCALE = Number(process.env.SCALE || 1); // 2 — 200% matn (brauzer shrift o'lchami)
const go = (p, u) => p.evaluate(u => { history.pushState({}, '', u); dispatchEvent(new PopStateEvent('popstate')); }, u);
(async () => {
  const b = await chromium.launch();
  const report = [];
  for (const scheme of SCHEMES) {
    const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, colorScheme: scheme });
    const p = await ctx.newPage();
    let errs = [];
    p.on('console', m => { const t = m.text(); if (/overflowed|EXCEPTION CAUGHT|Assertion failed|was not laid out|Unexpected null|RenderBox|setState\(\) or markNeedsBuild/i.test(t)) errs.push(t.split('\n').slice(0, 3).join(' | ').slice(0, 300)); });
    p.on('pageerror', e => errs.push('pageerror: ' + e.message.slice(0, 200)));
    if (process.env.LANG_CODE) await p.addInitScript(l => localStorage.setItem('flutter.agro_lang', JSON.stringify(l)), process.env.LANG_CODE);
    if (SCALE !== 1) await p.addInitScript(s => { document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = (16 * s) + 'px'; }); }, SCALE);
    // sessiyasiz ekranlar
    await p.goto(BASE + '/welcome');
    await p.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 120000 }); await sleep(1500);
    await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await sleep(1500);
    for (const w of SIZES) {
      await p.setViewportSize({ width: w, height: w >= 768 ? 900 : 760 });
      for (const [id, r] of AUTH.filter(([id]) => !ONLY || ONLY.includes(id))) {
        errs = []; await go(p, r); await sleep(1500);
        if (w === 320 || w === 1440) await p.screenshot({ path: `${OUT}${id}_${w}_${scheme}${SCALE !== 1 ? '_x' + SCALE : ''}${process.env.LANG_CODE ? '_' + process.env.LANG_CODE : ''}.png` });
        report.push({ id, r, w, scheme, scale: SCALE, errs: [...new Set(errs)] });
      }
    }
    // kirish
    await p.setViewportSize({ width: 390, height: 844 });
    await go(p, '/auth/login?via=email'); await sleep(1500);
    for (const [i, v] of [[0, 'akmal'], [1, 'Secret123!']]) { const tb = p.getByRole('textbox').nth(i); await tb.click(); await sleep(400); await p.keyboard.type(v, { delay: 20 }); }
    await p.keyboard.press('Enter'); await sleep(6000);
    for (const w of SIZES) {
      await p.setViewportSize({ width: w, height: w >= 768 ? 900 : 760 });
      for (const [id, r] of ROUTES.filter(([id]) => !ONLY || ONLY.includes(id))) {
        errs = []; await go(p, r); await sleep(2200);
        if (w === 320 || w === 1440) await p.screenshot({ path: `${OUT}${id}_${w}_${scheme}${SCALE !== 1 ? '_x' + SCALE : ''}${process.env.LANG_CODE ? '_' + process.env.LANG_CODE : ''}.png` });
        report.push({ id, r, w, scheme, scale: SCALE, errs: [...new Set(errs)] });
      }
    }
    await ctx.close();
  }
  await b.close();
  const bad = report.filter(x => x.errs.length);
  fs.writeFileSync(`${OUT}report_${SCALE}_${SCHEMES.join('-')}_${process.env.LANG_CODE || 'uz'}.json`, JSON.stringify(report, null, 1));
  console.log('checks', report.length, 'with errors', bad.length);
  for (const x of bad) console.log(x.id, x.w, x.scheme, x.scale, '\n   ', x.errs.slice(0, 2).join('\n    '));
})();
