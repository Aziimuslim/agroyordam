// QA02, QA04, QA13, QA14 — oqim sinovlari (release build, :8080)
const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
const fs = require('fs');
fs.mkdirSync(process.env.OUT || __dirname + '/out', { recursive: true }); const sleep = ms => new Promise(r => setTimeout(r, ms));
const ids = JSON.parse(fs.readFileSync(process.env.IDS || __dirname + '/ids.json'));
const BASE = process.env.BASE || 'http://localhost:8080';
const results = [];
const check = (id, name, ok, actual) => { results.push({ id, name, ok, actual }); console.log(ok ? 'PASS' : 'FAIL', id, name, '—', actual); };
const path = p => new URL(p.url()).pathname + new URL(p.url()).search;
async function sem(p) { await p.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 60000 }).catch(() => {}); await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await sleep(800); }
async function typeIn(p, i, v) { const tb = p.getByRole('textbox').nth(i); await tb.click(); await sleep(400); await p.keyboard.type(v, { delay: 20 }); }
async function login(p) { await typeIn(p, 0, 'akmal'); await typeIn(p, 1, 'Secret123!'); await p.keyboard.press('Enter'); await sleep(5000); }
(async () => {
  const b = await chromium.launch();
  // QA02 returnTo
  {
    const p = await (await b.newContext({ viewport: { width: 390, height: 844 } })).newPage();
    await p.goto(`${BASE}/garden/${ids.crop}?tab=diary`); await sleep(6000); await sem(p);
    check('QA02', 'Sessiyasiz shaxsiy havola → kirish sahifasi', path(p).startsWith('/welcome'), path(p));
    await p.getByRole('button', { name: 'Email bilan davom etish' }).click(); await sleep(1500);
    await p.getByRole('button', { name: 'Email', exact: true }).click().catch(() => {}); await sleep(500);
    await login(p);
    check('QA02', "Kirgach so'ralgan sahifaga qaytadi", path(p) === `/garden/${ids.crop}?tab=diary`, path(p));
    // QA04 Back/Forward + query saqlanishi
    await p.goto(`${BASE}/catalog?tab=diseases`); await sleep(5000); await sem(p);
    await p.evaluate(u => { history.pushState({}, '', u); dispatchEvent(new PopStateEvent('popstate')); }, `/catalog/disease/${ids.disease}`); await sleep(2000);
    await p.goBack(); await sleep(2000);
    check('QA04', 'Brauzer Back: tab query saqlanadi', path(p) === '/catalog?tab=diseases', path(p));
    await p.goForward(); await sleep(2000);
    check('QA04', 'Brauzer Forward buzilmaydi', path(p) === `/catalog/disease/${ids.disease}`, path(p));
    // QA13 logoutdan keyin Back
    await p.evaluate(u => { history.pushState({}, '', u); dispatchEvent(new PopStateEvent('popstate')); }, '/profile'); await sleep(2500);
    await p.mouse.wheel(0, 3000); await sleep(800);
    await p.getByRole('button', { name: 'Chiqish' }).first().click(); await sleep(800);
    await p.getByRole('button', { name: 'Chiqish' }).last().click(); await sleep(3000);
    check('QA13', 'Chiqish → kirish sahifasi', path(p).startsWith('/welcome'), path(p));
    await p.goBack(); await sleep(2500);
    check('QA13', "Chiqishdan keyin Back shaxsiy sahifani ochmaydi", !/\/profile|\/catalog\/disease/.test(path(p)) || (await p.getByRole('button', { name: 'Email bilan davom etish' }).count()) > 0, path(p));
    await p.context().close();
  }
  // QA14 faqat klaviatura bilan kirish
  {
    const p = await (await b.newContext({ viewport: { width: 1280, height: 900 } })).newPage();
    await p.goto(`${BASE}/auth/login?via=email`); await sleep(6000); await sem(p);
    await p.keyboard.press('Tab'); await sleep(300);
    let guard = 0; // birinchi matn maydonigacha Tab
    while (guard++ < 15 && !(await p.evaluate(() => document.activeElement && ['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)))) { await p.keyboard.press('Tab'); await sleep(250); }
    await p.keyboard.type('akmal', { delay: 20 }); await p.keyboard.press('Tab'); await sleep(300);
    await p.keyboard.type('Secret123!', { delay: 20 }); await p.keyboard.press('Enter'); await sleep(5000);
    check('QA14', 'Login faqat klaviatura (Tab/Enter) bilan', path(p) === '/home', path(p));
    await p.context().close();
  }
  await b.close();
  fs.writeFileSync((process.env.OUT || __dirname + '/out') + '/flows.json', JSON.stringify(results, null, 1));
})();
