// SVG → PNG (Chromium + Playwright): node tool/brand/render.js '[["kirish.svg","chiqish.png",512], ...]'
const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
const fs = require('fs');
(async () => {
  const jobs = JSON.parse(process.argv[2]);
  const b = await chromium.launch();
  const p = await b.newPage();
  for (const [svg, png, size] of jobs) {
    const data = 'data:image/svg+xml;base64,' + fs.readFileSync(svg).toString('base64');
    await p.setViewportSize({ width: size, height: size });
    await p.setContent(`<html><body style="margin:0;background:transparent"><img src="${data}" style="width:${size}px;height:${size}px;display:block"></body></html>`);
    await p.waitForTimeout(150);
    await p.screenshot({ path: png, omitBackground: true });
  }
  await b.close();
})();
