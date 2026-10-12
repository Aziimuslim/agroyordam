/* AgroYordam admin paneli (/admin) — faqat kompyuter uchun.
 * Ilova bilan bir xil API (/api/v1/admin/...), kirish — admin yoki moderator hisobi.
 * Lokal sinov: /admin/?api=http://localhost:8000 (manzil sessiya davomida eslab qolinadi). */
'use strict';
(() => {
  const qs = new URLSearchParams(location.search);
  if (qs.get('api')) sessionStorage.setItem('agro_api', qs.get('api'));
  const API = (sessionStorage.getItem('agro_api') || '').replace(/\/$/, '');
  const media = u => (!u ? null : /^https?:/.test(u) ? u : API + u);

  // Ilova ichidagi PlantVillage rasmlari (mobile/assets/catalog) — Flutter build'da /assets/assets/catalog/
  const KNOWN = new Set(['Apple_Black_rot', 'Apple_Cedar_rust', 'Apple_Scab', 'Apple_healthy', 'Cherry_Powdery_mildew', 'Cherry_healthy',
    'Corn_Common_rust', 'Corn_Gray_leaf_spot', 'Corn_Northern_Leaf_Blight', 'Corn_healthy', 'Grape_Black_rot', 'Grape_Esca',
    'Grape_Leaf_blight', 'Grape_healthy', 'Peach_Bacterial_spot', 'Peach_healthy', 'Pepper_Bacterial_spot', 'Pepper_healthy',
    'Potato_Early_blight', 'Potato_Late_blight', 'Potato_healthy', 'Squash_Powdery_mildew', 'Strawberry_Leaf_scorch',
    'Strawberry_healthy', 'Tomato_Bacterial_spot', 'Tomato_Early_blight', 'Tomato_Late_blight', 'Tomato_Leaf_Mold',
    'Tomato_Septoria_leaf_spot', 'Tomato_Spider_mites', 'Tomato_Target_Spot', 'Tomato_Yellow_Leaf_Curl_Virus', 'Tomato_healthy',
    'Tomato_mosaic_virus']);
  const catImg = l => (l && KNOWN.has(l) ? `/assets/assets/catalog/${l}.jpg` : null);

  // ---------- Yordamchilar ----------
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const fmt = n => Number(n || 0).toLocaleString('ru-RU').replace(/ /g, ' ');
  const money = n => (n >= 1e6 ? (n / 1e6).toFixed(1).replace('.', ',') + ' mln' : fmt(Math.round(n)));
  const parseTs = s => (s ? new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(s) ? s : s + 'Z') : null);
  const MON = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
  const dayLbl = iso => { const d = new Date(iso + 'T00:00:00'); return d.getDate() + '-' + MON[d.getMonth()]; };
  const fmtDate = s => { const d = parseTs(s); return d ? d.toLocaleDateString('ru-RU') : '—'; };
  const ago = s => {
    const d = parseTs(s); if (!d) return '—';
    const m = Math.round((Date.now() - d) / 60000);
    if (m < 1) return 'hozir'; if (m < 60) return m + ' daqiqa oldin';
    if (m < 1440) return Math.round(m / 60) + ' soat oldin'; if (m < 2880) return 'kecha';
    return d.toLocaleDateString('ru-RU');
  };
  const wait = m => (m == null ? '—' : m < 60 ? m + ' daq' : m < 1440 ? Math.round(m / 60) + ' soat' : Math.round(m / 1440) + ' kun');
  const initials = n => esc(String(n || '?').split(/\s+/).map(x => x[0] || '').join('').slice(0, 2).toUpperCase());
  const delta = (cur, prev) => (prev ? Math.round((cur / prev - 1) * 100) : null);

  const P = {
    dash: '<path d="M4 13h6V4H4zM14 20h6v-9h-6zM4 20h6v-4H4zM14 4v4h6V4z"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c1-3.5 3.5-5 6.5-5s5.5 1.5 6.5 5"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 15c2 .6 3.2 2.2 3.8 5"/>',
    shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/>',
    ai: '<rect x="4" y="8" width="16" height="11" rx="3"/><path d="M12 4v4M9 13v.01M15 13v.01"/>',
    book: '<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M5 17a3 3 0 0 1 3-3h11"/>',
    flag: '<path d="M5 21V4h11l-2 4 2 4H5"/>', card: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 10h18M7 15h4"/>',
    server: '<rect x="4" y="4" width="16" height="7" rx="2"/><rect x="4" y="13" width="16" height="7" rx="2"/><path d="M8 7.5v.01M8 16.5v.01"/>',
    leaf: '<path d="M5 19c8 0 14-6 14-14-8 0-14 6-14 14z"/><path d="M5 19l7-7"/>', search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7"/>', x: '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>',
    alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.5v.01"/>', info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.01"/>',
    up: '<path d="M7 14l5-5 5 5"/>', down: '<path d="M7 10l5 5 5-5"/>', arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    db: '<ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v12c0 1.7 3 3 7 3s7-1.3 7-3V6M5 12c0 1.7 3 3 7 3s7-1.3 7-3"/>',
    refresh: '<path d="M20 11a8 8 0 0 0-14.5-4.5L4 8M4 4v4h4M4 13a8 8 0 0 0 14.5 4.5L20 16M20 20v-4h-4"/>',
    send: '<path d="M4 12l16-8-6 16-3-7z"/>', download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    table: '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 10h16M10 4v16"/>', chart: '<path d="M4 20V4M4 20h16M8 16l4-5 3 3 5-6"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
    auto: '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v17a8.5 8.5 0 0 0 0-17z" fill="currentColor"/>',
    logout: '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3"/><path d="M10 17l-5-5 5-5M5 12h11"/>',
    image: '<rect x="4" y="5" width="16" height="14" rx="2"/><circle cx="9" cy="10" r="1.5"/><path d="M20 16l-5-5-8 8"/>',
  };
  const I = (n, c = 'ico') => `<svg class="${c}" viewBox="0 0 24 24" aria-hidden="true">${P[n]}</svg>`;
  const tag = (c, i, t) => `<span class="tag ${c}">${i ? I(i, 'ico s') : ''}${esc(t)}</span>`;
  const thumb = (src, title = '') => (src ? `<img class="thumb" src="${esc(src)}" alt="${esc(title)}" loading="lazy">`
    : `<span class="thumb ph" title="Rasm yo'q">${I('image', 'ico s')}</span>`);
  const RISK = { high: ['t-bad', 'x', 'Yuqori'], medium: ['t-risk', 'alert', "O'rta"], low: ['t-info', 'info', 'Past'] };
  const ROLES = { user: ['t-brand', 'Dehqon'], agronomist: ['t-exp', 'Agronom'], moderator: ['t-info', 'Moderator'], admin: ['t-neu', 'Admin'] };

  // ---------- Mavzu: yorug' / qorong'i / tizimga qarab (brauzerda eslab qolinadi) ----------
  const THEME_KEY = 'agro_admin_theme';
  const getTheme = () => { try { return localStorage.getItem(THEME_KEY) || 'system'; } catch { return 'system'; } };
  function applyTheme(t) {
    if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t; else delete document.documentElement.dataset.theme;
  }
  function setTheme(t) {
    try { localStorage.setItem(THEME_KEY, t); } catch { /* maxfiy rejim — faqat shu sessiya */ }
    applyTheme(t);
    document.querySelectorAll('.themes button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.v === t)));
    hideTip(); if (S.me) paint(); // grafiklar yangi ranglar bilan
  }
  applyTheme(getTheme());
  const themeSwitch = () => `<div class="themes" role="group" aria-label="Mavzu">${[['light', 'sun', "Yorug'"], ['dark', 'moon', "Qorong'i"], ['system', 'auto', 'Tizimga qarab']]
    .map(([v, ic, t]) => `<button type="button" data-act="theme" data-v="${v}" aria-pressed="${getTheme() === v}" title="${t}" aria-label="${t}">${I(ic, 'ico s')}</button>`).join('')}</div>`;

  // ---------- API ----------
  const store = {
    get at() { return sessionStorage.getItem('agro_at'); }, get rt() { return sessionStorage.getItem('agro_rt'); },
    set(t) { sessionStorage.setItem('agro_at', t.access_token); sessionStorage.setItem('agro_rt', t.refresh_token); },
    clear() { sessionStorage.removeItem('agro_at'); sessionStorage.removeItem('agro_rt'); },
  };
  class ApiError extends Error { constructor(msg, code) { super(msg); this.code = code; } }
  async function raw(path, { method = 'GET', body, auth = true } = {}) {
    const headers = { Accept: 'application/json' };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (auth && store.at) headers.Authorization = 'Bearer ' + store.at;
    let r;
    try { r = await fetch(API + '/api/v1' + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) }); }
    catch { throw new ApiError("Server bilan aloqa yo'q. Internetni tekshiring.", 0); }
    if (r.status === 204) return null;
    const data = await r.json().catch(() => null);
    if (!r.ok) {
      const d = data && data.detail;
      const msg = typeof d === 'string' ? d : Array.isArray(d) ? d.map(x => x.msg).join('; ') : `Xato (${r.status})`;
      throw new ApiError(r.status === 403 && msg === "Ruxsat yo'q" ? "Ruxsat yo'q: bu amalni faqat admin bajara oladi" : msg, r.status);
    }
    return data;
  }
  let refreshing = null;
  async function api(path, opts) {
    try { return await raw(path, opts); }
    catch (e) {
      if (e.code !== 401 || !store.rt) throw e;
      refreshing ??= raw('/auth/refresh', { method: 'POST', body: { refresh_token: store.rt }, auth: false })
        .then(t => store.set(t)).finally(() => { refreshing = null; });
      try { await refreshing; } catch { store.clear(); showLogin('Sessiya tugadi. Qayta kiring.'); throw e; }
      return raw(path, opts);
    }
  }

  // ---------- Grafiklar (bitta seriya, brend rangi; tooltip textContent orqali) ----------
  const tip = document.getElementById('tip');
  function showTip(host, x, y, val, lab) {
    tip.hidden = false; tip.replaceChildren();
    const b = document.createElement('b'); b.textContent = val;
    const k = document.createElement('div'); k.className = 'k';
    const i = document.createElement('i'); k.append(i, document.createTextNode(lab)); tip.append(b, k);
    const r = host.getBoundingClientRect();
    tip.style.left = (r.left + x + window.scrollX) + 'px'; tip.style.top = (r.top + y + window.scrollY) + 'px';
  }
  const hideTip = () => { tip.hidden = true; };
  function niceMax(v) { if (!(v > 0)) return 4; const p = Math.pow(10, Math.floor(Math.log10(v))); return [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10].find(m => m * p >= v) * p; }
  const axisN = t => (t >= 1000 ? (t / 1000) + 'K' : (Math.round(t * 10) / 10));
  function areaChart(el, vals, labels, unit) {
    const W = 640, H = 220, L = 40, R = 16, T = 14, B = 26; const max = niceMax(Math.max(...vals) * 1.1); const n = vals.length;
    const x = i => L + (W - L - R) * i / (n - 1), y = v => T + (H - T - B) * (1 - v / max);
    const pts = vals.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
    const xt = [0, Math.floor((n - 1) / 2), n - 1];
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(unit)}">${[0, max / 2, max].map(t => `<line class="gl" x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}"/><text class="ax" x="${L - 8}" y="${y(t) + 4}" text-anchor="end">${axisN(t)}</text>`).join('')}
     ${xt.map(i => `<text class="ax" x="${x(i)}" y="${H - 6}" text-anchor="${i === 0 ? 'start' : i === n - 1 ? 'end' : 'middle'}">${esc(labels[i])}</text>`).join('')}
     <polygon class="ar" points="${x(0)},${y(0)} ${pts} ${x(n - 1)},${y(0)}"/><polyline class="ln" points="${pts}"/>
     <circle class="dot" cx="${x(n - 1)}" cy="${y(vals[n - 1])}" r="4.5"/><text class="lab" x="${x(n - 1) - 8}" y="${y(vals[n - 1]) - 10}" text-anchor="end">${fmt(vals[n - 1])}</text>
     <line class="xh" x1="0" x2="0" y1="${T}" y2="${H - B}" visibility="hidden"/><circle class="dot xd" r="4.5" visibility="hidden"/>
     <rect class="hit" x="${L}" y="${T}" width="${W - L - R}" height="${H - T - B}"/></svg>`;
    const svg = el.querySelector('svg'), hit = svg.querySelector('.hit'), xh = svg.querySelector('.xh'), xd = svg.querySelector('.xd');
    hit.addEventListener('pointermove', e => {
      const r = svg.getBoundingClientRect(); const sx = (e.clientX - r.left) * W / r.width;
      const i = Math.max(0, Math.min(n - 1, Math.round((sx - L) / (W - L - R) * (n - 1))));
      xh.setAttribute('x1', x(i)); xh.setAttribute('x2', x(i)); xh.setAttribute('visibility', 'visible');
      xd.setAttribute('cx', x(i)); xd.setAttribute('cy', y(vals[i])); xd.setAttribute('visibility', 'visible');
      showTip(svg, x(i) * r.width / W, y(vals[i]) * r.height / H, fmt(vals[i]), labels[i] + ' · ' + unit);
    });
    hit.addEventListener('pointerleave', () => { xh.setAttribute('visibility', 'hidden'); xd.setAttribute('visibility', 'hidden'); hideTip(); });
  }
  function hbars(el, data, unit, fmtv = fmt) {
    const W = 520, rowH = 30, L = 128, R = 56, H = data.length * rowH + 6; const max = niceMax(Math.max(...data.map(d => d[1]))); const w = v => (W - L - R) * v / max;
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(unit)}">${data.map(([k, v], i) => {
      const yy = i * rowH + 6, bw = Math.max(5, w(v)); return `<text class="cat" x="${L - 10}" y="${yy + 14}" text-anchor="end">${esc(k)}</text>
      <path class="bar" d="M${L},${yy} h${bw - 4} a4,4 0 0 1 4,4 v10 a4,4 0 0 1 -4,4 h-${bw - 4} z"/>
      <text class="lab" x="${L + bw + 8}" y="${yy + 13}">${esc(fmtv(v))}</text><rect class="hb" data-i="${i}" x="0" y="${yy - 4}" width="${W}" height="${rowH}" tabindex="0"/>`;
    }).join('')}</svg>`;
    const svg = el.querySelector('svg');
    svg.querySelectorAll('.hb').forEach(h => {
      const i = +h.dataset.i;
      const on = () => { svg.querySelectorAll('.bar').forEach((b, j) => b.classList.toggle('dim', j !== i)); const r = svg.getBoundingClientRect(); showTip(svg, (L + w(data[i][1]) / 2) * r.width / W, (i * rowH + 6) * r.height / H, fmtv(data[i][1]), data[i][0] + ' · ' + unit); };
      const off = () => { svg.querySelectorAll('.bar').forEach(b => b.classList.remove('dim')); hideTip(); };
      h.addEventListener('pointerenter', on); h.addEventListener('focus', on); h.addEventListener('pointerleave', off); h.addEventListener('blur', off);
    });
  }
  function columns(el, data, unit, fmtv) {
    const W = 520, H = 220, L = 44, R = 10, T = 20, B = 26; const max = niceMax(Math.max(...data.map(d => d[1])) * 1.1);
    const n = data.length, band = (W - L - R) / n, bw = Math.min(24, band * 0.5); const y = v => T + (H - T - B) * (1 - v / max);
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(unit)}">${[0, max / 2, max].map(t => `<line class="gl" x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}"/><text class="ax" x="${L - 8}" y="${y(t) + 4}" text-anchor="end">${axisN(t)}</text>`).join('')}
     ${data.map(([k, v], i) => {
      const cx = L + band * i + band / 2, top = y(v), h = y(0) - top;
      return `${h > 0 ? `<path class="bar" d="M${cx - bw / 2},${y(0)} v-${Math.max(0, h - 4)} a4,4 0 0 1 4,-4 h${bw - 8} a4,4 0 0 1 4,4 v${Math.max(0, h - 4)} z"/>` : ''}<text class="ax" x="${cx}" y="${H - 6}" text-anchor="middle">${esc(k)}</text>${i === n - 1 ? `<text class="lab" x="${cx}" y="${top - 8}" text-anchor="middle">${esc(fmtv(v))}</text>` : ''}<rect class="hb" data-i="${i}" x="${L + band * i}" y="${T}" width="${band}" height="${H - T - B}" tabindex="0"/>`;
    }).join('')}</svg>`;
    const svg = el.querySelector('svg');
    svg.querySelectorAll('.hb').forEach(h => {
      const i = +h.dataset.i;
      const on = () => { svg.querySelectorAll('.bar').forEach((b, j) => b.classList.toggle('dim', j !== i)); const r = svg.getBoundingClientRect(); showTip(svg, (L + band * i + band / 2) * r.width / W, y(data[i][1]) * r.height / H, fmtv(data[i][1]), data[i][0] + ' · ' + unit); };
      const off = () => { svg.querySelectorAll('.bar').forEach(b => b.classList.remove('dim')); hideTip(); };
      h.addEventListener('pointerenter', on); h.addEventListener('focus', on); h.addEventListener('pointerleave', off); h.addEventListener('blur', off);
    });
  }
  function spark(vals) {
    if (vals.length < 2) return '';
    const W = 100, H = 28, max = Math.max(...vals), min = Math.min(...vals);
    const pts = vals.map((v, i) => `${(i / (vals.length - 1) * W).toFixed(1)},${(H - 2 - (v - min) / (max - min || 1) * (H - 4)).toFixed(1)}`).join(' ');
    return `<svg viewBox="0 0 ${W} ${H}" style="width:100px;height:28px" aria-hidden="true"><polyline fill="none" stroke="var(--line-strong)" stroke-width="1.6" points="${pts}"/><circle cx="${W}" cy="${pts.split(' ').pop().split(',')[1]}" r="3" fill="var(--brand)"/></svg>`;
  }
  const tableView = (rows, h1, h2) => `<div class="tview" style="max-height:220px;overflow:auto"><table><thead><tr><th>${h1}</th><th class="n">${h2}</th></tr></thead><tbody>${rows.map(([a, b]) => `<tr><td>${esc(a)}</td><td class="n">${esc(b)}</td></tr>`).join('')}</tbody></table></div>`;
  const tvBtn = id => `<button class="btn ghost sm" data-act="tv" data-v="${id}" aria-pressed="${!!S.chartTable[id]}">${I(S.chartTable[id] ? 'chart' : 'table')}${S.chartTable[id] ? 'Grafik' : 'Jadval'}</button>`;
  const deltaTag = (d, unit = '%') => (d == null ? '<span class="d neu">oldingi davr yo\'q</span>'
    : `<span class="d ${d >= 0 ? 'up' : 'dn'}">${I(d >= 0 ? 'up' : 'down', 'ico s')}${d >= 0 ? '+' : ''}${d}${unit}</span>`);
  const meter = (v, warn = 80) => (v == null ? '<span class="muted">—</span>'
    : `<div class="row" style="flex-wrap:nowrap"><div class="meter ${v < warn ? 'risk' : ''}" style="width:90px"><i style="width:${v}%"></i></div><span class="num small">${v}%</span></div>`);

  // ---------- Holat ----------
  const S = { sec: 'dash', range: 30, uq: '', ur: 'all', chartTable: {}, data: {}, me: null, badges: {} };
  const head = (t, p, right = '') => `<div class="head"><div><h1>${esc(t)}</h1><p>${p}</p></div><div class="row">${right}</div></div>`;
  const SEC = {};

  // ---------- Boshqaruv paneli ----------
  SEC.dash = {
    label: 'Boshqaruv paneli', ic: 'dash',
    async load() { const d = await api(`/admin/dashboard?days=${S.range}`); S.badges = { agro: d.attention.applications, mod: d.attention.reports }; return d; },
    render(d) {
      const dv = d.diagnoses_daily.map(x => x.count), uv = d.users_daily.map(x => x.count), lbl = d.diagnoses_daily.map(x => dayLbl(x.date));
      const a = d.attention, alerts = [];
      if (a.applications) alerts.push(['t-exp', 'shield', `${a.applications} ta agronom arizasi`, a.oldest_application_hours != null ? (a.oldest_application_hours < 1 ? 'Bugun keldi' : `Eng eskisi ${wait(a.oldest_application_hours * 60)} kutmoqda`) : '', 'agro', "Ko'rish"]);
      if (a.questions_stale) alerts.push(['t-risk', 'clock', `${a.questions_stale} ta javobsiz savol`, '4 soatdan ortiq kutmoqda', 'agro', 'Agronomlar']);
      if (a.reports) alerts.push(['t-bad', 'flag', `${a.reports} ta yozuvga shikoyat`, 'Jamoatdagi post va izohlar', 'mod', "Ko'rish"]);
      if (a.queue) alerts.push(['t-info', 'ai', `${a.queue} ta tashxis dehqon so'rovi bilan`, 'Agronom tekshiruvini kutmoqda', 'ai', 'AI va dataset']);
      const b = a.backup || {};
      if (b.available) alerts.push(b.ok ? ['t-ok', 'db', `Zaxira: ${ago(b.last_ok)} ✓`, b.offsite ? 'Serverda va bulutda' : 'Faqat serverda', 'sys', 'Tizim']
        : ['t-bad', 'db', 'Zaxira muammosi', b.status || "Hali zaxira olinmagan", 'sys', 'Tizim']);
      const regTot = d.regions.reduce((s, r) => s + r.count, 0);
      return `${head('Boshqaruv paneli', 'Platforma bir qarashda: foydalanuvchilar, tashxislar, AI sifati va navbatdagi ishlar.')}
      <div class="filters"><div class="segm" role="group" aria-label="Davr">${[[7, '7 kun'], [30, '30 kun'], [90, '90 kun']].map(([k, t]) => `<button data-act="range" data-v="${k}" aria-pressed="${S.range === k}">${t}</button>`).join('')}</div><span class="muted small">Raqamlar tanlangan davr uchun, oldingi shunday davrga nisbatan</span></div>
      <div class="grid g4">
        <div class="card tile"><span class="l">Yangi foydalanuvchilar</span><span class="v num">${fmt(d.users_new)}</span><div class="row" style="justify-content:space-between">${deltaTag(delta(d.users_new, d.users_new_prev))}${spark(uv.slice(-14))}</div></div>
        <div class="card tile"><span class="l">AI tashxislar</span><span class="v num">${fmt(d.diagnoses)}</span><div class="row" style="justify-content:space-between">${deltaTag(delta(d.diagnoses, d.diagnoses_prev))}${spark(dv.slice(-14))}</div></div>
        <div class="card tile"><span class="l">AI va agronom mos kelishi</span><span class="v num">${d.ai_agreement == null ? '—' : d.ai_agreement + '%'}</span><div class="row" style="justify-content:space-between">${d.ai_agreement != null && d.ai_agreement_prev != null ? deltaTag(d.ai_agreement - d.ai_agreement_prev, ' punkt') : '<span class="d neu">&nbsp;</span>'}<span class="muted small">${fmt(d.reviewed)} tekshiruv</span></div></div>
        <div class="card tile"><span class="l">Premium foydalanuvchilar</span><span class="v num">${fmt(d.premium_active)}</span><div class="row" style="justify-content:space-between"><span class="d ${d.premium_new ? 'up' : 'neu'}">+${fmt(d.premium_new)} yangi</span>${d.payment_mode === 'sandbox' ? tag('t-risk', 'alert', 'Sinov rejimi') : ''}</div></div>
      </div>
      <div class="grid g21">
        <div class="card"><div class="ch"><div><h2>Kunlik AI tashxislar</h2><div class="sub">Oxirgi ${d.days} kun · jami ${fmt(d.diagnoses)}</div></div>${tvBtn('diag')}</div><div class="chart" id="c-diag">${S.chartTable.diag ? tableView(dv.map((v, i) => [lbl[i], fmt(v)]).reverse(), 'Kun', 'Tashxislar') : ''}</div></div>
        <div class="card"><div class="ch"><h2>Diqqat talab qiladi</h2></div>
          ${alerts.length ? alerts.map(([c, ic, t, s, go, btn]) => `<div class="alert"><span class="ic ${c}">${I(ic)}</span><div><b>${esc(t)}</b><div class="muted small">${esc(s)}</div></div><button class="btn out sm" data-go="${go}">${esc(btn)}</button></div>`).join('')
          : `<div class="banner b-ok">${I('check')}<p>Hammasi joyida — kutayotgan ish yo'q.</p><span></span></div>`}
        </div>
      </div>
      <div class="grid g2">
        <div class="card"><div class="ch"><div><h2>Foydalanuvchilar viloyatlar bo'yicha</h2><div class="sub">Jami ${fmt(regTot)}</div></div>${tvBtn('reg')}</div><div class="chart" id="c-reg">${S.chartTable.reg ? tableView(d.regions.map(r => [r.region, fmt(r.count)]), 'Viloyat', 'Foydalanuvchi') : ''}</div></div>
        <div class="card"><div class="ch"><div><h2>AI aniqligi ekinlar bo'yicha</h2><div class="sub">Agronom tekshiruvi bilan mos kelish, %</div></div>${d.crop_accuracy.length ? tvBtn('crop') : ''}</div>
          <div class="chart" id="c-crop">${!d.crop_accuracy.length ? '<p class="empty">Hali agronom tekshirgan tashxis yo\'q. Agronomlar navbatni tekshira boshlagach shu yerda ko\'rinadi.</p>' : S.chartTable.crop ? tableView(d.crop_accuracy.map(r => [r.crop, r.accuracy + '% (' + r.reviewed + ')']), 'Ekin', 'Aniqlik') : ''}</div></div>
      </div>`;
    },
    after(d) {
      if (!S.chartTable.diag && d.diagnoses_daily.length > 1) areaChart(document.getElementById('c-diag'), d.diagnoses_daily.map(x => x.count), d.diagnoses_daily.map(x => dayLbl(x.date)), 'tashxis');
      if (!S.chartTable.reg && d.regions.length) hbars(document.getElementById('c-reg'), d.regions.map(r => [r.region, r.count]), 'foydalanuvchi');
      if (!S.chartTable.crop && d.crop_accuracy.length) hbars(document.getElementById('c-crop'), d.crop_accuracy.map(r => [r.crop, r.accuracy]), 'aniqlik', v => v + '%');
    },
  };

  // ---------- Foydalanuvchilar ----------
  SEC.users = {
    label: 'Foydalanuvchilar', ic: 'users',
    async load() {
      const p = new URLSearchParams({ limit: 200 });
      if (S.uq) p.set('q', S.uq);
      if (S.ur === 'blocked') p.set('blocked', 'true'); else if (S.ur !== 'all') p.set('role', S.ur);
      const [list, count] = await Promise.all([api('/admin/users?' + p), api('/admin/users/count')]);
      return { list, count };
    },
    render({ list, count }) {
      return `${head('Foydalanuvchilar', "Qidirish, rol berish va bloklash. Har bir o'zgarish harakatlar jurnaliga yoziladi.")}
      <div class="filters"><label class="search">${I('search')}<input id="uq" placeholder="Ism, login, telefon yoki viloyat" value="${esc(S.uq)}" aria-label="Qidiruv"></label>
        <div class="segm" role="group" aria-label="Rol">${[['all', 'Hammasi'], ['user', 'Dehqonlar'], ['agronomist', 'Agronomlar'], ['admin', 'Adminlar'], ['blocked', 'Bloklangan']].map(([k, t]) => `<button data-act="ur" data-v="${k}" aria-pressed="${S.ur === k}">${t}</button>`).join('')}</div></div>
      <div class="tw"><table><thead><tr><th>Foydalanuvchi</th><th>Viloyat</th><th>Rol</th><th>Obuna</th><th class="n">Tashxislar</th><th>Ro'yxatdan o'tgan</th><th>Holat</th></tr></thead><tbody>
      ${list.map((u, i) => `<tr class="click" data-act="user" data-v="${i}" tabindex="0"><td><div class="who"><div class="av ${u.role === 'agronomist' ? 'exp' : ''}">${initials(u.full_name)}</div><div><b>${esc(u.full_name)}</b><div class="muted small mono">${esc(u.phone || u.email || '@' + u.username)}</div></div></div></td>
        <td>${esc(u.region || '—')}</td><td>${tag(...(ROLES[u.role] || ROLES.user).slice(0, 1), '', (ROLES[u.role] || ROLES.user)[1])}</td>
        <td>${u.is_premium ? tag('t-pre', '', 'Premium') : '<span class="muted">Bepul</span>'}</td><td class="n">${u.diagnoses}</td><td class="num">${fmtDate(u.created_at)}</td>
        <td>${u.is_active ? tag('t-ok', 'check', 'Faol') : tag('t-bad', 'lock', 'Bloklangan')}</td></tr>`).join('') || '<tr><td colspan="7" class="muted">Hech kim topilmadi. Qidiruvni o\'zgartiring.</td></tr>'}
      </tbody></table></div><p class="muted small" style="margin:0">${list.length} ta ko'rsatildi · jami ${fmt(count.total)} · bloklangan ${fmt(count.blocked)}</p>`;
    },
  };
  function userDrawer(u) {
    drawer(`<div class="row" style="justify-content:space-between"><h3>${esc(u.full_name)}</h3><button class="btn ghost" data-act="close" aria-label="Yopish">${I('x')}</button></div>
      <dl class="kv"><dt>Login</dt><dd class="mono">@${esc(u.username)}</dd><dt>Telefon</dt><dd class="mono">${esc(u.phone || '—')}</dd><dt>Email</dt><dd>${esc(u.email || '—')}</dd>
      <dt>Viloyat</dt><dd>${esc(u.region || '—')}</dd><dt>Ro'yxatdan</dt><dd>${fmtDate(u.created_at)}</dd><dt>Ekinlar</dt><dd>${u.crops}</dd><dt>Tashxislar</dt><dd>${u.diagnoses}</dd>
      <dt>Obuna</dt><dd>${u.is_premium ? 'Premium' + (u.premium_until ? ' · ' + fmtDate(u.premium_until) + ' gacha' : '') : 'Bepul'}</dd>${u.specialization ? `<dt>Mutaxassislik</dt><dd>${esc(u.specialization)}</dd>` : ''}</dl>
      <div class="fld"><label for="role-s">Rol</label><select id="role-s">${Object.entries(ROLES).map(([k, [, t]]) => `<option value="${k}" ${u.role === k ? 'selected' : ''}>${t}</option>`).join('')}</select></div>
      <button class="btn pri" data-act="saverole" data-v="${u.id}">Rolni saqlash</button>
      <hr style="border:0;border-top:1px solid var(--line);width:100%">
      ${!u.is_active ? `<button class="btn out" data-act="unblock" data-v="${u.id}">${I('lock', 'ico s')}Blokdan chiqarish</button>`
        : u.role === 'admin' ? '<p class="muted small" style="margin:0">Adminni bloklab bo\'lmaydi.</p>'
          : `<div class="fld"><label for="blk-r">Bloklash sababi</label><input id="blk-r" placeholder="Masalan: spam, reklama" maxlength="200"></div><button class="btn dan" data-act="block" data-v="${u.id}">${I('lock', 'ico s')}Bloklash</button>`}`);
  }

  // ---------- Agronomlar ----------
  SEC.agro = {
    label: 'Agronomlar', ic: 'shield', badge: () => S.badges.agro,
    async load() { const [apps, experts] = await Promise.all([api('/admin/expert-applications'), api('/admin/experts')]); S.badges.agro = apps.length; return { apps, experts }; },
    render({ apps, experts }) {
      return `${head('Agronomlar', "Arizalarni ko'rib chiqish va agronomlar ish sifatini kuzatish.")}
      <div class="card"><div class="ch"><div><h2>Arizalar · ${apps.length}</h2><div class="sub">«Men agronomman» orqali yuborilgan</div></div></div>
        ${apps.length ? apps.map(a => `<div class="app-card" style="padding:12px 0;border-top:1px solid var(--line)"><div class="doc">${I('book')}<span>${a.document_url ? 'Hujjat' : "Hujjat yo'q"}</span></div>
          <div style="display:grid;gap:6px;min-width:0"><div class="row" style="justify-content:space-between"><b style="font-size:15.5px">${esc(a.full_name)}</b><span class="muted small">${esc(a.region || '')} · ${ago(a.created_at)}</span></div>
          <div class="small">${esc(a.specialization)} · tajriba ${a.experience_years} yil${a.phone ? ' · <span class="mono">' + esc(a.phone) + '</span>' : ''}</div>
          ${a.about ? `<div class="small muted">${esc(a.about)}</div>` : ''}
          ${a.document_url ? `<a class="small" href="${esc(media(a.document_url))}" target="_blank" rel="noopener">Hujjatni ochish</a>` : ''}
          <div class="row"><button class="btn exp sm" data-act="approve" data-v="${a.id}">${I('check', 'ico s')}Tasdiqlash</button><button class="btn out sm" data-act="reject" data-v="${a.id}" data-n="${esc(a.full_name)}">Rad etish</button></div></div></div>`).join('')
          : `<div class="banner b-ok">${I('check')}<p>Barcha arizalar ko'rib chiqildi.</p><span></span></div>`}
      </div>
      <div class="tw"><table><thead><tr><th>Agronom</th><th>Viloyat</th><th class="n">Javoblar (30 kun)</th><th class="n">Tekshirgan (30 kun)</th><th class="n">Reyting</th><th class="n">O'rtacha javob</th><th>AI bilan mos</th><th>Holat</th></tr></thead><tbody>
      ${experts.map(e => `<tr><td><div class="who"><div class="av exp">${initials(e.full_name)}</div><div><b>${esc(e.full_name)}</b><div class="muted small">${esc(e.specialization || '')}</div></div></div></td><td>${esc(e.region || '—')}</td>
        <td class="n">${e.answers_30d}</td><td class="n">${e.reviewed_30d}</td><td class="n">${e.rating == null ? '—' : '★ ' + String(e.rating).replace('.', ',')}</td><td class="n">${wait(e.avg_answer_minutes)}</td>
        <td>${meter(e.ai_agreement)}</td><td>${e.accepting_questions ? tag('t-ok', 'check', 'Onlayn') : tag('t-neu', 'clock', 'Oflayn')}</td></tr>`).join('') || '<tr><td colspan="8" class="muted">Hali agronom yo\'q. Arizani tasdiqlang yoki Foydalanuvchilar bo\'limida rol bering.</td></tr>'}
      </tbody></table></div>`;
    },
  };

  // ---------- AI va dataset ----------
  const isRunning = t => (t?.runs || []).some(r => r.status !== 'completed');
  SEC.ai = {
    label: 'AI va dataset', ic: 'ai',
    async load() {
      const [a, models, training, coverage] = await Promise.all([api('/admin/ai'), api('/admin/ai/models'), api('/admin/ai/training'), api('/admin/ai/coverage')]);
      return { a, models, training, coverage };
    },
    render({ a, models, training, coverage }) {
      const m = models.active || a.model || {};
      const activeN = +(models.active_tag || '').replace('model-v', '') || 0;
      const pctTxt = v => (v == null ? '—' : (Math.round(v * 1000) / 10).toString().replace('.', ',') + '%');
      const bar = (v, warn = 0.8) => (v == null ? '<span class="muted small">—</span>'
        : `<div class="row" style="flex-wrap:nowrap"><div class="meter ${v < warn ? 'risk' : ''}" style="width:80px"><i style="width:${Math.round(v * 100)}%"></i></div><span class="num small"><b>${pctTxt(v)}</b></span></div>`);
      const runs = training.runs || [], last = runs[0], running = isRunning(training);
      const usable = a.confirmed + a.corrected;
      const missing = coverage.classes.filter(c => !c.in_model);
      const missingImgs = missing.reduce((s, c) => s + c.train + c.test, 0);
      return `${head('AI va dataset', "Model qanchalik yaxshi ishlayapti va qanday yaxshilanadi: dala rasmlari → agronom tasdig'i → qayta o'qitish.", `<button class="btn out" data-act="export">${I('download')}Dataset eksporti</button>`)}
      <div class="grid g4">
        <div class="card tile"><span class="l">Datasetdagi dala rasmlari</span><span class="v num">${fmt(a.total)}</span><span class="muted small">oxirgi 30 kunda +${fmt(a.new_30d)}</span></div>
        <div class="card tile"><span class="l">Agronom tasdiqlagan</span><span class="v num">${fmt(usable)}</span><span class="muted small">o'qitishga tayyor · navbatda ${fmt(a.pending)}</span></div>
        <div class="card tile"><span class="l">Tuzatilgan (AI adashgan)</span><span class="v num">${fmt(a.corrected)}</span><span class="muted small">eng qimmatli rasmlar</span></div>
        <div class="card tile"><span class="l">Hozir ishlayapti</span><span class="v mono" style="font-size:22px">${esc(models.active_tag || m.model || '—')}</span><span class="muted small">${m.classes ? m.classes + ' sinf · ' : ''}agronom bilan mos ${a.field_accuracy == null ? '—' : a.field_accuracy + '%'}</span></div>
      </div>
      ${models.error ? `<div class="banner b-risk">${I('alert')}<p>Model versiyalari ro'yxatini olib bo'lmadi: ${esc(models.error)}</p><button class="btn out sm" data-act="reload">Qayta urinish</button></div>` : ''}
      <div class="tw"><table><thead><tr><th>Versiya</th><th>Sana</th><th>O'qitish ma'lumoti</th><th>PlantVillage testi</th><th>Dala rasmlari testi</th><th>Holat</th><th></th></tr></thead><tbody>
      ${models.models.map(r => {
        const n = +r.tag.replace('model-v', '');
        const st = r.active ? tag('t-ok', 'check', 'Ishlayapti') : n > activeN ? tag('t-info', 'info', 'Nomzod') : tag('t-neu', '', 'Arxiv');
        const btn = r.can_activate ? `<button class="btn ${n > activeN ? 'pri' : 'ghost'} sm" data-act="activate" data-v="${esc(r.tag)}">${n > activeN ? 'Ishga tushirish' : 'Qaytarish'}</button>`
          : r.can_force ? `<button class="btn ghost sm" data-act="activate" data-v="${esc(r.tag)}" data-force="1" title="${esc(r.reason)}">Dala testisiz ishga tushirish</button>`
            : (r.reason && !r.active ? `<span class="muted small">${esc(r.reason)}</span>` : '');
        return `<tr><td class="mono"><b>${esc(r.tag)}</b></td><td>${r.created_at ? fmtDate(r.created_at) : '—'}</td>
          <td class="small">PlantVillage${r.field_train_images ? ` + ${fmt(r.field_train_images)} dala rasmi` : ''}${r.classes ? ` · ${r.classes} sinf` : ''}</td>
          <td>${bar(r.val_accuracy, 0.9)}</td>
          <td>${r.field_test_accuracy == null ? '<span class="muted small">test rasmlari yo\'q</span>' : bar(r.field_test_accuracy)}${r.baseline_field_test_accuracy != null ? `<div class="muted small">${esc(r.baseline_model ? 'hozirgi' : 'oldingi')}: ${pctTxt(r.baseline_field_test_accuracy)} · ${r.field_test_samples} rasm</div>` : ''}</td>
          <td>${st}</td><td>${btn}</td></tr>`;
      }).join('') || '<tr><td colspan="7" class="muted">Versiyalar topilmadi.</td></tr>'}
      </tbody></table></div>
      <div class="banner b-info">${I('info')}<p><b>Dala rasmlari testi</b> — agronom tasdiqlagan, o'qitishda hech qachon ishlatilmaydigan telefon rasmlari (har 5 tadan biri). Haqiqiy foydalanuvchi sifati shu raqamda ko'rinadi; PlantVillage (laboratoriya rasmlari) bo'yicha 97% bo'lsa ham, dalada pastroq. Yangi model faqat shu test yomonlashmasa ishga tushiriladi.</p><span></span></div>
      <div class="grid g2">
        <div class="card"><div class="ch"><div><h2>Qayta o'qitish</h2><div class="sub">GitHub Actions'da, ~1 soat · natija — yangi nomzod versiya</div></div>${last ? `<a class="btn ghost sm" href="${esc(last.url)}" target="_blank" rel="noopener">GitHub'da</a>` : ''}</div>
          ${!training.configured ? `<div class="banner b-risk">${I('alert')}<p>Sozlanmagan. Serverda bir marta: <span class="mono">sudo bash deploy/enable-training.sh</span> (GitHub token kerak — docs/DATASET.md).</p><span></span></div>` : ''}
          ${training.error ? `<p class="muted small" style="margin:0">${esc(training.error)}</p>` : ''}
          ${last ? `<div class="steps">${last.steps.map(st => `<div class="step ${st.status === 'completed' && st.conclusion !== 'failure' ? 'done' : st.status === 'in_progress' ? 'run' : ''}"><span class="st">${I(st.conclusion === 'failure' ? 'x' : 'check', 'ico s')}</span><span>${esc(st.title)}</span><span class="muted small">${st.conclusion === 'skipped' ? "o'tkazildi" : st.conclusion === 'failure' ? 'xato' : ''}</span></div>`).join('')}</div>
            <p class="muted small" style="margin:0">Oxirgi: ${ago(last.created_at)} · ${last.status !== 'completed' ? 'ketyapti…' : last.conclusion === 'success' ? 'muvaffaqiyatli' : 'xato bilan tugadi'}</p>` : ''}
          ${!running ? `<p class="muted" style="margin:0">${fmt(usable)} ta tasdiqlangan dala rasmi${missingImgs ? ` (shundan ${fmt(missingImgs)} tasi model hali bilmaydigan sinflarda)` : ''}. Yangi versiya o'qitiladi va «Dala rasmlari testi»da hozirgi model bilan solishtiriladi.</p>
            <div><button class="btn pri" data-act="train" ${training.configured ? '' : 'disabled'}>${I('refresh')}Qayta o'qitishni boshlash</button></div>` : ''}
        </div>
        <div class="card"><div class="ch"><div><h2>AI eng ko'p adashtiradigan juftliklar</h2><div class="sub">Agronom tuzatgan holatlar, oxirgi 90 kun</div></div></div>
          ${a.pairs.length ? `<div class="pairs">${a.pairs.map(p => `<div class="pair">${thumb(catImg(p.ai_label), p.ai_name)}${I('arrow', 'ico s')}${thumb(catImg(p.label), p.name)}<span class="small"><b>${esc(p.ai_name.split(' (')[0])}</b> deb o'yladi, aslida <b>${esc(p.name.split(' (')[0])}</b></span><span class="num" style="text-align:right;font-weight:700">${p.count}</span></div>`).join('')}</div>
            <p class="muted small" style="margin:0">Shu juftliklarga ko'proq dala rasmi yig'ish modelni eng tez yaxshilaydi.</p>`
          : '<p class="empty">Hali agronom tuzatgan tashxis yo\'q.</p>'}
        </div>
      </div>
      <div class="card"><div class="ch"><div><h2>Sinflar bo'yicha dala rasmlari</h2><div class="sub">Maqsad — har sinfga ${coverage.target} ta tasdiqlangan rasm (o'qitish + test)</div></div></div>
        ${missing.length ? `<div class="banner b-risk">${I('alert')}<p><b>${missing.length} ta sinfni model hali bilmaydi</b> (${esc(missing.map(c => c.name).slice(0, 4).join(', '))}${missing.length > 4 ? '…' : ''}). Agronomlar navbatda shu ekin rasmlarini «Boshqa kasallik» orqali to'g'ri sinf bilan tasdiqlasa, keyingi o'qitishda model ularni ham o'rganadi (kamida 30–50 ta rasm).</p><span></span></div>` : ''}
        <div class="tw" style="border:0"><table><thead><tr><th>Sinf</th><th>Ekin</th><th>Model</th><th class="n">O'qitish</th><th class="n">Test</th><th>Maqsadga</th></tr></thead><tbody>
        ${coverage.classes.map(c => { const n = c.train + c.test, p = Math.min(100, Math.round(n / coverage.target * 100)); return `<tr><td><div class="who">${thumb(catImg(c.label), c.name)}<div><b>${esc(c.name)}</b><div class="muted small mono">${esc(c.label)}</div></div></div></td><td>${esc(c.plant || '—')}</td>
          <td>${c.in_model ? tag('t-ok', 'check', 'Biladi') : tag('t-risk', 'alert', 'Yangi sinf')}</td><td class="n">${c.train}</td><td class="n">${c.test}</td>
          <td><div class="row" style="flex-wrap:nowrap"><div class="meter ${p < 25 ? 'risk' : ''}" style="width:90px"><i style="width:${p}%"></i></div><span class="num small">${n}/${coverage.target}</span></div></td></tr>`; }).join('')}
        </tbody></table></div>
      </div>`;
    },
    after(d) {
      clearTimeout(S.trainTimer);
      if (isRunning(d.training)) S.trainTimer = setTimeout(() => { if (S.sec === 'ai') load(true); }, 20000);
    },
  };

  // ---------- Bilimlar bazasi ----------
  SEC.kb = {
    label: 'Bilimlar bazasi', ic: 'book',
    async load() { const [diseases, changes] = await Promise.all([api('/admin/kb/diseases'), api('/admin/catalog-changes?limit=60')]); return { diseases, changes }; },
    render({ diseases, changes }) {
      const img = d => catImg(d.ai_label) || media(d.image_url);
      const noImg = diseases.filter(d => !img(d)).length;
      return `${head('Bilimlar bazasi', `${diseases.length} kasallik${noImg ? ` · ${noImg} tasining rasmi yo'q` : ''}. Agronomlar ilovada tahrirlaydi; admin o'zgarishlarni ko'radi va kerak bo'lsa qaytaradi.`)}
      <div class="grid g21">
        <div class="tw"><table><thead><tr><th>Kasallik</th><th>Ekin</th><th>Xavf</th><th class="n">Dorilar</th><th>Rasm</th></tr></thead><tbody>
        ${diseases.map(d => { const r = RISK[d.risk_level] || RISK.medium; return `<tr><td><div class="who">${thumb(img(d), d.name)}<b>${esc(d.name)}</b></div></td><td>${esc(d.plant_name || '—')}</td><td>${tag(...r)}</td><td class="n">${d.medicines}</td><td>${img(d) ? tag('t-ok', 'check', catImg(d.ai_label) ? 'PlantVillage' : 'Dala rasmi') : tag('t-risk', 'alert', "Yo'q")}</td></tr>`; }).join('')}
        </tbody></table></div>
        <div class="card"><h2>O'zgarishlar tarixi</h2>
          ${changes.length ? changes.map(c => `<div class="alert"><span class="ic ${c.user_role === 'agronomist' ? 't-exp' : 't-neu'}">${I(c.action === 'revert' ? 'refresh' : 'shield')}</span><div><b>${esc(c.summary)}</b><div class="muted small">${esc(c.user_name || '—')} · ${ago(c.created_at)}</div></div>
            ${c.revertible ? `<button class="btn ghost sm" data-act="revert" data-v="${c.id}">Qaytarish</button>` : c.reverted ? tag('t-neu', 'refresh', 'Qaytarilgan') : '<span></span>'}</div>`).join('')
          : '<p class="empty">Hali o\'zgarish yo\'q.</p>'}
        </div>
      </div>`;
    },
  };

  // ---------- Jamoat moderatsiyasi ----------
  SEC.mod = {
    label: 'Jamoat', ic: 'flag', badge: () => S.badges.mod,
    async load() { const r = await api('/admin/reports'); S.badges.mod = r.length; return r; },
    render(list) {
      return `${head('Jamoat moderatsiyasi', 'Shikoyat qilingan postlar va izohlar. Yashirilsa, muallifga xabar boradi.')}
      ${list.length ? `<div class="tw"><table><thead><tr><th>Matn</th><th>Muallif</th><th>Sabab</th><th class="n">Shikoyatlar</th><th>Amal</th></tr></thead><tbody>${list.map((r, i) => `<tr><td style="max-width:420px"><span class="muted small">${r.kind === 'post' ? 'Post' : 'Izoh'} · ${ago(r.last_at)}</span><div>${esc(r.text)}</div></td><td>${esc(r.author || '—')}</td>
        <td><div class="row">${(r.reasons.length ? r.reasons : ["Ko'rsatilmagan"]).map(x => tag('t-bad', 'flag', x)).join('')}</div></td><td class="n">${r.count}</td>
        <td><div class="row" style="flex-wrap:nowrap"><button class="btn dan sm" data-act="hide" data-v="${i}">Yashirish</button><button class="btn out sm" data-act="dismiss" data-v="${i}">Rad etish</button></div></td></tr>`).join('')}</tbody></table></div>`
        : `<div class="banner b-ok">${I('check')}<p>Ochiq shikoyat yo'q.</p><span></span></div>`}`;
    },
  };

  // ---------- To'lovlar ----------
  const STAT = { active: ['t-ok', 'check', 'Faol'], pending: ['t-neu', 'clock', 'Kutilmoqda'], cancelled: ['t-neu', 'refresh', 'Bekor qilingan'], expired: ['t-neu', 'clock', 'Muddati tugagan'], trial: ['t-info', 'info', 'Sinov'] };
  const PLAN = { monthly: 'Oylik', yearly: 'Yillik', lifetime: 'Umrbod' };
  SEC.pay = {
    label: "To'lovlar", ic: 'card', load: () => api('/admin/payments'),
    render(p) {
      const plans = Object.entries(p.active_by_plan).map(([k, v]) => `${(PLAN[k] || k).toLowerCase()} ${v}`).join(' · ') || "faol obuna yo'q";
      return `${head("Obunalar va to'lovlar", 'Daromad, obunalar, tariflar va Payme / Click tranzaksiyalari.')}
      ${p.mode === 'sandbox' ? `<div class="banner b-risk">${I('alert')}<p><b>To'lovlar sinov rejimida.</b> Foydalanuvchilar Premium'ni sinov to'lovi bilan oladi, haqiqiy pul olinmaydi. Payme va Click merchant kalitlari serverga qo'shilgach jonli rejimga o'tkaziladi.</p><span></span></div>` : ''}
      <div class="grid g4">
        <div class="card tile"><span class="l">Shu oy daromad</span><span class="v num">${money(p.revenue_month)}</span><span class="muted small">so'm</span></div>
        <div class="card tile"><span class="l">Faol obunalar</span><span class="v num">${fmt(p.active)}</span><span class="muted small">${esc(plans)}</span></div>
        <div class="card tile"><span class="l">Premium ulushi</span><span class="v num">${String(p.premium_share).replace('.', ',')}%</span><span class="muted small">barcha foydalanuvchilardan</span></div>
        <div class="card tile"><span class="l">Bekor qilingan</span><span class="v num">${fmt(p.cancelled_30d)}</span><span class="muted small">30 kun</span></div>
      </div>
      <div class="grid g2">
        <div class="card"><div class="ch"><div><h2>Oylik daromad</h2><div class="sub">ming so'm</div></div>${tvBtn('rev')}</div><div class="chart" id="c-rev">${S.chartTable.rev ? tableView(p.monthly.map(m => [m.month, money(m.amount) + " so'm"]), 'Oy', 'Daromad') : ''}</div></div>
        <form class="card" data-form="settings"><h2>Tariflar va bepul limitlar</h2>
          ${p.settings.map(s => `<div class="fld"><label for="st-${s.key}">${esc(s.title)}</label><input id="st-${s.key}" name="${s.key}" type="number" min="${s.min}" max="${s.max}" value="${s.value}" required></div>`).join('')}
          <div class="row"><button class="btn pri" type="submit">Saqlash</button><span class="muted small">Yangi narx keyingi to'lovlardan amal qiladi</span></div>
        </form>
      </div>
      <div class="tw"><table><thead><tr><th>Vaqt</th><th>Foydalanuvchi</th><th>Tarif</th><th>Tizim</th><th class="n">Summa, so'm</th><th>Holat</th></tr></thead><tbody>
      ${p.transactions.map(t => `<tr><td>${ago(t.created_at)}</td><td>${esc(t.user)}</td><td>${esc(PLAN[t.plan] || t.plan)}</td><td>${esc(t.provider || '—')}</td><td class="n">${fmt(t.amount)}</td><td>${tag(...(t.status === 'active' && !t.paid ? STAT.pending : STAT[t.status] || STAT.pending))}</td></tr>`).join('') || '<tr><td colspan="6" class="muted">Hali to\'lov yo\'q.</td></tr>'}
      </tbody></table></div>`;
    },
    after(p) {
      const MONTHS = ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyun', 'Iyul', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek'];
      if (!S.chartTable.rev) columns(document.getElementById('c-rev'), p.monthly.map(m => [MONTHS[+m.month.slice(5) - 1], Math.round(m.amount / 1000)]), "ming so'm", v => fmt(v));
    },
  };

  // ---------- Tizim ----------
  SEC.sys = {
    label: 'Tizim', ic: 'server',
    async load() { const [s, audit, aud] = await Promise.all([api('/admin/system'), api('/admin/audit?limit=40'), api('/admin/broadcast/audiences')]); return { s, audit, aud }; },
    render({ s, audit, aud }) {
      const b = s.backup || {}, ai = s.ai || {};
      return `${head('Tizim', 'Server, zaxira nusxalar, ommaviy xabarlar va harakatlar jurnali.')}
      <div class="grid g4">
        <div class="card tile"><span class="l">Server</span><span class="v" style="font-size:20px">${s.database ? tag('t-ok', 'check', 'Ishlayapti') : tag('t-bad', 'x', 'Baza bilan muammo')}</span><span class="muted small">${esc(s.environment)} · ${fmt(s.users)} foydalanuvchi</span></div>
        <div class="card tile"><span class="l">Versiya</span><span class="v mono" style="font-size:20px">${esc(s.version)}</span><span class="muted small">AI: ${s.ai ? esc(ai.model_file || ai.model) : 'javob bermayapti'}</span></div>
        <div class="card tile"><span class="l">Oxirgi zaxira</span><span class="v" style="font-size:20px">${b.available ? (b.last_ok ? ago(b.last_ok) : "yo'q") : '—'}</span><span class="muted small">${b.available ? (b.offsite ? 'serverda va bulutda' : 'faqat serverda') : 'zaxira papkasi ulanmagan'}</span></div>
        <div class="card tile"><span class="l">Disk</span><span class="v num" style="font-size:20px">${s.disk.used_pct}%</span><div class="meter ${s.disk.used_pct > 85 ? 'risk' : ''}"><i style="width:${s.disk.used_pct}%"></i></div><span class="muted small">bo'sh ${String(s.disk.free_gb).replace('.', ',')} GB</span></div>
      </div>
      <div class="grid g2">
        <div class="card"><div class="ch"><div><h2>Zaxira nusxalar</h2><div class="sub">Baza + rasmlar · har kuni avtomatik</div></div>
          ${b.available ? `<button class="btn out sm" data-act="backup" ${b.requested ? 'disabled' : ''}>${I('db', 'ico s')}${b.requested ? "So'raldi, kutilmoqda" : 'Hozir olish'}</button>` : ''}</div>
          ${!b.available ? `<div class="banner b-info">${I('info')}<p>Zaxira holati faqat serverda ko'rinadi (zaxira papkasi backend'ga ulanadi).</p><span></span></div>`
          : `${b.status ? `<div class="banner ${b.ok ? 'b-ok' : 'b-risk'}">${I(b.ok ? 'check' : 'alert')}<p>${esc(b.status)}</p><span></span></div>` : ''}
            <div class="tw" style="border:0"><table style="min-width:0"><thead><tr><th>Nusxa (UTC)</th><th class="n">Baza, MB</th><th class="n">Rasmlar, MB</th></tr></thead><tbody>
            ${(b.files || []).map(f => `<tr><td class="mono">${esc(f.name)}</td><td class="n">${String(f.db_mb).replace('.', ',')}</td><td class="n">${f.media_mb == null ? '—' : String(f.media_mb).replace('.', ',')}</td></tr>`).join('') || '<tr><td colspan="3" class="muted">Hali nusxa yo\'q</td></tr>'}
            </tbody></table></div>`}
        </div>
        <form class="card" data-form="broadcast"><h2>Ommaviy xabar</h2>
          <div class="fld"><label for="bc-a">Kimga</label><select id="bc-a" name="audience">${aud.map(a => `<option value="${esc(a.key)}" data-n="${a.count}">${esc(a.title)} (${fmt(a.count)})</option>`).join('')}</select></div>
          <div class="fld"><label for="bc-h">Sarlavha</label><input id="bc-h" name="title" required minlength="3" maxlength="150" placeholder="Masalan: Ertaga kuchli yomg'ir"></div>
          <div class="fld"><label for="bc-t">Matn</label><textarea id="bc-t" name="body" rows="3" required minlength="3" maxlength="1000" placeholder="Purkashni bugun kechqurunga ko'chiring."></textarea></div>
          <div class="row"><button class="btn pri" type="submit">${I('send', 'ico s')}Yuborish</button><span class="muted small">Ilovada bildirishnoma bo'lib keladi</span></div>
        </form>
      </div>
      <div class="card"><h2>Harakatlar jurnali</h2>${audit.length ? audit.map(a => `<div class="alert" style="grid-template-columns:130px 140px minmax(0,1fr)"><span class="muted small">${ago(a.created_at)}</span><b class="small">${esc(a.actor)}</b><span class="small">${esc(a.summary)}</span></div>`).join('') : '<p class="empty">Hali yozuv yo\'q.</p>'}</div>`;
    },
  };

  // ---------- Ilova ----------
  const ORDER = ['dash', 'users', 'agro', 'ai', 'kb', 'mod', 'pay', 'sys'];
  const root = document.getElementById('root');
  function toast(m, bad = false) {
    document.querySelectorAll('.toast').forEach(t => t.remove());
    const t = document.createElement('div'); t.className = 'toast'; t.setAttribute('role', 'status');
    if (bad) t.style.background = 'var(--disease)';
    t.innerHTML = I(bad ? 'alert' : 'check'); const s = document.createElement('span'); s.textContent = m; t.append(s);
    document.body.append(t); clearTimeout(toast._t); toast._t = setTimeout(() => t.remove(), bad ? 5000 : 3200);
  }
  const fail = e => toast(e.message || String(e), true);
  function closeDrawer() { document.querySelectorAll('.scrim,.drawer').forEach(e => e.remove()); }
  function drawer(html) {
    closeDrawer();
    const s = document.createElement('div'); s.className = 'scrim'; s.dataset.act = 'close';
    const d = document.createElement('div'); d.className = 'drawer'; d.setAttribute('role', 'dialog'); d.setAttribute('aria-modal', 'true'); d.innerHTML = html;
    document.body.append(s, d); d.querySelector('select,input,button:not([data-act=close])')?.focus();
  }
  function shell() {
    root.innerHTML = `<div class="app"><nav class="side" aria-label="Admin menyusi"><div class="logo"><img src="/admin/logo.svg?v=1" alt="" width="34" height="34"><span>Agro<em>Yordam</em></span></div><div id="navs"></div>
      ${themeSwitch()}
      <div class="me"><div class="av">${initials(S.me.full_name)}</div><div style="min-width:0"><b class="me-name">${esc(S.me.full_name)}</b><div class="me-role">${esc((ROLES[S.me.role] || [, S.me.role])[1])}</div></div></div>
      <button class="logout" data-act="logout">${I('logout', 'ico s')}<span>Hisobdan chiqish</span></button></nav>
      <main class="main" id="main" aria-live="polite"></main></div>`;
  }
  function paintNav() {
    const el = document.getElementById('navs'); if (!el) return;
    el.innerHTML = '<div class="lbl">Umumiy</div>' + ORDER.map((k, i) => `${i === 3 ? '<div class="lbl">Mazmun</div>' : i === 6 ? '<div class="lbl">Biznes va tizim</div>' : ''}<button class="nav" data-go="${k}" ${S.sec === k ? 'aria-current="page"' : ''}>${I(SEC[k].ic)}<span>${SEC[k].label}</span>${SEC[k].badge && SEC[k].badge() ? `<span class="n">${SEC[k].badge()}</span>` : ''}</button>`).join('');
  }
  function paint() {
    const main = document.getElementById('main'); const sec = SEC[S.sec]; const d = S.data[S.sec];
    hideTip(); paintNav();
    if (d === undefined) { main.innerHTML = '<div class="loading">Yuklanmoqda…</div>'; return; }
    if (d instanceof Error) { main.innerHTML = `${head(sec.label, '')}<div class="banner b-risk">${I('alert')}<p>${esc(d.message)}</p><button class="btn out sm" data-act="reload">Qayta urinish</button></div>`; return; }
    main.innerHTML = sec.render(d); sec.after && sec.after(d);
  }
  async function load(keepOld = false) {
    const sec = S.sec;
    if (!keepOld) { delete S.data[sec]; paint(); }
    try { S.data[sec] = await SEC[sec].load(); } catch (e) { if (e.code === 401) return; S.data[sec] = e; }
    if (S.sec === sec) paint();
  }
  function go(sec) {
    if (!SEC[sec]) sec = 'dash';
    clearTimeout(S.trainTimer);
    S.sec = sec; closeDrawer();
    if (location.hash !== '#' + sec) history.replaceState(null, '', '#' + sec);
    window.scrollTo({ top: 0 }); load();
  }
  async function act(fn, ok) {
    try { await fn(); closeDrawer(); if (ok) toast(ok); await load(true); } catch (e) { fail(e); }
  }

  document.addEventListener('click', e => {
    const t = e.target.closest('[data-act],[data-go]'); if (!t || t.disabled) return;
    if (t.dataset.go) { go(t.dataset.go); return; }
    const a = t.dataset.act, v = t.dataset.v, d = S.data[S.sec];
    switch (a) {
      case 'range': S.range = +v; load(); break;
      case 'tv': S.chartTable[v] = !S.chartTable[v]; paint(); break;
      case 'ur': S.ur = v; load(true); break;
      case 'reload': load(); break;
      case 'close': closeDrawer(); break;
      case 'logout': logout(); break;
      case 'theme': setTheme(v); break;
      case 'user': userDrawer(d.list[+v]); break;
      case 'saverole': act(() => api(`/admin/users/${v}/role`, { method: 'PUT', body: { role: document.getElementById('role-s').value } }), 'Rol saqlandi'); break;
      case 'block': {
        const r = document.getElementById('blk-r');
        if (!r.value.trim()) { r.focus(); r.style.borderColor = 'var(--disease)'; r.placeholder = 'Sababni yozing — u jurnalga tushadi'; break; }
        act(() => api(`/admin/users/${v}/block?blocked=true&reason=${encodeURIComponent(r.value.trim())}`, { method: 'PUT' }), 'Bloklandi');
      } break;
      case 'unblock': act(() => api(`/admin/users/${v}/block?blocked=false`, { method: 'PUT' }), 'Blokdan chiqarildi'); break;
      case 'approve': act(() => api(`/admin/expert-applications/${v}/approve`, { method: 'POST' }), "Agronom bo'ldi. Ilovasi agronom rejimida ochiladi"); break;
      case 'reject': drawer(`<div class="row" style="justify-content:space-between"><h3>Arizani rad etish</h3><button class="btn ghost" data-act="close" aria-label="Yopish">${I('x')}</button></div>
        <p class="muted" style="margin:0">${esc(t.dataset.n)} sababni ilovada ko'radi va qayta topshira oladi.</p>
        <div class="fld"><label for="rj">Sabab</label><select id="rj"><option>Hujjat yuklanmagan</option><option>Hujjat o'qilmaydi</option><option>Tajriba yetarli emas</option><option>Ma'lumot to'liq emas</option></select></div>
        <button class="btn dan" data-act="rejectok" data-v="${v}">Rad etish</button>`); break;
      case 'rejectok': act(() => api(`/admin/expert-applications/${v}/reject`, { method: 'POST', body: { reason: document.getElementById('rj').value } }), 'Ariza rad etildi, sababi yuborildi'); break;
      case 'revert': if (confirm("O'zgarishni qaytarasizmi? Oldingi matn tiklanadi.")) act(() => api(`/admin/catalog-changes/${v}/revert`, { method: 'POST' }), "O'zgarish qaytarildi"); break;
      case 'hide': { const r = d[+v]; if (confirm(`${r.kind === 'post' ? 'Post' : 'Izoh'} o'chiriladi va muallifga xabar boradi. Davom etasizmi?`)) act(() => api('/admin/reports/hide', { method: 'POST', body: { kind: r.kind, target_id: r.target_id } }), 'Yashirildi, muallifga xabar berildi'); } break;
      case 'dismiss': { const r = d[+v]; act(() => api('/admin/reports/dismiss', { method: 'POST', body: { kind: r.kind, target_id: r.target_id } }), 'Shikoyat rad etildi'); } break;
      case 'backup': act(() => api('/admin/system/backup-now', { method: 'POST' }), "Zaxira so'raldi: 1–5 daqiqada boshlanadi"); break;
      case 'activate': {
        const force = !!t.dataset.force;
        const msg = force ? `${v} dala rasmlari testisiz ishga tushiriladi. Ishonchingiz komilmi?` : `${v} ishga tushirilsinmi? Kerak bo'lsa eski versiyaga bir bosishda qaytish mumkin.`;
        if (!confirm(msg)) break;
        t.disabled = true; t.textContent = 'Yuklanmoqda…';
        act(() => api(`/admin/ai/models/${v}/activate`, { method: 'POST', body: { force } }), `${v} ishga tushirildi`).finally(() => { t.disabled = false; });
      } break;
      case 'train':
        if (!confirm("Qayta o'qitish boshlansinmi? GitHub Actions'da ~1 soat davom etadi; tayyor bo'lgach yangi nomzod versiya shu jadvalda paydo bo'ladi.")) break;
        act(() => api('/admin/ai/training', { method: 'POST' }), "O'qitish boshlandi. Holati shu yerda yangilanib turadi");
        break;
      case 'export': api('/admin/dataset/export-link', { method: 'POST' }).then(r => { location.href = API + r.url; toast('Yuklab olish boshlandi (havola 10 daqiqa amal qiladi)'); }).catch(fail); break;
    }
  });
  document.addEventListener('submit', e => {
    const f = e.target.closest('form[data-form]'); if (!f) return;
    e.preventDefault();
    if (f.dataset.form === 'settings') {
      const body = {}; new FormData(f).forEach((v, k) => { body[k] = +v; });
      act(() => api('/admin/settings', { method: 'PUT', body }), 'Tariflar saqlandi');
    } else if (f.dataset.form === 'broadcast') {
      const fd = new FormData(f); const opt = f.querySelector('select').selectedOptions[0];
      if (!confirm(`Xabar ${opt.dataset.n} kishiga yuboriladi. Davom etasizmi?`)) return;
      act(async () => { const r = await api('/admin/broadcast', { method: 'POST', body: { audience: fd.get('audience'), title: fd.get('title'), body: fd.get('body') } }); toast(`Xabar ${r.sent} kishiga yuborildi`); });
    } else if (f.dataset.form === 'login') {
      login(f);
    }
  });
  let qTimer;
  document.addEventListener('input', e => {
    if (e.target.id !== 'uq') return;
    S.uq = e.target.value.trim(); clearTimeout(qTimer);
    qTimer = setTimeout(async () => {
      await load(true);
      const i = document.getElementById('uq'); if (i) { i.focus(); i.setSelectionRange(i.value.length, i.value.length); }
    }, 300);
  });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeDrawer(); if (e.key === 'Enter' && e.target.matches('tr[tabindex]')) e.target.click(); });
  window.addEventListener('resize', hideTip);
  window.addEventListener('hashchange', () => { const s = location.hash.slice(1); if (S.me && s && s !== S.sec) go(s); });

  // ---------- Kirish ----------
  function showLogin(msg = '') {
    root.innerHTML = `<div class="login"><form data-form="login" autocomplete="on"><div class="row" style="justify-content:space-between"><div class="logo"><img src="/admin/logo.svg?v=1" alt="" width="34" height="34"><span>Agro<em>Yordam</em></span></div>${themeSwitch()}</div>
      <div><h1>Admin paneli</h1><p class="muted" style="margin:4px 0 0">Admin yoki moderator hisobi bilan kiring.</p></div>
      <div class="fld"><label for="lg-u">Login yoki email</label><input id="lg-u" name="login" autocomplete="username" required></div>
      <div class="fld"><label for="lg-p">Parol</label><input id="lg-p" name="password" type="password" autocomplete="current-password" required></div>
      <p class="err" role="alert">${esc(msg)}</p><button class="btn pri" type="submit" style="justify-content:center">Kirish</button>
      <p class="muted small" style="margin:0">Dehqon va agronomlar uchun — <a href="/">mobil ilova</a>.</p></form></div>`;
    document.getElementById('lg-u').focus();
  }
  async function login(f) {
    const err = f.querySelector('.err'), btn = f.querySelector('button[type=submit]'); err.textContent = ''; btn.disabled = true;
    try {
      store.set(await raw('/auth/login', { method: 'POST', body: { login: f.login.value.trim(), password: f.password.value }, auth: false }));
      await start();
    } catch (e) { err.textContent = e.message; btn.disabled = false; }
  }
  async function logout() {
    try { if (store.rt) await raw('/auth/logout', { method: 'POST', body: { refresh_token: store.rt } }); } catch { /* baribir chiqamiz */ }
    store.clear(); S.me = null; S.data = {}; showLogin();
  }
  async function start() {
    if (!store.at) { showLogin(); return; }
    let me;
    try { me = await api('/users/me'); } catch (e) { if (e.code === 401) { store.clear(); showLogin(); } else { showLogin(e.message); } return; }
    if (!['admin', 'moderator'].includes(me.role)) { store.clear(); showLogin("Bu hisobda admin huquqi yo'q. Admin yoki moderator hisobi bilan kiring."); return; }
    S.me = me; shell();
    // Menyudagi raqamlar (arizalar, shikoyatlar) birinchi ochilishdan ko'rinsin
    if (location.hash.slice(1) !== 'dash') api('/admin/dashboard?days=7').then(d => { S.badges = { agro: d.attention.applications, mod: d.attention.reports }; paintNav(); }).catch(() => {});
    go(location.hash.slice(1) || 'dash');
  }
  start();
})();
