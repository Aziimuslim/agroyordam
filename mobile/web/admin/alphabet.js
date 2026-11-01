/* Admin paneldagi o'zbekcha matnni yangi lotin harflarida ko'rsatish: oʻ → ö, gʻ → ğ, sh → ş, ch → ç.
 * Faqat ko'rinadigan matn va placeholder/title/aria-label o'zgaradi; input qiymati, havola, kod, CSS klasslari va
 * API'ga yuboriladigan ma'lumot o'zgarmaydi. Qoidalar backend/app/core/alphabet.py va mobile translit.dart bilan bir xil. */
'use strict';
(() => {
  const KEEP = new Set(['agroyordam', 'payme', 'click', 'telegram', 'whatsapp', 'google', 'chrome', 'android', 'iphone', 'push',
    'fastapi', 'plantvillage', 'wi-fi', 'flash', 'dashboard', 'chat', 'check', 'match', 'sha', 'hash', 'cherry', 'peach', 'scorch',
    'squash', 'trichoderma', 'cichoracearum', 'chrysanthemi', 'sclerotiorum', 'fusarium', 'erysiphe', 'pseudomonas', 'xanthomonas',
    'csv', 'json', 'html', 'cpu', 'ssh']);
  const APOS = "'ʻʼ‘’`";
  const SKIP = /(https?:\/\/\S+|www\.\S+|[\w.+-]+@[\w-]+\.[\w.]+|\{\d+\}|@\w+)/;
  const WORD = /[A-Za-zÖöĞğŞşÇç'ʻʼ‘’`-]+/g;
  const SCI = /(ph|th|rh|aceae|ae$)/i;
  const HAS_APOS = /['ʻʼ‘’`]/;

  function word(w) {
    const lw = w.toLowerCase().replace(/^-+|-+$/g, '');
    const base = lw.replace(/['ʻʼ‘’`].*$/, '');
    if (KEEP.has(lw) || KEEP.has(base)) return w;
    if ((lw.includes('ch') || lw.includes('sh')) && SCI.test(lw) && !HAS_APOS.test(lw) && lw !== 'shira') return w;
    const up = w.length > 1 && w.toUpperCase() === w && /[A-Za-z]/.test(w);
    let out = '';
    for (let i = 0; i < w.length; i++) {
      const c = w[i], nx = w[i + 1] || '', lc = c.toLowerCase(), isUp = c !== lc;
      if ((lc === 'o' || lc === 'g') && nx && APOS.includes(nx)) { out += lc === 'o' ? (isUp ? 'Ö' : 'ö') : (isUp ? 'Ğ' : 'ğ'); i++; continue; }
      if ((lc === 's' || lc === 'c') && nx.toLowerCase() === 'h') { out += lc === 's' ? (isUp ? 'Ş' : 'ş') : (isUp ? 'Ç' : 'ç'); i++; continue; }
      out += c;
    }
    return up ? out.toUpperCase() : out;
  }
  function toNewLatin(s) {
    if (!s) return s;
    s = s.replace(/ó/g, 'ö').replace(/Ó/g, 'Ö').replace(/ǵ/g, 'ğ').replace(/Ǵ/g, 'Ğ'); // eski xato harflar
    if (!/[A-Za-z]/.test(s)) return s;
    return s.split(SKIP).map((part, k) => (k % 2 ? part : part.replace(WORD, word))).join('');
  }
  window.toNewLatin = toNewLatin;

  const NO = new Set(['SCRIPT', 'STYLE', 'CODE', 'PRE', 'TEXTAREA', 'INPUT', 'SELECT']);
  const ATTRS = ['placeholder', 'title', 'aria-label'];
  const skip = el => !el || NO.has(el.tagName) || el.closest('[data-raw],[contenteditable="true"]');
  function text(n) {
    if (skip(n.parentElement)) return;
    const v = toNewLatin(n.nodeValue);
    if (v !== n.nodeValue) n.nodeValue = v;
  }
  function attrs(el) {
    for (const a of ATTRS) {
      const v = el.getAttribute && el.getAttribute(a);
      if (v) { const nv = toNewLatin(v); if (nv !== v) el.setAttribute(a, nv); }
    }
  }
  function walk(root) {
    if (root.nodeType === 3) { text(root); return; }
    if (root.nodeType !== 1) return;
    if (NO.has(root.tagName)) { if (root.tagName === 'INPUT' || root.tagName === 'TEXTAREA') attrs(root); return; }
    if (root.closest('[data-raw],[contenteditable="true"]')) return;
    attrs(root);
    const it = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    for (let n = it.nextNode(); n; n = it.nextNode()) n.nodeType === 3 ? text(n) : attrs(n);
  }
  const fixTitle = () => { const t = toNewLatin(document.title); if (t !== document.title) document.title = t; };
  const obs = new MutationObserver(ms => {
    for (const m of ms) {
      if (m.type === 'characterData') text(m.target);
      else if (m.type === 'attributes') attrs(m.target);
      else m.addedNodes.forEach(walk);
    }
    fixTitle();
  });
  const go = () => {
    walk(document.body); fixTitle();
    obs.observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS });
  };
  if (document.body) go(); else document.addEventListener('DOMContentLoaded', go);
})();
