// يحوّل ملفات الصفوة (Markdown→HTML جاهز) إلى PDF بمقاس A4
const { chromium } = require('playwright');
const fs = require('fs'), cp = require('child_process');
(async () => {
  const files = process.argv.slice(2);
  const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
  const ctx = await b.newContext(); const cache = {};
  await ctx.route(/fonts\.(googleapis|gstatic)\.com/, r => { const u = r.request().url();
    if (!cache[u]) cache[u] = cp.execFileSync('curl', ['-sS', '-A', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36', u]);
    r.fulfill({status:200, body:cache[u], headers:{'content-type': u.includes('googleapis') ? 'text/css' : 'font/woff2', 'access-control-allow-origin':'*'}}); });
  for (const f of files) {
    const p = await ctx.newPage();
    await p.goto('file://' + f); await p.waitForTimeout(1500);
    const out = f.replace(/\.html$/, '.pdf');
    await p.pdf({path: out, format: 'A4', printBackground: true, margin: {top:'14mm', bottom:'14mm', left:'13mm', right:'13mm'},
      displayHeaderFooter: true, headerTemplate: '<span></span>',
      footerTemplate: '<div style="width:100%;font-size:8px;color:#777;text-align:center;font-family:sans-serif"><span class="pageNumber"></span> / <span class="totalPages"></span></div>'});
    console.log(out); await p.close();
  }
  await b.close();
})();
