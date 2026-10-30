/* AgroYordam admin paneli (/admin) — "Tabiiy Agro" dizayni (Admin dizayn TZ v1.0).
 * Ilova bilan bir xil API (/api/v1/admin/...), kirish — admin yoki moderator hisobi.
 * Barcha raqamlar serverdan; ma'lumot bo'lmasa "—" / "Noma'lum". Backend'da yo'q amal soxta "muvaffaqiyat" bermaydi.
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
  const fmt = n => (n == null || Number.isNaN(+n) ? '—' : Number(n).toLocaleString('ru-RU').replace(/ /g, ' '));
  const sum = n => fmt(Math.round(n || 0)) + " so'm";
  const pct = v => (v == null ? '—' : (Math.round(v * 1000) / 10).toString().replace('.', ',') + '%');
  const parseTs = s => (s ? new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(s) ? s : s + 'Z') : null);
  const MON = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
  const pad = n => String(n).padStart(2, '0');
  const dayLbl = iso => { const d = new Date(iso + 'T00:00:00'); return d.getDate() + '-' + MON[d.getMonth()]; };
  const fmtDate = s => { const d = parseTs(s); return d ? `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}` : '—'; };
  const fmtDT = s => { const d = parseTs(s); return d ? `${fmtDate(s)} ${pad(d.getHours())}:${pad(d.getMinutes())}` : '—'; };
  const ago = s => {
    const d = parseTs(s); if (!d) return '—';
    const m = Math.round((Date.now() - d) / 60000);
    if (m < 1) return 'hozir'; if (m < 60) return m + ' daqiqa oldin';
    if (m < 1440) return Math.round(m / 60) + ' soat oldin'; if (m < 2880) return 'kecha, ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    if (m < 10080) return Math.floor(m / 1440) + ' kun oldin';
    return fmtDate(s);
  };
  const wait = m => (m == null ? '—' : m < 60 ? m + ' daq' : m < 1440 ? Math.round(m / 60) + ' soat' : Math.round(m / 1440) + ' kun');
  const bytes = b => (b == null ? '—' : b < 1024 * 1024 ? Math.max(1, Math.round(b / 1024)) + ' KB' : b < 1e9 ? (b / 1048576).toFixed(1).replace('.', ',') + ' MB' : (b / 1073741824).toFixed(2).replace('.', ',') + ' GB');
  const mb = v => (v == null ? '—' : v < 1 ? Math.max(1, Math.round(v * 1000)) + ' KB' : String(v).replace('.', ',') + ' MB');
  const initials = n => esc(String(n || '?').trim().split(/\s+/).map(x => x[0] || '').join('').slice(0, 2).toUpperCase());
  const delta = (cur, prev) => (prev ? Math.round((cur / prev - 1) * 100) : null);
  const uptime = s => { if (s == null) return null; const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
    return d ? [d + ' kun', `${h} soat ${m} daqiqa`] : h ? [h + ' soat', m + ' daqiqa'] : [m + ' daqiqa', 'yaqinda qayta ishga tushgan']; };

  // ---------- Ikonkalar: bitta outline oila, 20/24 px ----------
  const P = {
    home: '<path d="M4 11l8-7 8 7"/><path d="M6 10v10h12V10"/><path d="M10 20v-6h4v6"/>',
    dash: '<path d="M4 11l8-7 8 7"/><path d="M6 10v10h12V10"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c1-3.5 3.5-5 6.5-5s5.5 1.5 6.5 5"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 15c2 .6 3.2 2.2 3.8 5"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.2-4 4.2-6 8-6s6.8 2 8 6"/>',
    agro: '<path d="M5 19c8 0 14-6 14-14-8 0-14 6-14 14z"/><path d="M5 19l7-7"/>',
    ai: '<rect x="6" y="6" width="12" height="12" rx="2.5"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/><path d="M10 10h4v4h-4z"/>',
    book: '<path d="M3 5.5C5.5 4.5 8.5 4.5 12 6.5c3.5-2 6.5-2 9-1V19c-2.5-1-5.5-1-9 1-3.5-2-6.5-2-9-1z"/><path d="M12 6.5V20"/>',
    chat: '<path d="M4 5h16v11H9l-5 4z"/><path d="M8 10h.01M12 10h.01M16 10h.01"/>',
    card: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 10h18M7 15h4"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7"/>', checkc: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.8 2.8L16 9.8"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>', xc: '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>',
    alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.5v.01"/>', alertc: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.5v.01"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.01"/>',
    up: '<path d="M7 17L17 7M9 7h8v8"/>', down: '<path d="M7 7l10 10M17 9v8H9"/>', arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    chevR: '<path d="M9 6l6 6-6 6"/>', chevL: '<path d="M15 6l-6 6 6 6"/>', chevD: '<path d="M6 9l6 6 6-6"/>',
    db: '<ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v12c0 1.7 3 3 7 3s7-1.3 7-3V6M5 12c0 1.7 3 3 7 3s7-1.3 7-3"/>',
    server: '<rect x="4" y="4" width="16" height="7" rx="2"/><rect x="4" y="13" width="16" height="7" rx="2"/><path d="M8 7.5v.01M8 16.5v.01"/>',
    refresh: '<path d="M20 11a8 8 0 0 0-14.5-4.5L4 8M4 4v4h4M4 13a8 8 0 0 0 14.5 4.5L20 16M20 20v-4h-4"/>',
    send: '<path d="M4 12l16-8-6 16-3-7z"/>', download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', key: '<circle cx="8" cy="15" r="4"/><path d="M10.8 12.2 20 3M16 7l3 3M14 9l2 2"/>',
    copy: '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/>', lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    unlock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 7.5-2"/>',
    table: '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 10h16M10 4v16"/>', chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
    auto: '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v17a8.5 8.5 0 0 0 0-17z" fill="currentColor"/>',
    logout: '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3"/><path d="M10 17l-5-5 5-5M5 12h11"/>',
    image: '<rect x="4" y="5" width="16" height="14" rx="2"/><circle cx="9" cy="10" r="1.5"/><path d="M20 16l-5-5-8 8"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    eyeoff: '<path d="M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.3 4.2M6.4 6.4A17 17 0 0 0 2 12s3.5 7 10 7a9.6 9.6 0 0 0 4.2-1M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
    pin: '<path d="M12 21s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12z"/><circle cx="12" cy="9" r="2.5"/>',
    cal: '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
    doc: '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>', star: '<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>',
    bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
    shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>', shieldLock: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><rect x="9" y="11" width="6" height="5" rx="1"/><path d="M10.5 11V9.5a1.5 1.5 0 0 1 3 0V11"/>',
    play: '<path d="M7 5l12 7-12 7z"/>', plus: '<path d="M12 5v14M5 12h14"/>', flag: '<path d="M5 21V4h11l-2 4 2 4H5"/>',
    pulse: '<path d="M3 12h4l3-8 4 16 3-8h4"/>', crown: '<path d="M3 8l4.5 4L12 5l4.5 7L21 8l-2 11H5z"/>',
    coins: '<ellipse cx="9" cy="6.5" rx="6" ry="2.5"/><path d="M3 6.5v4c0 1.4 2.7 2.5 6 2.5s6-1.1 6-2.5v-4"/><path d="M9 15.5c0 1.4 2.7 2.5 6 2.5s6-1.1 6-2.5v-4c0-1.2-1.9-2.2-4.6-2.4"/>',
    ext: '<path d="M14 4h6v6M20 4l-9 9M18 14v6H4V6h6"/>', menu: '<path d="M4 7h16M4 12h16M4 17h16"/>', layers: '<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>',
    filter: '<path d="M4 6h16M7 12h10M10 18h4"/>', userx: '<circle cx="10" cy="8" r="4"/><path d="M2 21c1.2-4 4.2-6 8-6 1.5 0 2.9.3 4 .9M16 16l5 5M21 16l-5 5"/>',
    usercheck: '<circle cx="10" cy="8" r="4"/><path d="M2 21c1.2-4 4.2-6 8-6 1.5 0 2.9.3 4 .9M15.5 18.5l2 2 4-4"/>',
    target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>', cube: '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M4 7.5l8 4.5 8-4.5M12 12v9"/>',
    msg: '<path d="M4 5h16v11H9l-5 4z"/>', leafs: '<path d="M4 20c0-8 5-13 13-14-1 8-6 13-13 14z"/><path d="M4 20l7-7"/>',
  };
  const I = (n, c = 'ico') => `<svg class="${c}" viewBox="0 0 24 24" aria-hidden="true">${P[n] || ''}</svg>`;
  const badge = (cls, text, icon) => `<span class="b ${cls}">${icon === 'dot' ? '<span class="dot"></span>' : icon ? I(icon, 'ico s') : ''}${esc(text)}</span>`;
  const thumb = (src, title = '', big = false) => (src ? `<button type="button" class="thumb${big ? ' lg' : ''}" data-act="zoom" data-src="${esc(src)}" data-t="${esc(title)}" aria-label="${esc(title || 'Rasm')}: kattalashtirish"><img class="thumb${big ? ' lg' : ''}" src="${esc(src)}" alt="" loading="lazy" style="border:0"></button>`
    : `<span class="thumb${big ? ' lg' : ''}" title="Rasm yo'q">${I('image', 'ico')}</span>`);
  const avatar = (name, url, cls = '') => `<span class="av ${cls}">${url ? `<img src="${esc(media(url))}" alt="">` : initials(name)}</span>`;
  const ROLES = { user: ['brand', 'Dehqon'], agronomist: ['info', 'Agronom'], moderator: ['pur', 'Moderator'], admin: ['act', 'Admin'] };
  const roleB = r => badge(...(ROLES[r] || ROLES.user));
  const RISK = { high: ['bad', 'Yuqori xavf'], medium: ['warn', "O'rta xavf"], low: ['ok', 'Past xavf'] };
  const PLAN = { monthly: 'Premium (oylik)', yearly: 'Premium (yillik)', lifetime: 'Premium (umrbod)' };
  const PROV = { payme: ['Payme', '#33CCCC'], click: ['Click', '#0F5BD7'], uzum: ['Uzum', '#7B2FF7'] };
  const prov = p => (PROV[p] ? `<span class="prov"><i style="background:${PROV[p][1]}"></i>${PROV[p][0]}</span>` : `<span class="muted">${esc(p || '—')}</span>`);
  const ACTIONS = {
    role: "Rol o'zgartirildi", block: 'Bloklandi', unblock: 'Blokdan chiqarildi', password_reset: 'Parol tiklandi',
    expert_approve: 'Ariza tasdiqlandi', expert_reject: 'Ariza rad etildi', catalog_revert: "O'zgarish qaytarildi",
    report_hide: 'Kontent yashirildi', report_dismiss: 'Shikoyat rad etildi', report_review: "Shikoyat ko'rib chiqilmoqda",
    settings: 'Sozlamalar yangilandi', broadcast: 'Ommaviy xabar', backup_now: "Zaxira so'raldi", model_activate: 'Model faollashtirildi', model_train: "O'qitish boshlandi",
  };
  const actionDot = a => ({ block: 'bad', report_hide: 'bad', password_reset: 'warn', expert_reject: 'warn', report_dismiss: 'info', report_review: 'info' })[a] || 'ok';

  // ---------- Mavzu ----------
  const THEME_KEY = 'agro_admin_theme';
  const getTheme = () => { try { return localStorage.getItem(THEME_KEY) || 'system'; } catch { return 'system'; } };
  const applyTheme = t => { if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t; else delete document.documentElement.dataset.theme; };
  applyTheme(getTheme());
  const themeSwitch = () => `<div class="themes" role="group" aria-label="Mavzu">${[['light', 'sun', "Yorug' mavzu"], ['dark', 'moon', "Qorong'i mavzu"], ['system', 'auto', 'Tizim mavzusi']]
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
    catch { throw new ApiError(navigator.onLine === false ? "Internet aloqasi yo'q. Ulanish tiklangach «Qayta urinish»ni bosing." : "Server bilan aloqa yo'q. Internetni tekshiring.", 0); }
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
  const q = o => new URLSearchParams(Object.entries(o).filter(([, v]) => v !== '' && v != null && v !== 'all')).toString();

  // ---------- Grafiklar (bitta seriya, nuqtali chiziq + maydon; tooltip textContent orqali) ----------
  const tip = document.getElementById('tip');
  function showTip(host, x, y, val, lab) {
    tip.hidden = false; tip.replaceChildren();
    const b = document.createElement('b'); b.textContent = val;
    const k = document.createElement('div'); k.className = 'k'; k.textContent = lab; tip.append(b, k);
    const r = host.getBoundingClientRect();
    tip.style.left = (r.left + x + window.scrollX) + 'px'; tip.style.top = (r.top + y + window.scrollY) + 'px';
  }
  const hideTip = () => { tip.hidden = true; };
  function niceMax(v) { if (!(v > 0)) return 4; const p = Math.pow(10, Math.floor(Math.log10(v))); return [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10].find(m => m * p >= v) * p; }
  const axisN = t => (t >= 1000 ? (t / 1000) + 'K' : (Math.round(t * 10) / 10));
  // O'q qiymatlari butun va "chiroyli" qadam bilan (1, 2, 5, 10…)
  function niceStep(raw) { const p = Math.pow(10, Math.floor(Math.log10(raw || 1))); return [1, 2, 2.5, 5, 10].map(m => m * p).find(s => s >= raw) || 10 * p; }
  function lineChart(el, vals, labels, unit) {
    const W = 760, H = 250, L = 34, R = 12, T = 14, B = 30; const n = vals.length;
    const step = Math.max(1, niceStep(Math.max(...vals, 1) / 4)); const max = Math.max(step, Math.ceil(Math.max(...vals, 1) * 1.05 / step) * step);
    const x = i => L + (W - L - R) * i / Math.max(1, n - 1), y = v => T + (H - T - B) * (1 - v / max);
    const pts = vals.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
    const ticks = []; for (let t = 0; t <= max + 1e-9; t += step) ticks.push(t);
    const every = Math.ceil(n / 10);
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(unit)} grafigi">${ticks.map(t => `<line class="gl" x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}"/><text class="ax" x="${L - 8}" y="${y(t) + 4}" text-anchor="end">${axisN(t)}</text>`).join('')}
     ${labels.map((lb, i) => (i % every === 0 || i === n - 1) && !(i !== n - 1 && n - 1 - i < every / 2) ? `<text class="ax" x="${x(i)}" y="${H - 8}" text-anchor="middle">${esc(lb)}</text>` : '').join('')}
     <polygon class="ar" points="${x(0)},${y(0)} ${pts} ${x(n - 1)},${y(0)}"/><polyline class="ln" points="${pts}"/>
     ${n <= 45 ? vals.map((v, i) => `<circle class="pt" cx="${x(i)}" cy="${y(v)}" r="3.6"/>`).join('') : ''}
     <line class="xh" x1="0" x2="0" y1="${T}" y2="${H - B}" visibility="hidden"/><circle class="pt xd" r="5.5" visibility="hidden"/>
     <rect class="hit" x="${L}" y="${T}" width="${W - L - R}" height="${H - T - B}"/></svg>`;
    const svg = el.querySelector('svg'), hit = svg.querySelector('.hit'), xh = svg.querySelector('.xh'), xd = svg.querySelector('.xd');
    hit.addEventListener('pointermove', e => {
      const r = svg.getBoundingClientRect(); const sx = (e.clientX - r.left) * W / r.width;
      const i = Math.max(0, Math.min(n - 1, Math.round((sx - L) / (W - L - R) * (n - 1))));
      xh.setAttribute('x1', x(i)); xh.setAttribute('x2', x(i)); xh.setAttribute('visibility', 'visible');
      xd.setAttribute('cx', x(i)); xd.setAttribute('cy', y(vals[i])); xd.setAttribute('visibility', 'visible');
      showTip(svg, x(i) * r.width / W, y(vals[i]) * r.height / H, fmt(vals[i]) + ' ' + unit, labels[i]);
    });
    hit.addEventListener('pointerleave', () => { xh.setAttribute('visibility', 'hidden'); xd.setAttribute('visibility', 'hidden'); hideTip(); });
  }
  function hbars(el, data, unit, fmtv = fmt) {
    const W = 520, rowH = 32, L = 150, R = 60, H = data.length * rowH + 6; const max = niceMax(Math.max(...data.map(d => d[1]))); const w = v => (W - L - R) * v / max;
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(unit)}">${data.map(([k, v], i) => {
      const yy = i * rowH + 6, bw = Math.max(5, w(v)); return `<text class="cat" x="${L - 10}" y="${yy + 15}" text-anchor="end">${esc(k)}</text>
      <path class="bar" d="M${L},${yy} h${bw - 4} a4,4 0 0 1 4,4 v12 a4,4 0 0 1 -4,4 h-${bw - 4} z"/>
      <text class="lab" x="${L + bw + 8}" y="${yy + 15}">${esc(fmtv(v))}</text><rect class="hb" data-i="${i}" x="0" y="${yy - 4}" width="${W}" height="${rowH}" tabindex="0"/>`;
    }).join('')}</svg>`;
    const svg = el.querySelector('svg');
    svg.querySelectorAll('.hb').forEach(h => {
      const i = +h.dataset.i;
      const on = () => { svg.querySelectorAll('.bar').forEach((b, j) => b.classList.toggle('dim', j !== i)); const r = svg.getBoundingClientRect(); showTip(svg, (L + w(data[i][1]) / 2) * r.width / W, (i * rowH + 6) * r.height / H, fmtv(data[i][1]), data[i][0]); };
      const off = () => { svg.querySelectorAll('.bar').forEach(b => b.classList.remove('dim')); hideTip(); };
      h.addEventListener('pointerenter', on); h.addEventListener('focus', on); h.addEventListener('pointerleave', off); h.addEventListener('blur', off);
    });
  }
  function columns(el, data, unit, fmtv) {
    const W = 520, H = 220, L = 44, R = 10, T = 20, B = 26; const max = niceMax(Math.max(...data.map(d => d[1]), 1) * 1.1);
    const n = data.length, band = (W - L - R) / n, bw = Math.min(26, band * 0.5); const y = v => T + (H - T - B) * (1 - v / max);
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(unit)}">${[0, max / 2, max].map(t => `<line class="gl" x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}"/><text class="ax" x="${L - 8}" y="${y(t) + 4}" text-anchor="end">${axisN(t)}</text>`).join('')}
     ${data.map(([k, v], i) => {
      const cx = L + band * i + band / 2, top = y(v), h = y(0) - top;
      return `${h > 0 ? `<path class="bar" d="M${cx - bw / 2},${y(0)} v-${Math.max(0, h - 4)} a4,4 0 0 1 4,-4 h${bw - 8} a4,4 0 0 1 4,4 v${Math.max(0, h - 4)} z"/>` : ''}<text class="ax" x="${cx}" y="${H - 6}" text-anchor="middle">${esc(k)}</text><rect class="hb" data-i="${i}" x="${L + band * i}" y="${T}" width="${band}" height="${H - T - B}" tabindex="0"/>`;
    }).join('')}</svg>`;
    const svg = el.querySelector('svg');
    svg.querySelectorAll('.hb').forEach(h => {
      const i = +h.dataset.i;
      const on = () => { const r = svg.getBoundingClientRect(); showTip(svg, (L + band * i + band / 2) * r.width / W, y(data[i][1]) * r.height / H, fmtv(data[i][1]), data[i][0]); };
      h.addEventListener('pointerenter', on); h.addEventListener('focus', on); h.addEventListener('pointerleave', hideTip); h.addEventListener('blur', hideTip);
    });
  }
  function donut(parts) {
    const tot = parts.reduce((s, p) => s + p[0], 0) || 1; let a = -Math.PI / 2; const R = 46, C = 56;
    const arcs = parts.map(([v, color]) => {
      if (!v) return '';
      const a2 = a + v / tot * Math.PI * 2 - (v === tot ? 0.0001 : 0); const big = a2 - a > Math.PI ? 1 : 0;
      const d = `M${C + R * Math.cos(a)},${C + R * Math.sin(a)} A${R},${R} 0 ${big} 1 ${C + R * Math.cos(a2)},${C + R * Math.sin(a2)}`; a = a2 + (v === tot ? 0 : 0);
      return `<path d="${d}" fill="none" stroke="${color}" stroke-width="14" stroke-linecap="butt"/>`;
    }).join('');
    return `<svg class="donut" viewBox="0 0 112 112" aria-hidden="true"><circle cx="56" cy="56" r="46" fill="none" stroke="var(--surface-muted)" stroke-width="14"/>${arcs}`;
  }

  // ---------- Umumiy komponentlar ----------
  const head = (t, p, right = '') => `<div class="head"><div><h1>${esc(t)}</h1>${p ? `<p>${p}</p>` : ''}</div>${right ? `<div class="row">${right}</div>` : ''}</div>`;
  const kpi = (icon, label, value, sub = '', cls = '') => `<div class="card kpi"><span class="ic ${cls}">${I(icon)}</span><div style="min-width:0"><div class="l">${esc(label)}</div><div class="v">${value}</div>${sub ? `<div class="s">${sub}</div>` : ''}</div></div>`;
  const deltaTag = (d, unit = '%') => (d == null ? '' : `<span class="d ${d >= 0 ? 'up' : 'dn'}">${I(d >= 0 ? 'up' : 'down', 'ico s')}${d >= 0 ? '+' : ''}${d}${unit}</span>`);
  const tabsBar = (sec, tabs, cur, cls = '') => `<div class="tabs ${cls}" role="tablist" aria-label="Bo'lim tablari">${tabs.map(([k, t, ic, n]) => `<button class="tab" role="tab" aria-selected="${cur === k}" data-tab="${k}" data-sec="${sec}">${ic ? I(ic) : ''}${esc(t)}${n != null ? ` <span class="tab-n">(${n})</span>` : ''}</button>`).join('')}</div>`;
  const emptyState = (title, text = '', icon = 'info', cls = '', extra = '') => `<div class="state ${cls}"><span class="ic">${I(icon, 'ico l')}</span><b>${esc(title)}</b>${text ? `<span class="small">${text}</span>` : ''}${extra}</div>`;
  const errState = e => `<div class="state bad"><span class="ic">${I('alert', 'ico l')}</span><b>Ma'lumotni olib bo'lmadi</b><span class="small">${esc(e.message || e)}</span><button class="btn sec sm" data-act="reload">${I('refresh', 'ico s')}Qayta urinish</button></div>`;
  const meter = (v, warn = 80, bad = 50) => (v == null ? '<span class="muted">—</span>'
    : `<div class="row" style="flex-wrap:nowrap;gap:10px"><div class="meter ${v < bad ? 'bad' : v < warn ? 'warn' : ''}" style="max-width:110px"><i style="width:${Math.max(0, Math.min(100, v))}%"></i></div><span class="num small"><b>${v}%</b></span></div>`);
  function pager(total, limit, offset, key) {
    const pages = Math.max(1, Math.ceil(total / limit)), cur = Math.floor(offset / limit) + 1;
    const nums = []; for (let p = 1; p <= pages; p++) if (p === 1 || p === pages || Math.abs(p - cur) <= 1) nums.push(p); else if (nums[nums.length - 1] !== '…') nums.push('…');
    return `<div class="tfoot"><span>${total ? `${offset + 1}–${Math.min(total, offset + limit)} / ${fmt(total)} ta` : '0 ta'}</span>
      <div class="pager"><label class="sr" for="ps-${key}">Sahifadagi yozuvlar</label><select id="ps-${key}" data-act="psize" data-k="${key}">${[25, 50, 100].map(n => `<option value="${n}" ${n === limit ? 'selected' : ''}>${n} ta</option>`).join('')}</select>
      <button data-act="page" data-k="${key}" data-v="${cur - 1}" ${cur <= 1 ? 'disabled' : ''} aria-label="Oldingi sahifa">${I('chevL', 'ico s')}</button>
      ${nums.map(p => p === '…' ? '<span class="muted">…</span>' : `<button data-act="page" data-k="${key}" data-v="${p}" aria-current="${p === cur}">${p}</button>`).join('')}
      <button data-act="page" data-k="${key}" data-v="${cur + 1}" ${cur >= pages ? 'disabled' : ''} aria-label="Keyingi sahifa">${I('chevR', 'ico s')}</button></div></div>`;
  }
  const sel = (id, label, opts, val, act, attrs = '') => `<div class="fld"><label for="${id}">${esc(label)}</label><select id="${id}" data-act="${act}" ${attrs}>${opts.map(([v, t]) => `<option value="${esc(v)}" ${String(v) === String(val) ? 'selected' : ''}>${esc(t)}</option>`).join('')}</select></div>`;
  const stale = s => { const d = parseTs(s); return d && Date.now() - d > 10 * 60000; };

  // ---------- Holat va marshrut ----------
  // URL: #bo'lim/tab (aktiv tab URL'da saqlanadi), foydalanuvchi profili: #users/<id> — brauzer Back drawer'ni yopadi
  const S = {
    sec: 'dash', tab: null, id: null, me: null, data: {}, badges: {}, mode: null, chartTable: {}, range: 30, metric: 'diag',
    uf: { q: '', role: 'all', state: 'all', region: '', plan: 'all', sort: 'new', limit: 25, offset: 0 },
    af: { q: '', online: 'all' }, kbf: { q: '', plant: '', state: 'all' }, modf: { q: '', kind: 'all', reason: 'all', sort: 'new' }, modSel: null,
    payf: { from: '', to: '', provider: 'all', status: 'all', env: 'all' }, subf: 'active', audf: { q: '', action: '', limit: 25, offset: 0 },
    dsf: { q: '', plant: '', model: 'all' },
  };
  const SEC = {};
  const ORDER = ['dash', 'users', 'agro', 'ai', 'kb', 'mod', 'pay', 'sys'];
  const keyOf = () => S.sec + ':' + (S.tab || '');
  const parseHash = () => { const [sec, a, b] = location.hash.slice(1).split('/'); return { sec: SEC[sec] ? sec : 'dash', a: a || null, b: b || null }; };

  // ================= 01. Boshqaruv paneli =================
  SEC.dash = {
    label: 'Boshqaruv paneli', short: 'Boshqaruv', ic: 'dash',
    async load() {
      const [d, recent, queue] = await Promise.all([api(`/admin/dashboard?days=${S.range}`), api('/admin/diagnoses?scope=recent&limit=4'), api('/admin/diagnoses?scope=queue&limit=5')]);
      S.badges = { agro: d.attention.applications, mod: d.attention.reports }; S.mode = d.payment_mode;
      return { d, recent, queue };
    },
    render({ d, recent, queue }) {
      const a = d.attention; const confirmed = d.ai_agreement == null ? 0 : Math.round(d.ai_agreement * d.reviewed / 100);
      const few = d.reviewed < 30;
      const tasks = [];
      if (a.applications) tasks.push(['c-info', 'usercheck', `${a.applications} ta agronom arizasi`, a.oldest_application_hours != null ? (a.oldest_application_hours < 1 ? 'Bugun keldi' : `Eng eskisi ${wait(a.oldest_application_hours * 60)} kutmoqda`) : '', 'agro/apps']);
      if (a.reports) tasks.push(['c-bad', 'flag', `${a.reports} ta shikoyat`, 'Jamoatdagi post va izohlar', 'mod/open']);
      if (a.queue) tasks.push(['c-warn', 'clock', `${a.queue} ta tashxis tekshiruvda`, 'Dehqon agronom tekshiruvini so\'ragan', 'ai/queue']);
      if (a.questions_stale) tasks.push(['c-warn', 'msg', `${a.questions_stale} ta javobsiz savol`, '4 soatdan ortiq kutmoqda', 'agro/active']);
      const b = a.backup || {};
      if (b.available && !b.ok) tasks.push(['c-bad', 'db', 'Zaxira muammosi', b.status || 'Hali zaxira olinmagan', 'sys/backups']);
      const vals = S.metric === 'users' ? d.users_daily.map(x => x.count) : d.diagnoses_daily.map(x => x.count);
      const lbl = d.diagnoses_daily.map(x => dayLbl(x.date));
      const unit = S.metric === 'users' ? 'foydalanuvchi' : 'tashxis';
      const statusB = x => x.review_status === 'pending' ? (x.review_requested ? badge('warn', "Ko'rib chiqilmoqda") : badge('info', 'Yangi'))
        : x.review_status === 'confirmed' ? badge('ok', 'Yakunlangan') : x.review_status === 'corrected' ? badge('ok', 'Tuzatilgan') : badge('', 'Rad etilgan');
      return `${head('Boshqaruv paneli', 'AgroYordam platformasining asosiy ko\'rsatkichlari va holati',
        `<label class="sr" for="rng">Davr</label><select id="rng" data-act="range" style="width:auto;min-width:170px">${[[7, 'Oxirgi 7 kun'], [30, 'Oxirgi 30 kun'], [90, 'Oxirgi 90 kun']].map(([k, t]) => `<option value="${k}" ${S.range === k ? 'selected' : ''}>${t}</option>`).join('')}</select>`)}
      <div class="g g4">
        ${kpi('users', 'Foydalanuvchilar', fmt(d.users_total), `${deltaTag(delta(d.users_new, d.users_new_prev))}<span>+${fmt(d.users_new)} so'nggi ${d.days} kunda</span>`)}
        ${kpi('agro', 'Tashxislar', fmt(d.diagnoses), `${deltaTag(delta(d.diagnoses, d.diagnoses_prev))}<span>so'nggi ${d.days} kunda</span>`)}
        ${kpi('clock', 'Tekshiruv navbatida', fmt(a.queue), '<span>agronom tekshiruvini kutmoqda</span>', 'c-warn')}
        ${kpi('shield', 'Moslik tekshiruvi', d.reviewed ? `${fmt(confirmed)} / ${fmt(d.reviewed)}` : '—',
          d.reviewed ? (few ? badge('warn sm', 'Namuna yetarli emas', 'alert') : `${badge('ok sm', `${d.ai_agreement}% mos`, 'check')}`) : '<span>hali ekspert tekshiruvi yo\'q</span>')}
      </div>
      <div class="g g84">
        <div class="card"><div class="ch"><div class="ttl">${I('chart', 'ico l')}<div><h2>Faollik grafigi</h2><div class="sub">So'nggi ${d.days} kun ichidagi faollik (${S.metric === 'users' ? "yangi foydalanuvchilar" : 'tashxislar soni'})</div></div></div>
          <div class="row"><label class="sr" for="mtr">Ko'rsatkich</label><select id="mtr" data-act="metric" style="width:auto;min-width:200px"><option value="diag" ${S.metric === 'diag' ? 'selected' : ''}>Tashxislar soni</option><option value="users" ${S.metric === 'users' ? 'selected' : ''}>Yangi foydalanuvchilar</option></select>
          <button class="btn ghost icon sm" data-act="tv" data-v="act" aria-pressed="${!!S.chartTable.act}" title="${S.chartTable.act ? 'Grafik' : 'Jadval'} ko'rinishi" aria-label="${S.chartTable.act ? 'Grafik' : 'Jadval'} ko'rinishi">${I(S.chartTable.act ? 'chart' : 'table')}</button></div></div>
          <div class="chart" id="c-act">${S.chartTable.act ? `<div class="tw" style="max-height:250px"><table style="min-width:0"><thead><tr><th>Kun</th><th class="n">${esc(unit)}</th></tr></thead><tbody>${vals.map((v, i) => [lbl[i], v]).reverse().map(([k, v]) => `<tr><td>${esc(k)}</td><td class="n">${fmt(v)}</td></tr>`).join('')}</tbody></table></div>` : ''}</div></div>
        <div class="col">
          ${few ? `<div class="banner warn" style="flex-direction:column;gap:10px"><div class="row" style="flex-wrap:nowrap;gap:12px">${I('alertc', 'ico l')}<b>Ma'lumot yetarli emas</b></div><p>AI sifatini baholash uchun kamida 30 ta ekspert tekshiruvi kerak (hozir ${fmt(d.reviewed)} ta). Agronomlar navbatni tekshirgani sari baho aniqlashadi.</p><button class="btn pri" data-go="ai/dataset" style="margin-top:6px">Batafsil ma'lumot</button></div>` : ''}
          <div class="card"><div class="ch"><h2>Navbatdagi ishlar</h2></div>
          ${tasks.length ? `<div class="list">${tasks.map(([c, ic, t, s, go]) => `<div class="li"><span class="ic ${c}" style="width:40px;height:40px;border-radius:999px;display:grid;place-items:center;flex:none">${I(ic)}</span><div class="grow"><div class="t">${esc(t)}</div><div class="m">${esc(s)}</div></div><button class="btn sec sm" data-go="${go}">Ko'rish</button></div>`).join('')}</div>`
          : emptyState("Kutayotgan ish yo'q", 'Arizalar, shikoyatlar va tekshiruv navbati bo\'sh.', 'check', 'ok')}</div>
        </div>
      </div>
      <div class="g g2">
        <div class="card"><div class="ch"><div class="ttl">${I('agro', 'ico l')}<h2>So'nggi tashxislar</h2></div></div>
          ${recent.items.length ? `<div class="list">${recent.items.map(x => `<div class="li">${thumb(media(x.image_url), x.disease || 'Tashxis')}<div class="grow"><div class="t">${esc(x.disease || 'Aniqlanmadi')}</div><div class="m">${esc([x.plant, x.region].filter(Boolean).join(' • ') || '—')} • ${ago(x.created_at)}</div></div>${statusB(x)}</div>`).join('')}</div>`
          : emptyState("Hali tashxis yo'q")}</div>
        <div class="card"><div class="ch"><div class="ttl">${I('clock', 'ico l')}<h2>Tekshiruv navbatida (${fmt(queue.queue_total)})</h2></div>${queue.queue_total ? `<button class="link" data-go="ai/queue">Barchasini ko'rish ${I('arrow', 'ico s')}</button>` : ''}</div>
          ${queue.items.length ? `<div class="list">${queue.items.map((x, i) => `<div class="li">${thumb(media(x.image_url), x.disease || 'Tashxis')}<div class="grow"><div class="t">${esc(x.disease || 'Aniqlanmadi')}</div><div class="m">${esc([x.plant, x.region].filter(Boolean).join(' • ') || '—')} • ${ago(x.created_at)}</div></div><button class="btn pri sm" data-act="diag" data-v="${i}">Ko'rish</button></div>`).join('')}</div>` : emptyState("Navbat bo'sh", "Dehqonlar agronom tekshiruvini so'ramagan.", 'check', 'ok')}</div>
      </div>
      <div class="g g2">
        <div class="card"><div class="ch"><div><h2>Foydalanuvchilar viloyatlar bo'yicha</h2><div class="sub">Jami ${fmt(d.regions.reduce((s, r) => s + r.count, 0))}</div></div></div><div class="chart" id="c-reg" style="min-height:0"></div></div>
        <div class="card"><div class="ch"><div><h2>AI aniqligi ekinlar bo'yicha</h2><div class="sub">Agronom tekshiruvi bilan mos kelish, %</div></div></div>
          <div class="chart" id="c-crop" style="min-height:0">${d.crop_accuracy.length ? '' : emptyState("Hali agronom tekshirgan tashxis yo'q", 'Agronomlar navbatni tekshira boshlagach shu yerda ko\'rinadi.')}</div></div>
      </div>`;
    },
    after({ d }) {
      const vals = S.metric === 'users' ? d.users_daily.map(x => x.count) : d.diagnoses_daily.map(x => x.count);
      if (!S.chartTable.act && vals.length > 1) lineChart(document.getElementById('c-act'), vals, d.diagnoses_daily.map(x => dayLbl(x.date)), S.metric === 'users' ? 'foydalanuvchi' : 'tashxis');
      if (d.regions.length) hbars(document.getElementById('c-reg'), d.regions.map(r => [r.region, r.count]), 'foydalanuvchi');
      if (d.crop_accuracy.length) hbars(document.getElementById('c-crop'), d.crop_accuracy.map(r => [r.crop, r.accuracy]), 'aniqlik', v => v + '%');
    },
  };
  function diagModal(x) {
    modal(`<div class="row sp"><h3>${esc(x.disease || 'Aniqlanmadi')}</h3><button class="btn ghost icon" data-act="mclose" aria-label="Yopish">${I('x')}</button></div>
      <div class="g g2" style="gap:20px"><img class="zoom" src="${esc(media(x.image_url))}" alt="Dehqon yuborgan asl rasm">
      <div class="col" style="gap:12px"><div class="fact"><span class="lbl muted xs">AI taxmini</span><b>${esc(x.disease || x.ai_label || 'Aniqlanmadi')}</b>${x.confidence != null ? ` · ishonch ${String(x.confidence).replace('.', ',')}%` : ''}</div>
        ${x.verified_label ? `<div class="fact"><span class="lbl muted xs">Ekspert yakuniy xulosasi</span><b>${esc(x.verified_label)}</b></div>` : `<div class="fact"><span class="lbl muted xs">Ekspert yakuniy xulosasi</span><span class="muted">Hali tekshirilmagan</span></div>`}
        ${x.review_note ? `<div class="quote"><span class="lbl">Dehqon izohi</span>${esc(x.review_note)}</div>` : ''}
        <dl class="kv"><dt>Ekin</dt><dd>${esc(x.plant || '—')}</dd><dt>Hudud</dt><dd>${esc(x.region || '—')}</dd><dt>Dehqon</dt><dd>${esc(x.user || '—')}</dd><dt>Yuborilgan</dt><dd>${fmtDT(x.created_at)}</dd></dl>
        <p class="muted small">Belgilashni agronomlar ilovadagi «Tekshiruv navbati»da bajaradi.</p></div></div>`, true);
  }

  // ================= 02. Foydalanuvchilar =================
  SEC.users = {
    label: 'Foydalanuvchilar', ic: 'users',
    async load() {
      const f = S.uf;
      const [stats, page] = await Promise.all([api('/admin/users/stats'), api('/admin/users/page?' + q({ q: f.q, role: f.role, state: f.state, region: f.region, plan: f.plan, sort: f.sort, limit: f.limit, offset: f.offset }))]);
      return { stats, page };
    },
    render({ stats, page }) {
      const f = S.uf; const dirty = f.q || f.role !== 'all' || f.state !== 'all' || f.region || f.plan !== 'all';
      const stB = u => (!u.is_active ? badge('bad', 'Bloklangan', 'lock') : u.last_active && Date.now() - parseTs(u.last_active) < 30 * 864e5 ? badge('ok', 'Faol', 'dot') : badge('warn', 'Nofaol', 'dot'));
      return `${head('Foydalanuvchilar', "Platformadan foydalanayotgan barcha foydalanuvchilar ro'yxati va ularning holati.")}
      <div class="g g4">
        ${kpi('users', 'Jami foydalanuvchilar', fmt(stats.total), stats.blocked ? `<span>${fmt(stats.blocked)} ta bloklangan</span>` : '<span>bloklangan yo\'q</span>')}
        ${kpi('user', 'Faol foydalanuvchilar', fmt(stats.active), "<span>so'nggi 30 kunda kirgan</span>")}
        ${kpi('clock', 'Nofaol foydalanuvchilar', fmt(stats.inactive), '<span>30 kundan beri kirmagan</span>', 'c-warn')}
        ${kpi('plus', 'Yangi foydalanuvchilar', fmt(stats.new), `${deltaTag(delta(stats.new, stats.new_prev))}<span>so'nggi 30 kunda</span>`)}
      </div>
      <div class="card" style="padding:20px">
        <div class="filters"><label class="search"><span class="sr">Qidiruv</span>${I('search')}<input id="uq" data-q="uf" placeholder="Ism, login, telefon yoki hudud bo'yicha qidirish…" value="${esc(f.q)}"></label>
          ${sel('ur', 'Rol', [['all', 'Barcha rollar'], ['user', 'Dehqon'], ['agronomist', 'Agronom'], ['moderator', 'Moderator'], ['admin', 'Admin']], f.role, 'uf', 'data-k="role"')}
          ${sel('us', 'Holat', [['all', 'Barcha holatlar'], ['active', 'Faol'], ['inactive', 'Nofaol'], ['blocked', 'Bloklangan']], f.state, 'uf', 'data-k="state"')}
          ${sel('ug', 'Hudud', [['', 'Barcha hududlar'], ...stats.regions.map(r => [r, r])], f.region, 'uf', 'data-k="region"')}
          ${sel('up', 'Obuna', [['all', 'Barchasi'], ['premium', 'Premium'], ['free', 'Bepul']], f.plan, 'uf', 'data-k="plan"')}
          ${sel('uo', 'Saralash', [['new', 'Eng yangi'], ['old', 'Eng eski'], ['name', 'Ism bo\'yicha'], ['active', 'Oxirgi faollik']], f.sort, 'uf', 'data-k="sort"')}
          ${dirty ? `<button class="btn ghost" data-act="uclear">${I('x', 'ico s')}Tozalash</button>` : ''}
        </div>
      </div>
      <div>
        <div class="tw"><table><thead><tr><th>#</th><th>Foydalanuvchi</th><th>Hudud</th><th>Roli</th><th>Obuna</th><th class="n">Tashxislar</th><th>Qo'shilgan sana</th><th>Oxirgi faollik</th><th>Holati</th><th><span class="sr">Amallar</span></th></tr></thead><tbody>
        ${page.items.map((u, i) => `<tr class="click" data-act="user" data-v="${u.id}" tabindex="0" aria-label="${esc(u.full_name)} profilini ochish"><td class="num muted">${f.offset + i + 1}</td>
          <td><div class="who">${avatar(u.full_name, u.avatar_url)}<div style="min-width:0"><b>${esc(u.full_name)}</b><div class="muted xs">${esc(u.phone_masked || u.email_masked || '@' + u.username)}</div></div></div></td>
          <td>${esc(u.region || '—')}</td><td>${roleB(u.role)}</td>
          <td>${u.is_premium ? (u.premium_source === 'sandbox' ? badge('warn', 'Premium · sinov') : badge('act', 'Premium', 'crown')) : '<span class="muted">Bepul</span>'}</td>
          <td class="n">${fmt(u.diagnoses)}</td><td class="num">${fmtDate(u.created_at)}</td><td>${u.last_active ? ago(u.last_active) : '<span class="muted">—</span>'}</td>
          <td>${stB(u)}</td><td><button class="btn pri sm" data-act="user" data-v="${u.id}">Ko'rish</button></td></tr>`).join('')}
        </tbody></table>${page.items.length ? '' : (dirty ? emptyState("Hech kim topilmadi", "Qidiruv yoki filtrlarni o'zgartiring.", 'search', '', '<button class="btn sec sm" data-act="uclear">Filtrlarni tozalash</button>') : emptyState("Hali foydalanuvchi yo'q"))}</div>
        ${pager(page.total, f.limit, f.offset, 'users')}
      </div>`;
    },
  };
  async function openUser(id, tab = 'main') {
    S.drawerUser = { id, tab, data: null, show: false };
    drawer(`<div class="dh"><div class="row sp"><div class="sk" style="height:32px;width:60%"></div><button class="btn ghost icon" data-act="close" aria-label="Yopish">${I('x')}</button></div></div><div class="db"><div class="sk" style="height:96px;width:96px;border-radius:999px"></div><div class="sk" style="height:220px"></div></div>`, 'user');
    try { S.drawerUser.data = await api(`/admin/users/${id}/detail`); paintUser(); }
    catch (e) { document.querySelector('.drawer .db').innerHTML = errState(e); }
  }
  function paintUser() {
    const st = S.drawerUser; const u = st.data; const dr = document.querySelector('.drawer'); if (!dr || !u) return;
    const tabs = [['main', 'Umumiy'], ['act', 'Faollik'], ['sub', 'Obuna'], ['lim', 'Cheklovlar'], ['audit', 'Audit']];
    const status = !u.is_active ? badge('bad', 'Bloklangan', 'lock') : u.last_active && Date.now() - parseTs(u.last_active) < 30 * 864e5 ? badge('ok', 'Faol', 'dot') : badge('warn', 'Nofaol', 'dot');
    const contact = (raw, masked) => (raw ? `<span class="mono">${esc(st.show ? raw : masked)}</span>` : '—');
    let body = '';
    if (st.tab === 'main') body = `<div class="row sp"><h4 class="h2">Asosiy ma'lumotlar</h4>${u.phone || u.email ? `<button class="btn ghost sm" data-act="ushow" aria-pressed="${st.show}">${I(st.show ? 'eyeoff' : 'eye', 'ico s')}${st.show ? 'Yashirish' : "Kontaktni ko'rsatish"}</button>` : ''}</div>
      <dl class="kv"><dt>Ism familiya</dt><dd>${esc(u.full_name)}</dd><dt>Login</dt><dd class="mono">@${esc(u.username)}</dd><dt>Telefon</dt><dd>${contact(u.phone, u.phone_masked)}</dd><dt>Email</dt><dd>${contact(u.email, u.email_masked)}</dd>
      <dt>Foydalanuvchi turi</dt><dd>${esc((ROLES[u.role] || ROLES.user)[1])}</dd><dt>Hudud</dt><dd>${esc(u.region || '—')}</dd><dt>Tuman</dt><dd>${esc(u.district || '—')}</dd>
      ${u.farm_type ? `<dt>Xo'jalik</dt><dd>${esc(u.farm_type)}${u.farm_area ? ` · ${String(u.farm_area).replace('.', ',')} ga` : ''}</dd>` : ''}
      ${u.main_crops.length ? `<dt>Ekinlari</dt><dd><div class="chips">${u.main_crops.map(c => `<span class="chip">${esc(c)}</span>`).join('')}</div></dd>` : ''}
      ${u.specialization ? `<dt>Mutaxassislik</dt><dd>${esc(u.specialization)}${u.experience_years != null ? ` · ${u.experience_years} yil` : ''}</dd>` : ''}
      <dt>Ro'yxatdan o'tgan</dt><dd>${fmtDT(u.created_at)}</dd><dt>Oxirgi faollik</dt><dd>${u.last_active ? fmtDT(u.last_active) : '—'}</dd></dl>`;
    else if (st.tab === 'act') body = `<h4 class="h2">Statistika</h4><div class="stats">${[['agro', 'Tashxislar', u.activity.diagnoses], ['leafs', 'Ekinlar', u.activity.crops], ['chat', 'Postlar', u.activity.posts], ['msg', 'Izohlar', u.activity.comments], ['users', 'Agronomga savollar', u.activity.questions], ['flag', 'Unga shikoyatlar', u.activity.reports_against]]
      .map(([ic, k, v]) => `<div class="stat"><span class="ic">${I(ic)}</span><div><div class="k">${k}</div><div class="v">${fmt(v)}</div></div></div>`).join('')}</div>`;
    else if (st.tab === 'sub') body = `<h4 class="h2">Obuna</h4><div class="fact">${u.is_premium ? `<b>Premium</b>${u.premium_until ? ` · ${fmtDate(u.premium_until)} gacha` : ''}` : '<b>Bepul tarif</b>'}</div>
      ${u.subscriptions.length ? `<div class="list">${u.subscriptions.map(s => `<div class="li"><div class="grow"><div class="t">${esc(PLAN[s.plan] || s.plan)} · ${sum(s.price)}</div><div class="m">${fmtDate(s.created_at)} · ${esc(PROV[s.provider]?.[0] || s.provider || '—')}${s.expires_at ? ` · ${fmtDate(s.expires_at)} gacha` : ''}</div></div>${s.sandbox ? badge('warn sm', 'Sinov') : s.paid ? badge('ok sm', "To'langan") : badge('sm', "To'lanmagan")}</div>`).join('')}</div>` : '<p class="muted">To\'lovlar tarixi yo\'q.</p>'}`;
    else if (st.tab === 'lim') {
      const self = S.me && S.me.id === u.id;
      body = `<h4 class="h2">Hisob amallari</h4><p class="muted small">Rol, parol va bloklash profil ma'lumotlaridan alohida. Har biri harakatlar jurnaliga yoziladi.</p>
      <div class="card flat" style="padding:16px;display:grid;gap:12px"><div class="fld"><label for="role-s">Rol</label><select id="role-s" ${self ? 'disabled' : ''}>${Object.entries(ROLES).map(([k, [, t]]) => `<option value="${k}" ${u.role === k ? 'selected' : ''}>${t}</option>`).join('')}</select>${self ? '<span class="help">O\'z rolingizni o\'zgartira olmaysiz.</span>' : ''}</div>
        <div><button class="btn sec" data-act="saverole" ${self ? 'disabled' : ''}>Rolni saqlash</button></div></div>
      ${u.role === 'admin' ? '' : `<div class="card flat" style="padding:16px;display:grid;gap:10px"><b>Parol</b><span class="muted small">Unutgan bo'lsa — vaqtinchalik parol beriladi, barcha qurilmalardan chiqariladi. Eski parol ko'rsatilmaydi.</span><div><button class="btn sec" data-act="pwreset" data-v="${u.id}" data-n="${esc(u.full_name)}">${I('key', 'ico s')}Vaqtinchalik parol berish</button></div></div>`}
      <div class="card flat" style="padding:16px;display:grid;gap:10px"><b>Bloklash</b>${!u.is_active ? `<span class="muted small">Hisob bloklangan — foydalanuvchi ilovaga kira olmaydi.</span><div><button class="btn sec" data-act="unblock" data-v="${u.id}">${I('unlock', 'ico s')}Blokdan chiqarish</button></div>`
        : u.role === 'admin' ? '<span class="muted small">Adminni bloklab bo\'lmaydi.</span>' : `<span class="muted small">Bloklangan foydalanuvchi ilovaga kira olmaydi; ma'lumotlari saqlanadi.</span><div><button class="btn dan-out" data-act="blockask" data-v="${u.id}" data-n="${esc(u.full_name)}">${I('lock', 'ico s')}Hisobni bloklash</button></div>`}</div>`;
    } else body = `<h4 class="h2">Audit</h4>${u.audit.length ? `<ul class="timeline">${u.audit.map(a => `<li class="done"><div><b class="small">${esc(ACTIONS[a.action] || a.action)}</b><div class="muted xs">${esc(a.summary)} · ${esc(a.actor)}</div></div><span class="xs muted">${ago(a.created_at)}</span></li>`).join('')}</ul>` : '<p class="muted">Bu foydalanuvchi bo\'yicha admin harakati yo\'q.</p>'}`;
    dr.innerHTML = `<div class="dh"><div class="row sp" style="align-items:flex-start;flex-wrap:nowrap"><h3 id="dr-t">${esc(u.full_name)}</h3><button class="btn ghost icon" data-act="close" aria-label="Yopish">${I('x')}</button></div>
      <div class="row" style="gap:16px;flex-wrap:nowrap">${avatar(u.full_name, u.avatar_url, 'lg')}<div class="col" style="gap:8px"><div class="row">${status}${roleB(u.role)}</div>${u.is_premium ? badge('act', 'Premium', 'crown') : ''}</div></div>
      <div class="tabs" role="tablist">${tabs.map(([k, t]) => `<button class="tab" role="tab" aria-selected="${st.tab === k}" data-act="utab" data-v="${k}">${t}</button>`).join('')}</div></div>
      <div class="db">${body}</div>`;
    dr.setAttribute('aria-labelledby', 'dr-t');
  }
  function pwModal(r) {
    modal(`<h3>Vaqtinchalik parol</h3><p class="muted">${esc(r.full_name)} uchun yangi parol yaratildi. Uni shaxsan (qo'ng'iroq yoki SMS orqali) bering.</p>
      <dl class="kv"><dt>Login</dt><dd class="mono">${esc(r.username)}</dd><dt>Parol</dt><dd><b class="mono" style="font-size:18px">${esc(r.password)}</b></dd></dl>
      <div class="banner warn">${I('alert')}<p>Bu oynani yopgach parolni qayta ko'rib bo'lmaydi. Foydalanuvchi kirgach, Profil → «Parolni o'zgartirish» orqali o'z parolini qo'yadi.</p></div>
      <div class="acts"><button class="btn sec" data-act="mclose">Yopish</button><button class="btn pri" data-act="pwcopy" data-u="${esc(r.username)}" data-p="${esc(r.password)}">${I('copy', 'ico s')}Login va parolni nusxalash</button></div>`);
  }

  // ================= 03. Agronomlar =================
  SEC.agro = {
    label: 'Agronomlar', ic: 'agro', badge: () => S.badges.agro,
    tabs: () => [['apps', 'Arizalar', 'doc'], ['active', 'Faol agronomlar', 'users'], ['history', 'Faoliyat tarixi', 'chart']], def: 'apps',
    async load() { const [apps, experts] = await Promise.all([api('/admin/expert-applications?status=all'), api('/admin/experts')]); S.badges.agro = apps.filter(a => a.status === 'pending').length; return { apps, experts }; },
    render({ apps, experts }, tab) {
      const m30 = Date.now() - 30 * 864e5; const pending = apps.filter(a => a.status === 'pending');
      const recent = apps.filter(a => parseTs(a.created_at) >= m30).length; const rej30 = apps.filter(a => a.status === 'rejected' && parseTs(a.reviewed_at) >= m30).length;
      let body = '';
      if (tab === 'apps') {
        body = `<div class="card"><div class="ch"><div><h2>Yangi agronom arizalari</h2><div class="sub">Quyidagi arizalarni ko'rib chiqib, tegishli qaror qabul qiling.</div></div></div>
        ${pending.length ? `<div class="g g2" style="gap:16px">${pending.map(a => `<div class="appc"><span class="av" style="width:52px;height:52px">${initials(a.full_name)}</span>
          <div style="min-width:0;display:grid;gap:6px"><b style="font-size:17px">${esc(a.full_name)}</b><div class="m">${I('agro', 'ico s')}${esc(a.specialization)} · tajriba ${a.experience_years} yil</div>
          <div class="m">${I('pin', 'ico s')}${esc(a.region || 'Hudud ko\'rsatilmagan')}</div><div class="m">${I('cal', 'ico s')}${fmtDate(a.created_at)} yuborilgan · ${ago(a.created_at)}</div></div>
          <div class="col" style="gap:12px;justify-items:end">${badge('warn', "Ko'rib chiqilmoqda", 'clock')}<button class="btn pri" data-act="app" data-v="${a.id}">${I('doc', 'ico s')}Ko'rib chiqish</button></div></div>`).join('')}</div>`
          : emptyState('Barcha arizalar ko\'rib chiqilgan', "Yangi ariza kelsa, shu yerda va menyuda raqam bilan ko'rinadi.", 'check', 'ok', '<button class="btn sec sm" data-go="agro/history">Faoliyat tarixi</button>')}</div>`;
      } else if (tab === 'active') {
        const f = S.af; const list = experts.filter(e => (f.online === 'all' || (f.online === 'on') === e.accepting_questions) && (!f.q || [e.full_name, e.specialization, e.region].join(' ').toLowerCase().includes(f.q.toLowerCase())));
        body = `<div class="card"><div class="ch"><div><h2>Agronomlar ro'yxati</h2><div class="sub">Faol agronomlar va ularning faoliyati (so'nggi 30 kun)</div></div>
          <div class="filters"><label class="search" style="min-width:260px"><span class="sr">Qidiruv</span>${I('search')}<input id="aq" data-q="af" placeholder="Ism, mutaxassislik yoki hudud bo'yicha…" value="${esc(f.q)}"></label>
          <label class="sr" for="ao">Holat</label><select id="ao" data-act="af" data-k="online" style="width:auto"><option value="all">Barcha holatlar</option><option value="on" ${f.online === 'on' ? 'selected' : ''}>Savol qabul qiladi</option><option value="off" ${f.online === 'off' ? 'selected' : ''}>Savol qabul qilmaydi</option></select></div></div>
        <div class="tw"><table><thead><tr><th>#</th><th>Ism va familiya</th><th>Mutaxassislik yo'nalishi</th><th>Hudud</th><th class="n">Ko'rib chiqilgan tashxislar</th><th class="n">Javoblar</th><th>O'rtacha javob vaqti</th><th class="n">Reyting</th><th>AI bilan moslik</th><th>Holati</th><th><span class="sr">Amallar</span></th></tr></thead><tbody>
        ${list.map((e, i) => `<tr><td class="num muted">${i + 1}</td><td><div class="who">${avatar(e.full_name)}<b>${esc(e.full_name)}</b></div></td><td class="small">${esc(e.specialization || '—')}</td><td>${esc(e.region || '—')}</td>
          <td class="n">${fmt(e.reviewed)}<div class="muted xs">30 kunda ${fmt(e.reviewed_30d)}</div></td><td class="n">${fmt(e.answers_30d)}</td><td>${wait(e.avg_answer_minutes)}</td>
          <td class="n">${e.rating == null ? '<span class="muted">—</span>' : '★ ' + String(e.rating).replace('.', ',')}</td><td>${meter(e.ai_agreement)}</td>
          <td>${e.accepting_questions ? badge('ok', 'Faol', 'dot') : badge('', 'Dam olmoqda', 'dot')}</td><td><button class="btn out sm" data-act="expert" data-v="${e.id}">${I('eye', 'ico s')}Ko'rish</button></td></tr>`).join('')}
        </tbody></table>${list.length ? '' : emptyState(experts.length ? 'Hech kim topilmadi' : "Hali agronom yo'q", experts.length ? 'Qidiruvni o\'zgartiring.' : "Arizani tasdiqlang yoki Foydalanuvchilar bo'limida rol bering.")}</div></div>`;
      } else {
        const done = apps.filter(a => a.status !== 'pending').sort((a, b) => parseTs(b.reviewed_at || b.created_at) - parseTs(a.reviewed_at || a.created_at));
        body = `<div class="card"><div class="ch"><div><h2>Faoliyat tarixi</h2><div class="sub">Ko'rib chiqilgan arizalar va qarorlar</div></div></div>
        ${done.length ? `<div class="tw"><table><thead><tr><th>Ariza beruvchi</th><th>Mutaxassislik</th><th>Hudud</th><th>Yuborilgan</th><th>Qaror</th><th>Qaror sanasi</th><th>Izoh</th></tr></thead><tbody>
          ${done.map(a => `<tr><td><div class="who">${avatar(a.full_name)}<b>${esc(a.full_name)}</b></div></td><td class="small">${esc(a.specialization)}</td><td>${esc(a.region || '—')}</td><td>${fmtDate(a.created_at)}</td>
            <td>${a.status === 'approved' ? badge('ok', 'Tasdiqlangan', 'check') : badge('bad', 'Rad etilgan', 'xc')}</td><td>${fmtDate(a.reviewed_at)}</td><td class="small">${esc(a.reason || '—')}</td></tr>`).join('')}
        </tbody></table></div>` : emptyState("Hali ko'rib chiqilgan ariza yo'q")}</div>`;
      }
      return `${head('Agronomlar', "Agronomlar arizalarini ko'rib chiqing, ekspertlarni boshqaring va ularning faoliyatini kuzating.")}
      <div class="g g4">
        ${kpi('doc', 'Jami arizalar', fmt(apps.length), `<span>+${fmt(recent)} so'nggi 30 kunda</span>`, 'c-act')}
        ${kpi('user', 'Faol agronomlar', fmt(experts.length), `<span>${fmt(experts.filter(e => e.accepting_questions).length)} tasi savol qabul qiladi</span>`)}
        ${kpi('clock', "Ko'rib chiqilmoqda", fmt(pending.length), '<span>javob kutilmoqda</span>', 'c-warn')}
        ${kpi('xc', 'Rad etilgan arizalar', fmt(rej30), "<span>so'nggi 30 kunda</span>", 'c-bad')}
      </div>
      ${tabsBar('agro', SEC.agro.tabs().map(t => t[0] === 'apps' ? [...t, pending.length] : t), tab)}
      ${body}`;
    },
  };
  function appDrawer(a) {
    drawer(`<div class="dh"><div class="row sp"><h3 id="dr-t">Agronom arizasi</h3><button class="btn ghost icon" data-act="close" aria-label="Yopish">${I('x')}</button></div>
      <div class="row" style="gap:14px;flex-wrap:nowrap"><span class="av" style="width:64px;height:64px;font-size:20px">${initials(a.full_name)}</span><div><b style="font-size:18px">${esc(a.full_name)}</b><div class="muted small">${ago(a.created_at)} yuborilgan</div></div></div></div>
      <div class="db"><dl class="kv"><dt>Mutaxassislik</dt><dd>${esc(a.specialization)}</dd><dt>Tajriba</dt><dd>${a.experience_years} yil</dd><dt>Hudud</dt><dd>${esc(a.region || '—')}</dd><dt>Telefon</dt><dd class="mono">${esc(a.phone || '—')}</dd><dt>Yuborilgan</dt><dd>${fmtDT(a.created_at)}</dd></dl>
      ${a.about ? `<div><div class="lbl" style="margin-bottom:6px">O'zi haqida</div><div class="fact">${esc(a.about)}</div></div>` : ''}
      <div><div class="lbl" style="margin-bottom:6px">Hujjatlar</div>${a.document_url ? `<a class="btn sec" href="${esc(media(a.document_url))}" target="_blank" rel="noopener">${I('doc', 'ico s')}Hujjatni ochish${I('ext', 'ico s')}</a>` : '<div class="banner warn">' + I('alert') + '<p>Hujjat yuklanmagan. Rad etishda shu sababni tanlash mumkin.</p></div>'}</div>
      <div><div class="lbl" style="margin-bottom:6px">Tekshiruv tarixi</div><ul class="timeline"><li class="done"><div><b class="small">Ariza yuborildi</b></div><span class="xs muted">${fmtDT(a.created_at)}</span></li><li><div><b class="small">Qaror</b><div class="muted xs">Hali qaror chiqarilmagan</div></div><span class="xs muted">—</span></li></ul></div></div>
      <div class="df"><button class="btn dan-out" data-act="appreject" data-v="${a.id}" data-n="${esc(a.full_name)}">Arizani rad etish</button><button class="btn ok" data-act="approve" data-v="${a.id}" data-n="${esc(a.full_name)}" style="margin-left:auto">${I('check', 'ico s')}Arizani tasdiqlash</button></div>`, 'app');
  }
  function expertDrawer(e) {
    drawer(`<div class="dh"><div class="row sp"><h3 id="dr-t">${esc(e.full_name)}</h3><button class="btn ghost icon" data-act="close" aria-label="Yopish">${I('x')}</button></div>
      <div class="row">${badge('info', 'Agronom')}${e.accepting_questions ? badge('ok', 'Savol qabul qiladi', 'dot') : badge('', 'Dam olmoqda', 'dot')}</div></div>
      <div class="db"><dl class="kv"><dt>Mutaxassislik</dt><dd>${esc(e.specialization || '—')}</dd><dt>Hudud</dt><dd>${esc(e.region || '—')}</dd><dt>Login</dt><dd class="mono">@${esc(e.username)}</dd></dl>
      <div class="stats">${[['agro', 'Tekshirgan tashxislar', fmt(e.reviewed)], ['clock', "O'rtacha javob", wait(e.avg_answer_minutes)], ['msg', 'Javoblar (30 kun)', fmt(e.answers_30d)], ['star', 'Reyting', e.rating == null ? '—' : String(e.rating).replace('.', ',')]].map(([ic, k, v]) => `<div class="stat"><span class="ic">${I(ic)}</span><div><div class="k">${k}</div><div class="v">${v}</div></div></div>`).join('')}</div>
      <div><div class="lbl" style="margin-bottom:6px">AI bilan moslik</div>${meter(e.ai_agreement)}<p class="muted xs" style="margin-top:6px">Agronom tasdiqlagan tashxislar ulushi (AI to'g'ri topgan).</p></div>
      <div class="card flat" style="padding:16px;display:grid;gap:10px"><b>Vakolat</b><span class="muted small">Agronom vakolatini to'xtatish hisobni bloklamaydi — u oddiy dehqon bo'lib qoladi. Bloklash Foydalanuvchilar bo'limida.</span>
        <div class="row"><button class="btn sec" data-act="pwreset" data-v="${e.id}" data-n="${esc(e.full_name)}">${I('key', 'ico s')}Vaqtinchalik parol</button><button class="btn dan-out" data-act="revoke" data-v="${e.id}" data-n="${esc(e.full_name)}">Vakolatni to'xtatish</button></div></div>
      <button class="link" data-act="user" data-v="${e.id}">To'liq profilni ko'rish ${I('arrow', 'ico s')}</button></div>`, 'expert');
  }

  // ================= 04. AI nazorati =================
  const isRunning = t => (t?.runs || []).some(r => r.status !== 'completed');
  SEC.ai = {
    label: 'AI nazorati', ic: 'ai',
    tabs: () => [['model', 'Model'], ['queue', 'Tekshiruv navbati'], ['dataset', 'Dataset'], ['training', "O'qitish tarixi"]], def: 'model',
    async load(tab) {
      if (tab === 'model') { const [a, models] = await Promise.all([api('/admin/ai'), api('/admin/ai/models')]); return { a, models }; }
      if (tab === 'queue') return { queue: await api('/admin/diagnoses?scope=queue&limit=60') };
      if (tab === 'dataset') { const [a, coverage] = await Promise.all([api('/admin/ai'), api('/admin/ai/coverage')]); return { a, coverage }; }
      const [training, a, models] = await Promise.all([api('/admin/ai/training'), api('/admin/ai'), api('/admin/ai/models')]); return { training, a, models };
    },
    render(d, tab) {
      let body = '';
      if (tab === 'model') body = aiModel(d); else if (tab === 'queue') body = aiQueue(d); else if (tab === 'dataset') body = aiDataset(d); else body = aiTraining(d);
      return `${head('AI nazorati', "Model holatini kuzating, ma'lumotlarni tekshiring va o'qitish jarayonini boshqaring.")}${tabsBar('ai', SEC.ai.tabs(), tab, 'seg')}${body}`;
    },
    after(d, tab) { clearTimeout(S.trainTimer); if (tab === 'training' && isRunning(d.training)) S.trainTimer = setTimeout(() => { if (S.sec === 'ai' && S.tab === 'training') load(true); }, 20000); },
  };
  function aiModel({ a, models }) {
    const m = models.active || a.model || {}; const tag = models.active_tag || m.model_tag;
    const cur = models.models.find(r => r.active) || {}; const activeN = +(tag || '').replace('model-v', '') || 0;
    const noField = cur.field_test_accuracy == null;
    const metrics = m.metrics || {};
    return `<div class="g" style="grid-template-columns:minmax(0,1.6fr) minmax(0,1fr) minmax(0,1fr)">
      <div class="card"><div class="ch"><div class="ttl">${I('cube', 'ico l')}<h2>Joriy model</h2></div></div>
        <div class="row" style="gap:16px;align-items:flex-start;flex-wrap:wrap"><div style="flex:1;min-width:220px"><div class="row"><b style="font-size:30px;line-height:38px">${esc(tag || m.model || 'Noma\'lum')}</b>${a.model ? badge('ok', 'Faol') : badge('bad', 'Javob bermayapti')}</div>
          <p class="muted" style="margin-top:8px">Oxirgi o'qitish: ${cur.created_at ? fmtDT(cur.created_at) : m.model_updated ? fmtDT(m.model_updated) : '—'}</p>
          <p class="muted">Model turi: <b style="color:var(--text)">Tasvirni tasniflash (${esc(m.model === 'OnnxClassifier' ? 'CNN, ONNX' : m.model || '—')})</b>${m.model_size_mb ? ` · ${String(m.model_size_mb).replace('.', ',')} MB` : ''}</p></div>
        ${noField ? `<div class="banner warn" style="flex-direction:column;gap:8px;max-width:300px">${I('alert')}<b>Dala testi mavjud emas</b><p class="small">Model hozircha dala sharoitida to'liq sinovdan o'tmagan. Tasdiqlangan dala rasmlari to'plangach test avtomatik o'tkaziladi.</p><button class="btn pri sm" data-go="ai/dataset">Dataset holati</button></div>` : ''}</div></div>
      <div class="card"><div class="ch"><div class="ttl">${I('db', 'ico l')}<h2>Sinflar soni</h2></div></div><div class="row" style="align-items:baseline"><b style="font-size:44px;line-height:52px">${fmt(m.classes || cur.classes)}</b><span style="font-size:18px">sinf</span></div><p class="muted small">Kasalliklar va sog'lom holatlar</p></div>
      <div class="card"><div class="ch"><div class="ttl">${I('target', 'ico l')}<h2>Model aniqligi</h2></div></div>
        <b style="font-size:44px;line-height:52px">${a.field_accuracy != null ? a.field_accuracy + '%' : '—'}</b><p class="muted small">Agronom tekshiruvi bilan mos (${fmt(a.reviewed)} ta tekshiruv)${a.reviewed < 30 ? ' — namuna kam' : ''}</p>
        <p class="small" style="margin-top:8px">PlantVillage testi: <b>${pct(cur.val_accuracy ?? metrics.val_accuracy_onnx)}</b> <span class="muted">(laboratoriya rasmlari)</span></p></div>
    </div>
    ${models.error ? `<div class="banner warn">${I('alert')}<p>Model versiyalari ro'yxatini olib bo'lmadi: ${esc(models.error)}</p><button class="btn sec sm act" data-act="reload">Qayta urinish</button></div>` : ''}
    <div class="card"><div class="ch"><div><h2>Model versiyalari</h2><div class="sub">Yangi model faqat dala rasmlari testida yomonlashmasa faollashtiriladi; eski versiyaga qaytarish alohida amal.</div></div></div>
    <div class="tw"><table><thead><tr><th>Versiya</th><th>Sana</th><th>O'qitish ma'lumoti</th><th>PlantVillage testi</th><th>Dala rasmlari testi</th><th>Holat</th><th><span class="sr">Amallar</span></th></tr></thead><tbody>
    ${models.models.map(r => {
      const n = +r.tag.replace('model-v', '');
      const st = r.active ? badge('ok', 'Faol', 'check') : n > activeN ? badge('info', 'Nomzod') : badge('', 'Arxiv');
      const btn = r.can_activate ? `<button class="btn ${n > activeN ? 'pri' : 'sec'} sm" data-act="activate" data-v="${esc(r.tag)}" data-rb="${n < activeN ? 1 : ''}">${n > activeN ? 'Faollashtirish' : 'Shu versiyaga qaytarish'}</button>`
        : r.can_force ? `<button class="btn sec sm" data-act="activate" data-v="${esc(r.tag)}" data-force="1" title="${esc(r.reason)}">Dala testisiz faollashtirish</button>`
          : (r.reason && !r.active ? `<span class="muted xs">${esc(r.reason)}</span>` : '');
      return `<tr><td class="mono"><b>${esc(r.tag)}</b></td><td>${r.created_at ? fmtDate(r.created_at) : '—'}</td><td class="small">PlantVillage${r.field_train_images ? ` + ${fmt(r.field_train_images)} dala rasmi` : ''}${r.classes ? ` · ${r.classes} sinf` : ''}</td>
        <td>${r.val_accuracy == null ? '—' : meter(Math.round(r.val_accuracy * 1000) / 10, 90, 70)}</td><td>${r.field_test_accuracy == null ? '<span class="muted xs">test rasmlari yo\'q</span>' : meter(Math.round(r.field_test_accuracy * 1000) / 10)}${r.baseline_field_test_accuracy != null ? `<div class="muted xs">${r.baseline_model ? 'hozirgi' : 'oldingi'}: ${pct(r.baseline_field_test_accuracy)} · ${r.field_test_samples} rasm</div>` : ''}</td>
        <td>${st}</td><td>${btn}</td></tr>`;
    }).join('')}</tbody></table>${models.models.length ? '' : emptyState('Versiyalar topilmadi')}</div></div>`;
  }
  function aiQueue({ queue }) {
    return `<div class="card"><div class="ch"><div class="ttl">${I('clock', 'ico l')}<div><h2>Tekshiruv navbatidagi namunalar (${fmt(queue.queue_total)})</h2><div class="sub">Dehqon agronom tekshiruvini so'ragan tasvirlar. Belgilashni agronomlar ilovada bajaradi.</div></div></div></div>
      ${queue.items.length ? `<div class="qcards">${queue.items.map((x, i) => `<div class="qcard">${x.image_url ? `<img src="${esc(media(x.image_url))}" alt="" loading="lazy">` : `<span class="ph">${I('image')}</span>`}
        <div style="display:grid;gap:6px;align-content:start;min-width:0"><span class="t">${esc(x.disease || 'Aniqlanmadi')}</span>${x.confidence != null ? badge(x.confidence < 50 ? 'warn sm' : 'brand sm', `${String(x.confidence).replace('.', ',')}% ishonch`) : ''}
          <span class="m">${I('agro', 'ico s')}${esc(x.plant || '—')}</span><span class="m">${I('pin', 'ico s')}${esc(x.region || '—')}</span><span class="m">${I('cal', 'ico s')}${fmtDT(x.created_at)}</span>
          <div><button class="btn pri sm" data-act="diag" data-v="${i}">${I('eye', 'ico s')}Ko'rish</button></div></div></div>`).join('')}</div>`
      : emptyState("Navbat bo'sh", "Dehqonlar agronom tekshiruvini so'ramagan.", 'check', 'ok')}</div>`;
  }
  function aiDataset({ a, coverage }) {
    const f = S.dsf; const usable = a.confirmed + a.corrected;
    const plants = [...new Set(coverage.classes.map(c => c.plant).filter(Boolean))].sort();
    const rows = coverage.classes.filter(c => (!f.plant || c.plant === f.plant) && (f.model === 'all' || (f.model === 'known') === c.in_model) && (!f.q || (c.name + ' ' + c.label).toLowerCase().includes(f.q.toLowerCase())));
    const target = coverage.target * coverage.classes.length; const have = coverage.classes.reduce((s, c) => s + Math.min(coverage.target, c.train + c.test), 0);
    const p = target ? Math.round(have / target * 100) : 0; const missing = coverage.classes.filter(c => !c.in_model);
    return `<div class="g g84"><div class="card"><div class="ch"><div class="ttl">${I('db', 'ico l')}<h2>Dataset holati</h2></div><button class="btn sec sm" data-act="export">${I('download', 'ico s')}Dataset eksporti</button></div>
        <div class="row" style="align-items:baseline;gap:8px"><b style="font-size:40px;line-height:48px">${fmt(have)}</b><span style="font-size:20px">/ ${fmt(target)}</span><span class="muted">tasvir (har sinfga ${coverage.target} ta maqsad)</span></div>
        <div class="row" style="flex-wrap:nowrap;gap:14px;margin:14px 0 20px"><div class="meter" style="height:12px"><i style="width:${p}%"></i></div><b class="num">${p}%</b></div>
        <div class="mbox"><div><div class="k">${I('agro', 'ico s')} Sinflar</div><div class="v">${fmt(coverage.classes.length)}</div></div><div><div class="k">${I('doc', 'ico s')} Dala rasmlari</div><div class="v">${fmt(a.total)}</div></div><div><div class="k">${I('image', 'ico s')} Tasdiqlangan</div><div class="v">${fmt(usable)}</div></div><div><div class="k">${I('clock', 'ico s')} Ko'rib chiqilmoqda</div><div class="v">${fmt(a.pending)}</div></div></div></div>
      <div class="card"><div class="ch"><div class="ttl">${I('alert', 'ico l')}<div><h2>AI eng ko'p adashtiradigan juftliklar</h2><div class="sub">Agronom tuzatgan holatlar, oxirgi 90 kun</div></div></div></div>
        ${a.pairs.length ? `<div class="list">${a.pairs.map(pp => `<div class="li"><div class="grow small"><b>${esc(pp.ai_name.split(' (')[0])}</b> deb o'yladi, aslida <b>${esc(pp.name.split(' (')[0])}</b></div><b class="num">${pp.count}</b></div>`).join('')}</div>` : emptyState("Hali agronom tuzatgan tashxis yo'q")}</div></div>
      ${missing.length ? `<div class="banner warn">${I('alert')}<div><b>${missing.length} ta sinfni model hali bilmaydi</b><p>${esc(missing.map(c => c.name).slice(0, 5).join(', '))}${missing.length > 5 ? '…' : ''}. Agronomlar shu ekin rasmlarini to'g'ri sinf bilan tasdiqlasa, keyingi o'qitishda model ularni ham o'rganadi (kamida 30–50 ta rasm).</p></div></div>` : ''}
      <div class="card"><div class="ch"><div><h2>Sinflar bo'yicha dala rasmlari</h2><div class="sub">O'qitish va test to'plami (test rasmlari o'qitishda hech qachon ishlatilmaydi)</div></div></div>
        <div class="filters" style="margin-bottom:16px"><label class="search"><span class="sr">Qidiruv</span>${I('search')}<input id="dq" data-q="dsf" placeholder="Sinf nomi bo'yicha…" value="${esc(f.q)}"></label>
          ${sel('dp', 'Ekin', [['', 'Barcha ekinlar'], ...plants.map(x => [x, x])], f.plant, 'dsf', 'data-k="plant"')}${sel('dm', 'Model', [['all', 'Barchasi'], ['known', 'Model biladi'], ['new', 'Yangi sinf']], f.model, 'dsf', 'data-k="model"')}</div>
        <div class="tw"><table><thead><tr><th>Sinf</th><th>Ekin</th><th>Model</th><th class="n">O'qitish</th><th class="n">Test</th><th>Maqsadga</th></tr></thead><tbody>
        ${rows.map(c => { const n = c.train + c.test, pr = Math.min(100, Math.round(n / coverage.target * 100)); return `<tr><td><div class="who">${thumb(catImg(c.label), c.name)}<div style="min-width:0"><b>${esc(c.name)}</b><div class="muted xs mono">${esc(c.label)}</div></div></div></td><td>${esc(c.plant || '—')}</td>
          <td>${c.in_model ? badge('ok', 'Biladi', 'check') : badge('warn', 'Yangi sinf', 'alert')}</td><td class="n">${c.train}</td><td class="n">${c.test}</td>
          <td><div class="row" style="flex-wrap:nowrap;gap:10px"><div class="meter ${pr < 25 ? 'warn' : ''}" style="max-width:110px"><i style="width:${pr}%"></i></div><span class="num small">${n}/${coverage.target}</span></div></td></tr>`; }).join('')}
        </tbody></table>${rows.length ? '' : emptyState('Mos sinf topilmadi', 'Filtrlarni o\'zgartiring.')}</div></div>`;
  }
  function aiTraining({ training, a, models }) {
    const runs = training.runs || [], last = runs[0], running = isRunning(training); const usable = a.confirmed + a.corrected;
    const rs = r => r.status !== 'completed' ? (r.status === 'queued' ? badge('info', 'Navbatda', 'clock') : badge('warn', 'Ishlamoqda', 'refresh')) : r.conclusion === 'success' ? badge('ok', 'Muvaffaqiyatli', 'check') : badge('bad', 'Xato', 'xc');
    return `<div class="g g84"><div class="card"><div class="ch"><div class="ttl">${I('chart', 'ico l')}<div><h2>So'nggi o'qitish natijalari</h2><div class="sub">GitHub Actions'da, ~1 soat · natija — yangi nomzod versiya</div></div></div>${last ? `<a class="btn ghost sm" href="${esc(last.url)}" target="_blank" rel="noopener">Log${I('ext', 'ico s')}</a>` : ''}</div>
        ${!training.configured ? `<div class="banner warn">${I('alert')}<p>Qayta o'qitish sozlanmagan. Serverda bir marta: <span class="mono">sudo bash deploy/enable-training.sh</span> (docs/DATASET.md).</p></div>` : ''}
        ${training.error ? `<div class="banner warn">${I('alert')}<p>${esc(training.error)}</p></div>` : ''}
        ${last ? `<ul class="timeline" style="margin-top:8px">${last.steps.map(st => `<li class="${st.status === 'completed' && st.conclusion !== 'failure' ? 'done' : ''}"><div><b class="small">${esc(st.title)}</b></div><span class="xs muted">${st.conclusion === 'failure' ? 'xato' : st.conclusion === 'skipped' ? "o'tkazildi" : st.status === 'in_progress' ? 'ishlamoqda…' : st.status === 'completed' ? 'tayyor' : 'kutilmoqda'}</span></li>`).join('')}</ul>
          <div class="row sp"><span class="muted small">Oxirgi: ${fmtDT(last.created_at)}</span>${rs(last)}</div>` : emptyState("Hali o'qitish o'tkazilmagan")}</div>
      <div class="card"><h2>Yangi o'qitish</h2><p class="muted" style="margin:8px 0 16px">${fmt(usable)} ta tasdiqlangan dala rasmi bilan yangi versiya o'qitiladi va «Dala rasmlari testi»da hozirgi model (${esc(models.active_tag || '—')}) bilan solishtiriladi. Faollashtirish alohida tasdiq bilan.</p>
        ${running ? `<div class="banner info">${I('refresh')}<p>O'qitish ketyapti — holati shu sahifada 20 soniyada yangilanadi. Sahifani yopsangiz ham davom etadi.</p></div>` : `<button class="btn pri" data-act="train" ${training.configured ? '' : 'disabled'} style="width:100%">${I('play', 'ico s')}Yangi o'qitishni boshlash</button>`}</div></div>
      <div class="card"><div class="ch"><h2>O'qitish tarixi</h2></div>${runs.length ? `<div class="tw"><table><thead><tr><th>Boshlangan</th><th>Yangilangan</th><th>Holat</th><th><span class="sr">Log</span></th></tr></thead><tbody>
        ${runs.map(r => `<tr><td>${fmtDT(r.created_at)}</td><td>${fmtDT(r.updated_at)}</td><td>${rs(r)}</td><td><a class="link" href="${esc(r.url)}" target="_blank" rel="noopener">Log va natija ${I('ext', 'ico s')}</a></td></tr>`).join('')}</tbody></table></div>` : emptyState("Tarix bo'sh")}</div>`;
  }

  // ================= 05. Bilimlar bazasi =================
  const KBT = { diseases: ['Kasalliklar', 'agro', 'Kasallik'], plants: ["O'simliklar", 'leafs', "O'simlik"], medicines: ['Dorilar', 'flag', 'Dori'] };
  const KBSTATE = { complete: ['ok', "To'liq", 'checkc'], incomplete: ['warn', "To'liq emas", 'clock'], no_image: ['bad', "Rasm yo'q", 'image'] };
  SEC.kb = {
    label: 'Bilimlar bazasi', ic: 'book',
    tabs: () => [['diseases', 'Kasalliklar', 'agro'], ['plants', "O'simliklar", 'leafs'], ['medicines', 'Dorilar', 'flag'], ['changes', "O'zgarishlar", 'clock']], def: 'diseases',
    async load(tab) {
      if (tab === 'changes') return { changes: await api('/admin/catalog-changes?limit=100') };
      const [list, changes] = await Promise.all([api('/admin/kb/list/' + tab), api('/admin/catalog-changes?limit=5')]); return { list, changes };
    },
    render(d, tab) {
      const title = head('Bilimlar bazasi', "O'simlik kasalliklari, zararkunandalar, dorilar va boshqa agronomik ma'lumotlarni boshqaring.");
      if (tab === 'changes') return `${title}${tabsBar('kb', SEC.kb.tabs(), tab)}<div class="card"><div class="ch"><div><h2>O'zgarishlar tarixi</h2><div class="sub">Agronomlar ilovada tahrirlaydi; admin kerak bo'lsa qaytaradi (oldingi matn tiklanadi).</div></div></div>${changesList(d.changes, true)}</div>`;
      const { list, changes } = d; const f = S.kbf; const img = r => catImg(r.ai_label) || media(r.image_url);
      const plants = [...new Set(list.items.map(r => r.plant).filter(Boolean))].sort();
      const rows = list.items.filter(r => (f.state === 'all' || r.state === f.state) && (!f.plant || r.plant === f.plant) && (!f.q || r.name.toLowerCase().includes(f.q.toLowerCase())));
      const s = list.summary; const pc = list.total ? Math.round(s.complete / list.total * 100) : 0; const noImg = list.items.filter(r => r.state === 'no_image');
      const sub = r => tab === 'diseases' ? (r.risk_level ? esc((RISK[r.risk_level] || [])[1] || '') : '') : tab === 'plants' ? esc(r.scientific_name || '') : esc(r.active_ingredient || '');
      return `${title}${tabsBar('kb', SEC.kb.tabs(), tab)}
      <div class="g g93"><div class="col" style="gap:20px">
        ${noImg.length ? `<div class="banner warn">${I('alert')}<p><b style="display:inline;font-size:16px">${noImg.length} ta yozuvda rasm yetishmaydi.</b> To'liq ma'lumot uchun rasmlar qo'shishni unutmang.</p><button class="btn out sm act" data-act="kbf" data-k="state" data-v="no_image">Ko'rish ${I('arrow', 'ico s')}</button></div>` : ''}
        <div class="filters"><label class="search"><span class="sr">Qidiruv</span>${I('search')}<input id="kq" data-q="kbf" placeholder="${KBT[tab][2]} nomi bo'yicha qidirish…" value="${esc(f.q)}"></label>
          ${tab === 'diseases' ? sel('kp', "O'simlik", [['', "Barcha o'simliklar"], ...plants.map(x => [x, x])], f.plant, 'kbf', 'data-k="plant"') : ''}
          ${sel('ks', 'Holat', [['all', 'Barcha holatlar'], ['complete', "To'liq"], ['incomplete', "To'liq emas"], ['no_image', "Rasm yo'q"]], f.state, 'kbf', 'data-k="state"')}
          ${f.q || f.plant || f.state !== 'all' ? `<button class="btn ghost" data-act="kbclear">${I('x', 'ico s')}Tozalash</button>` : ''}</div>
        <div class="tw"><table><thead><tr><th>#</th><th>Rasm</th><th>${KBT[tab][2]} nomi</th>${tab === 'diseases' ? "<th>O'simlik</th><th class=\"n\">Dorilar</th>" : tab === 'medicines' ? '<th>Yorliq</th><th class="n">Kasalliklarda</th>' : '<th>Turkum</th>'}<th>Holat</th><th>Oxirgi yangilanish</th><th><span class="sr">Amallar</span></th></tr></thead><tbody>
          ${rows.map((r, i) => `<tr><td class="num muted">${i + 1}</td><td>${thumb(img(r), r.name)}</td><td class="wrap"><b>${esc(r.name)}</b>${sub(r) ? `<div class="muted xs">${sub(r)}</div>` : ''}</td>
            ${tab === 'diseases' ? `<td>${esc(r.plant || '—')}</td><td class="n">${r.medicines}</td>` : tab === 'medicines' ? `<td>${r.label_verified ? badge('ok sm', 'Tasdiqlangan') : badge('sm', 'Tekshirilmagan')}</td><td class="n">${r.used_in}</td>` : `<td>${esc(r.category || '—')}</td>`}
            <td>${badge(...KBSTATE[r.state])}</td><td>${fmtDate(r.updated_at)}<div class="muted xs">${esc(r.updated_by || 'Dastlabki katalog')}</div></td><td><button class="btn sec sm" data-act="kbitem" data-v="${r.id}">${I('eye', 'ico s')}Ko'rish</button></td></tr>`).join('')}
        </tbody></table>${rows.length ? '' : emptyState('Hech narsa topilmadi', 'Qidiruv yoki filtrlarni o\'zgartiring.', 'search')}</div>
        <p class="muted small">${rows.length} / ${list.total} ta ko'rsatildi</p></div>
      <div class="col" style="gap:20px">
        <div class="card"><div class="ch"><div class="ttl">${I('leafs', 'ico l')}<h2>Kontent sifati</h2></div></div>
          <div class="row" style="gap:18px;flex-wrap:nowrap"><div style="position:relative">${donut([[s.complete, 'var(--success)'], [s.incomplete, '#D9912B'], [s.no_image, 'var(--danger)']])}<b style="position:absolute;inset:0;display:grid;place-items:center;font-size:22px">${pc}%</b></div>
          <div><b>To'liq ma'lumotli yozuvlar</b><div class="muted small">Jami ${list.total} ta yozuvdan ${s.complete} tasi to'liq</div></div></div>
          <div class="legend" style="margin-top:18px"><div><i style="background:var(--success)"></i>To'liq<b>${s.complete}</b></div><div><i style="background:#D9912B"></i>Maydon yetishmaydi<b>${s.incomplete}</b></div><div><i style="background:var(--danger)"></i>Rasm yetishmaydi<b>${s.no_image}</b></div></div></div>
        ${noImg.length ? `<div class="card" style="background:var(--danger-bg);border-color:color-mix(in srgb,var(--danger) 25%,transparent)"><div class="ch"><div class="ttl" style="color:var(--danger)">${I('image', 'ico l')}<h2>Rasm yetishmaydigan yozuvlar (${noImg.length})</h2></div></div>
          <div class="list">${noImg.slice(0, 5).map((r, i) => `<div class="li" style="border-color:color-mix(in srgb,var(--danger) 15%,transparent)"><span class="thumb">${I('image')}</span><div class="grow"><div class="t">${i + 1}. ${esc(r.name)}</div><div class="m">${esc(r.plant || r.category || '')}</div></div></div>`).join('')}</div></div>` : ''}
        <div class="card"><div class="ch"><div class="ttl">${I('clock', 'ico l')}<h2>So'nggi o'zgarishlar</h2></div><button class="link" data-go="kb/changes">Barchasi ${I('arrow', 'ico s')}</button></div>${changesList(changes, false)}</div>
      </div></div>`;
    },
  };
  const changesList = (changes, full) => (changes.length ? `<div class="list">${changes.map(c => `<div class="li"><span class="b ${c.reverted ? '' : c.action === 'revert' ? 'info' : 'ok'} sm" style="width:10px;height:10px;padding:0"></span><div class="grow"><div class="t small">${esc(c.summary)}</div><div class="m">${esc(c.user_name || '—')} · ${fmtDT(c.created_at)}</div></div>
    ${full ? (c.revertible ? `<button class="btn sec sm" data-act="revert" data-v="${c.id}">${I('refresh', 'ico s')}Qaytarish</button>` : c.reverted ? badge('sm', 'Qaytarilgan') : '') : ''}</div>`).join('')}</div>` : emptyState("Hali o'zgarish yo'q"));
  function kbDrawer(r, kind) {
    const img = catImg(r.ai_label) || media(r.image_url);
    const F = kind === 'diseases' ? [['Tavsif', r.description], ['Belgilar', r.symptoms], ['Davolash', r.treatment], ['Oldini olish', r.prevention]]
      : kind === 'plants' ? [['Tavsif', r.description], ['Parvarish', r.care_info]] : [['Faol modda', r.active_ingredient], ['Qo\'llash', r.usage], ['Ehtiyot choralari', r.precautions], ['Ishlab chiqaruvchi', r.manufacturer]];
    drawer(`<div class="dh"><div class="row sp"><h3 id="dr-t">${esc(r.name)}</h3><button class="btn ghost icon" data-act="close" aria-label="Yopish">${I('x')}</button></div><div class="row">${badge(...KBSTATE[r.state])}${r.risk_level ? badge(...(RISK[r.risk_level] || ['', r.risk_level])) : ''}${kind === 'medicines' ? (r.label_verified ? badge('ok', 'Yorliq tasdiqlangan') : badge('', 'Yorliq tekshirilmagan')) : ''}</div></div>
      <div class="db">${img ? `<img class="zoom" src="${esc(img)}" alt="${esc(r.name)}" style="max-height:240px">` : `<div class="banner bad">${I('image')}<p>Rasm yo'q — ilovada umumiy belgi ko'rsatiladi.</p></div>`}
      ${r.missing.length ? `<div class="banner warn">${I('alert')}<div><b>Yetishmaydigan maydonlar</b><p>${esc(r.missing.join(', '))}</p></div></div>` : ''}
      <dl class="kv">${r.plant ? `<dt>O'simlik</dt><dd>${esc(r.plant)}</dd>` : ''}${r.ai_label ? `<dt>AI sinfi</dt><dd class="mono small">${esc(r.ai_label)}</dd>` : ''}${kind === 'diseases' ? `<dt>Bog'langan dorilar</dt><dd>${r.medicines}</dd>` : ''}
      <dt>Manba</dt><dd>${esc(r.source || "Ko'rsatilmagan")}</dd><dt>Oxirgi yangilanish</dt><dd>${fmtDT(r.updated_at)} · ${esc(r.updated_by || 'Dastlabki katalog')}</dd></dl>
      ${F.map(([k, v]) => `<div><div class="lbl" style="margin-bottom:6px">${k}</div>${v ? `<div class="fact" style="white-space:pre-line">${esc(v)}</div>` : '<span class="muted small">— kiritilmagan</span>'}</div>`).join('')}
      <div class="banner info">${I('info')}<p>Yozuvlarni agronomlar ilovadagi «Bilimlar bazasi» muharririda tahrirlaydi. Har o'zgarish «O'zgarishlar» tabida ko'rinadi va qaytarilishi mumkin.</p></div></div>`, 'kb');
  }

  // ================= 06. Jamoat moderatsiyasi =================
  const KIND = { post: ['Post', 'ok'], comment: ['Izoh', 'info'], message: ['Chat xabari', 'pur'] };
  SEC.mod = {
    label: 'Jamoat', ic: 'chat', badge: () => S.badges.mod,
    tabs: () => [['open', 'Ochiq'], ['review', "Ko'rib chiqilmoqda"], ['closed', 'Yopilgan']], def: 'open',
    async load(tab) { const r = await api('/admin/moderation?tab=' + tab); S.badges.mod = r.counts.open + r.counts.review; return r; },
    render(d, tab) {
      const T = SEC.mod.tabs().map(([k, t]) => [k, t, null, d.counts[k]]);
      const top = `${head('Jamoat moderatsiyasi', "Foydalanuvchilar tomonidan yuborilgan shikoyatlar asosida postlar, izohlar va xabarlarni ko'rib chiqing.")}${tabsBar('mod', T, tab)}`;
      if (tab === 'closed') return `${top}<div class="card">${d.items.length ? `<div class="tw"><table><thead><tr><th>Sana</th><th>Moderator</th><th>Qaror</th><th>Tafsilot</th></tr></thead><tbody>${d.items.map(x => `<tr><td>${fmtDT(x.created_at)}</td><td>${esc(x.moderator)}</td><td>${x.decision === 'hidden' ? badge('bad', 'Kontent yashirildi') : badge('info', 'Shikoyat rad etildi')}</td><td class="wrap small">${esc(x.summary)}</td></tr>`).join('')}</tbody></table></div>` : emptyState("Hali yopilgan shikoyat yo'q")}</div>`;
      const f = S.modf; const reasons = [...new Set(d.items.flatMap(x => x.reasons.map(r => r.reason)))].sort();
      let rows = d.items.filter(x => (f.kind === 'all' || x.kind === f.kind) && (f.reason === 'all' || x.reasons.some(r => r.reason === f.reason)) && (!f.q || [x.title, x.text, x.author].join(' ').toLowerCase().includes(f.q.toLowerCase())));
      if (f.sort === 'count') rows = [...rows].sort((a, b) => b.count - a.count); else if (f.sort === 'old') rows = [...rows].sort((a, b) => parseTs(a.first_at) - parseTs(b.first_at));
      if (!d.items.length) return `${top}<div class="card">${emptyState(tab === 'open' ? "Ochiq shikoyat yo'q" : "Ko'rib chiqilayotgan shikoyat yo'q", 'Yangi shikoyat kelsa, shu yerda ko\'rinadi.', 'check', 'ok', '<button class="btn sec sm" data-go="mod/closed">Yopilganlar tarixi</button>')}</div>`;
      const cur = rows.find(x => x.target_id === S.modSel) || rows[0]; S.modSel = cur ? cur.target_id : null;
      return `${top}
      <div class="filters"><label class="search"><span class="sr">Qidiruv</span>${I('search')}<input id="mq" data-q="modf" placeholder="Post, muallif yoki mavzu bo'yicha qidirish…" value="${esc(f.q)}"></label>
        ${sel('mk', 'Kontent turi', [['all', 'Barchasi'], ['post', 'Post'], ['comment', 'Izoh'], ['message', 'Chat xabari']], f.kind, 'modf', 'data-k="kind"')}
        ${sel('mr', 'Shikoyat sababi', [['all', 'Barchasi'], ...reasons.map(r => [r, r])], f.reason, 'modf', 'data-k="reason"')}
        ${sel('ms', 'Saralash', [['new', 'Eng yangi'], ['old', 'Eng eski'], ['count', "Shikoyati ko'p"]], f.sort, 'modf', 'data-k="sort"')}</div>
      <div class="g g75" style="align-items:start">
        <div class="card" style="padding:12px"><div class="tw" style="border:0"><table style="min-width:600px"><thead><tr><th>Kontent</th><th>Turi</th><th>Shikoyat sababi</th><th class="n">Shikoyatlar</th><th><span class="sr">Amallar</span></th></tr></thead><tbody>
          ${rows.map(x => `<tr class="click ${cur && x.target_id === cur.target_id ? 'sel' : ''}" data-act="modsel" data-v="${x.target_id}" tabindex="0"><td><div class="who">${x.image_url ? thumb(media(x.image_url), x.title || '') : `<span class="thumb">${I(x.kind === 'post' ? 'chat' : 'msg')}</span>`}<div style="min-width:0;max-width:300px"><b style="white-space:normal">${esc((x.title || x.text || '—').slice(0, 80))}</b><div class="muted xs">${esc(x.author || '—')} · ${ago(x.last_at)}</div></div></div></td>
            <td>${badge(KIND[x.kind][1], KIND[x.kind][0])}</td><td><div class="row" style="flex-wrap:wrap;max-width:180px">${x.reasons.slice(0, 2).map(r => badge('', r.reason)).join('')}</div></td><td class="n">${x.count}</td>
            <td><button class="btn out sm" data-act="modsel" data-v="${x.target_id}">Ko'rish</button></td></tr>`).join('')}
        </tbody></table>${rows.length ? '' : emptyState('Mos shikoyat topilmadi', 'Filtrlarni o\'zgartiring.', 'search')}</div><p class="muted small" style="padding:12px 8px 4px">${d.items.length} tadan ${rows.length} tasi ko'rsatilmoqda</p></div>
        ${cur ? modDetail(cur, tab) : '<div></div>'}
      </div>`;
    },
  };
  function modDetail(x, tab) {
    const noun = { post: 'Postni', comment: 'Izohni', message: 'Xabarni' }[x.kind];
    return `<div class="card" style="position:sticky;top:96px;display:grid;gap:18px"><div class="row sp"><h2>Shikoyat tafsilotlari</h2><span class="b sm mono">#${esc(String(x.target_id).slice(0, 8).toUpperCase())}</span></div>
      <div class="row" style="flex-wrap:nowrap;align-items:flex-start;gap:14px">${x.image_url ? thumb(media(x.image_url), x.title || '', true) : ''}<div style="min-width:0"><b style="font-size:17px">${esc(x.title || KIND[x.kind][0])}</b><p class="small" style="margin-top:4px;white-space:pre-line">${esc(x.text || '—')}</p>
        <div class="m muted xs row" style="margin-top:8px">${I('user', 'ico s')}${esc(x.author || '—')} · ${ago(x.created_at)}</div></div></div>
      <div class="row sp" style="align-items:flex-start"><div><div class="lbl">Shikoyat sababi</div><div class="row" style="margin-top:6px">${x.reasons.map(r => badge('warn', `${r.reason} · ${r.count}`)).join('')}</div></div><div style="text-align:right"><div class="lbl">Jami shikoyatlar</div><b style="font-size:20px">${x.count} ta</b></div></div>
      ${x.claims.length ? `<div class="col" style="gap:8px">${x.claims.map(c => `<div class="quote"><span class="lbl">Shikoyatchi aytgan (tasdiqlanmagan)</span>“${esc(c)}”</div>`).join('')}</div>` : '<p class="muted small">Shikoyatchilar izoh yozmagan.</p>'}
      <p class="muted xs">Shikoyatlar soni o'z-o'zidan qoidabuzarlikni bildirmaydi — kontentni o'qib qaror qiling.</p>
      <div class="fld"><label for="mod-note">Moderator qarori sababi</label><textarea id="mod-note" maxlength="500" rows="3" placeholder="Qaror sababini kiriting…"></textarea><span class="count" id="mod-cnt">0/500</span></div>
      <div class="row" style="gap:10px">${tab === 'open' ? `<button class="btn sec" data-act="modstart" style="flex:1">${I('clock', 'ico s')}Ko'rib chiqishni boshlash</button>` : ''}
        <button class="btn out" data-act="moddismiss" style="flex:1">Shikoyatni rad etish</button><button class="btn dan" data-act="modhide" style="flex:1">${noun} yashirish</button></div>
      <div><h3 class="h2" style="margin-bottom:12px">Ko'rib chiqish tarixi</h3><ul class="timeline"><li class="done"><div><b class="small">Shikoyat yaratildi</b><div class="muted xs">${x.count} ta shikoyat · birinchisi ${fmtDT(x.first_at)}</div></div><span class="xs muted">${ago(x.first_at)}</span></li>
        <li class="${x.status === 'reviewing' ? 'done' : ''}"><div><b class="small">Ko'rib chiqilmoqda</b><div class="muted xs">${x.status === 'reviewing' ? 'Moderator ko\'rib chiqmoqda' : 'Hali boshlanmagan'}</div></div><span class="xs muted">${x.reviewed_at ? ago(x.reviewed_at) : '—'}</span></li>
        <li><div><b class="small">Qaror</b><div class="muted xs">Yashirilsa, muallifga sabab bilan bildirishnoma boradi</div></div><span class="xs muted">—</span></li></ul></div></div>`;
  }

  // ================= 07. Obunalar va to'lovlar =================
  const TXS = { active: ['ok', 'Muvaffaqiyatli', 'checkc'], expired: ['', 'Muddati tugagan', 'clock'], cancelled: ['bad', 'Bekor qilingan', 'xc'], pending: ['', 'Kutilmoqda', 'clock'], trial: ['info', 'Sinov', 'info'] };
  const txStatus = t => (t.status === 'active' && !t.paid ? TXS.pending : TXS[t.status] || TXS.pending);
  SEC.pay = {
    label: "To'lovlar", ic: 'card', tabs: () => [['tx', 'Tranzaksiyalar'], ['subs', 'Obunalar'], ['plans', 'Tariflar']], def: 'tx',
    async load() { const [list, p] = await Promise.all([api('/admin/payments/list'), api('/admin/payments')]); S.mode = list.mode; return { list, p }; },
    render({ list, p }, tab) {
      const k = list.kpi; const sandbox = list.mode === 'sandbox';
      let body = '';
      if (tab === 'tx') {
        const f = S.payf; const rows = filterTx(list.items);
        body = `<div class="card" style="padding:20px"><div class="filters">
          <div class="fld" style="flex:0 1 auto"><span class="lbl">Sana oralig'i</span><div class="row dates" style="flex-wrap:nowrap"><label class="sr" for="pf-from">Boshlanish</label><input id="pf-from" type="date" data-act="payf" data-k="from" value="${esc(f.from)}" class="date"><span class="muted">—</span><label class="sr" for="pf-to">Tugash</label><input id="pf-to" type="date" data-act="payf" data-k="to" value="${esc(f.to)}" class="date"></div></div>
          ${sel('pf-p', "To'lov provayderi", [['all', 'Barchasi'], ['payme', 'Payme'], ['click', 'Click'], ['uzum', 'Uzum']], f.provider, 'payf', 'data-k="provider"')}
          ${sel('pf-s', 'Holat', [['all', 'Barchasi'], ['active', 'Muvaffaqiyatli'], ['pending', 'Kutilmoqda'], ['cancelled', 'Bekor qilingan'], ['expired', 'Muddati tugagan']], f.status, 'payf', 'data-k="status"')}
          ${sel('pf-e', 'Muhit', [['all', 'Barchasi'], ['sandbox', 'Sinov'], ['live', 'Haqiqiy']], f.env, 'payf', 'data-k="env"')}
          <button class="btn ghost" data-act="payclear">${I('refresh', 'ico s')}Tozalash</button></div></div>
        <div class="card"><div class="ch"><div class="ttl">${I('card', 'ico l')}<h2>Tranzaksiyalar (${rows.length} ta)</h2></div><button class="btn sec sm" data-act="csv" ${rows.length ? '' : 'disabled'}>${I('download', 'ico s')}CSV yuklab olish</button></div>
          <div class="tw"><table><thead><tr><th>#</th><th>Sana</th><th>Foydalanuvchi</th><th>Buyurtma</th><th>Provayder</th><th class="n">Summa</th><th>Turi</th><th>Holat</th><th>Muhit</th><th><span class="sr">Amallar</span></th></tr></thead><tbody>
          ${rows.map((t, i) => `<tr><td class="num muted">${i + 1}</td><td class="num">${fmtDT(t.created_at)}</td><td>${esc(t.user)}</td><td class="mono small">${esc(t.order)}</td><td>${prov(t.provider)}</td><td class="n">${sum(t.amount)}</td><td class="small">${esc(PLAN[t.plan] || t.plan)}</td>
            <td>${badge(...txStatus(t))}</td><td>${t.sandbox ? badge('warn sm', 'Sinov') : t.paid ? badge('ok sm', 'Haqiqiy') : badge('sm', '—')}</td><td><button class="btn sec sm" data-act="tx" data-v="${t.id}">${I('eye', 'ico s')}Ko'rish</button></td></tr>`).join('')}
          </tbody></table>${rows.length ? '' : emptyState(list.items.length ? "Filtrga mos to'lov yo'q" : "Hali to'lov yo'q", list.items.length ? 'Filtrlarni o\'zgartiring.' : '')}</div></div>
          <div class="g g2" style="align-items:start"><div class="card"><div class="ch"><div class="ttl">${I('crown', 'ico l')}<h2>Obuna haqida</h2></div></div>
            <div class="banner ${sandbox ? 'warn' : 'ok'}" style="flex-direction:column;gap:8px"><b>Premium huquqi manbasi: ${sandbox ? 'Sinov' : "Haqiqiy to'lov"}</b><p class="small">${sandbox ? "Ushbu muhitda barcha premium obunalar sinov maqsadida beriladi. Foydalanuvchilardan haqiqiy to'lov undirilmaydi. «Sinov» belgisi bilan ko'rsatilgan obunalar test obunalar hisoblanadi." : "Payme va Click orqali haqiqiy to'lovlar qabul qilinmoqda."}</p></div>
            <div class="banner info" style="margin-top:12px">${I('info')}<p class="small">Obuna muddati tugagach, u avtomatik ravishda faol emas holatga o'tadi.</p></div></div>
            <div class="card"><div class="ch"><div><h2>Haqiqiy daromad (oylar)</h2><div class="sub">Bekor qilingan va qaytarilgan to'lovlar qo'shilmaydi</div></div></div><div class="chart" id="c-rev" style="min-height:0"></div></div></div>`;
      } else if (tab === 'subs') {
        const st = S.subf; const rows = list.items.filter(t => t.paid && (st === 'all' || t.status === st));
        body = `<div class="card"><div class="ch"><div><h2>Obunalar</h2><div class="sub">To'langan (sinov yoki haqiqiy) obunalar va ularning muddati</div></div>${sel('sf', 'Holat', [['active', 'Faol'], ['expired', 'Muddati tugagan'], ['cancelled', 'Bekor qilingan'], ['all', 'Barchasi']], st, 'subf')}</div>
          <div class="tw"><table><thead><tr><th>Foydalanuvchi</th><th>Tarif</th><th>Boshlangan</th><th>Tugaydi</th><th>Avto-yangilanish</th><th>Holat</th><th>Muhit</th></tr></thead><tbody>
          ${rows.map(t => `<tr><td><div class="who">${avatar(t.user)}<div><b>${esc(t.user)}</b><div class="muted xs">@${esc(t.username)}</div></div></div></td><td>${esc(PLAN[t.plan] || t.plan)}</td><td>${fmtDate(t.paid_at || t.created_at)}</td><td>${t.plan === 'lifetime' ? 'Umrbod' : fmtDate(t.expires_at)}</td><td>${t.auto_renew ? 'Yoqilgan' : "O'chirilgan"}</td><td>${badge(...txStatus(t))}</td><td>${t.sandbox ? badge('warn sm', 'Sinov') : badge('ok sm', 'Haqiqiy')}</td></tr>`).join('')}
          </tbody></table>${rows.length ? '' : emptyState("Bu holatda obuna yo'q")}</div></div>`;
      } else {
        body = `<form class="card" data-form="settings" style="display:grid;gap:18px"><div><h2>Tariflar va bepul limitlar</h2><p class="muted small" style="margin-top:4px">Yangi qiymat keyingi to'lovlardan amal qiladi. Saqlashdan oldin oldingi va yangi qiymat solishtiriladi.</p></div>
          <div class="g g2" style="gap:16px">${p.settings.map(s => `<div class="fld"><label for="st-${s.key}">${esc(s.title)} <span class="req" aria-hidden="true">*</span></label><input id="st-${s.key}" name="${s.key}" type="number" inputmode="numeric" min="${s.min}" max="${s.max}" value="${s.value}" data-old="${s.value}" required><span class="help">Hozir: <b>${fmt(s.value)}</b> · ruxsat: ${fmt(s.min)}–${fmt(s.max)}</span></div>`).join('')}</div>
          <div class="row"><button class="btn pri" type="submit">Saqlash</button><span class="muted small">Merchant kalitlari faqat server sozlamalarida saqlanadi va bu yerda ko'rsatilmaydi.</span></div></form>`;
      }
      return `${head("Obunalar va to'lovlar", `Obunalar, to'lovlar va tariflarni boshqarish.${sandbox ? " Barcha ma'lumotlar sinov muhitida ko'rsatilmoqda." : ''}`)}
      ${sandbox ? `<div class="banner bad">${I('alert', 'ico l')}<div><b>Sinov rejimi — haqiqiy pul olinmaydi</b><p>Bu sinov muhiti. Barcha to'lovlar va obunalar faqat test maqsadida. Haqiqiy pul mablag'i hisoblanmaydi va undirilmaydi.</p></div></div>` : ''}
      ${tabsBar('pay', SEC.pay.tabs(), tab, 'seg')}
      <div class="g g4">
        ${kpi('coins', 'Haqiqiy daromad', sum(k.live_revenue_month), sandbox ? "<span>Sinov muhitida haqiqiy to'lovlar olinmaydi</span>" : '<span>shu oy</span>')}
        ${kpi('crown', 'Sinov Premium', fmt(k.sandbox_active), "<span>sinov orqali berilgan faol obunalar</span>", 'c-warn')}
        ${kpi('users', 'Faol pullik obunalar', fmt(k.live_active), k.live_active ? '<span>haqiqiy to\'lov bilan</span>' : "<span>hozircha faol pullik obuna yo'q</span>")}
        ${kpi('xc', 'Bekor qilingan obunalar', fmt(k.cancelled_30d), "<span>so'nggi 30 kunda</span>", 'c-bad')}
      </div>
      ${body}`;
    },
    after({ list }, tab) {
      if (tab !== 'tx') return;
      const el = document.getElementById('c-rev'); if (!el) return;
      const MONTHS = ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyun', 'Iyul', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek'];
      const now = new Date(); const months = [];
      for (let i = 5; i >= 0; i--) { const d = new Date(now.getFullYear(), now.getMonth() - i, 1); months.push([d.getFullYear() * 12 + d.getMonth(), MONTHS[d.getMonth()]]); }
      const live = list.items.filter(t => t.paid && !t.sandbox && ['active', 'expired'].includes(t.status) && !t.refunded_at);
      const data = months.map(([key, lb]) => [lb, live.filter(t => { const d = parseTs(t.created_at); return d.getFullYear() * 12 + d.getMonth() === key; }).reduce((s, t) => s + t.amount, 0) / 1000]);
      if (!data.some(d => d[1] > 0)) { el.innerHTML = emptyState("Haqiqiy to'lov hali yo'q", list.mode === 'sandbox' ? "Sinov rejimida daromad hisoblanmaydi." : ''); return; }
      columns(el, data, "ming so'm", v => fmt(Math.round(v)) + " ming so'm");
    },
  };
  function filterTx(items) {
    const f = S.payf; const from = f.from ? new Date(f.from + 'T00:00:00') : null, to = f.to ? new Date(f.to + 'T23:59:59') : null;
    return items.filter(t => { const d = parseTs(t.created_at); const st = t.status === 'active' && !t.paid ? 'pending' : t.status;
      return (!from || d >= from) && (!to || d <= to) && (f.provider === 'all' || t.provider === f.provider) && (f.status === 'all' || st === f.status) && (f.env === 'all' || (f.env === 'sandbox') === t.sandbox); });
  }
  function txDrawer(t) {
    const src = t.sandbox ? "Sinov to'lovi (haqiqiy pul olinmagan)" : t.paid ? "Haqiqiy to'lov" : "To'lanmagan — Premium berilmagan";
    drawer(`<div class="dh"><div class="row sp"><h3 id="dr-t">Tranzaksiya #${esc(t.order)}</h3><button class="btn ghost icon" data-act="close" aria-label="Yopish">${I('x')}</button></div><div class="row">${badge(...txStatus(t))}${t.sandbox ? badge('warn', 'Sinov') : ''}</div></div>
      <div class="db"><dl class="kv"><dt>Foydalanuvchi</dt><dd>${esc(t.user)} <span class="muted">@${esc(t.username)}</span></dd><dt>Tarif</dt><dd>${esc(PLAN[t.plan] || t.plan)}</dd><dt>Summa</dt><dd><b>${sum(t.amount)}</b> ${esc(t.currency)}</dd><dt>Provayder</dt><dd>${prov(t.provider)}</dd><dt>Buyurtma ID</dt><dd class="mono small">${esc(t.id)}</dd></dl>
      <div><div class="lbl" style="margin-bottom:10px">To'lov tarixi</div><ul class="timeline"><li class="done"><div><b class="small">Buyurtma yaratildi</b></div><span class="xs muted">${fmtDT(t.created_at)}</span></li>
        <li class="${t.paid_at ? 'done' : ''}"><div><b class="small">To'lov tasdiqlandi</b></div><span class="xs muted">${t.paid_at ? fmtDT(t.paid_at) : '—'}</span></li>
        ${t.refunded_at ? `<li class="done"><div><b class="small">To'lov qaytarildi</b></div><span class="xs muted">${fmtDT(t.refunded_at)}</span></li>` : ''}
        <li class="${t.status === 'expired' || t.status === 'cancelled' ? 'done' : ''}"><div><b class="small">${t.status === 'cancelled' ? 'Bekor qilindi' : 'Muddat tugashi'}</b></div><span class="xs muted">${t.plan === 'lifetime' ? 'Umrbod' : fmtDT(t.expires_at)}</span></li></ul></div>
      <div class="fact"><span class="lbl muted xs">Premium huquqi manbasi</span><b>${src}</b></div>
      <button class="link" data-act="user" data-v="${t.user_id}">Foydalanuvchi profilini ochish ${I('arrow', 'ico s')}</button></div>`, 'tx');
  }

  // ================= 08. Tizim =================
  SEC.sys = {
    label: 'Tizim', ic: 'gear',
    tabs: () => [['monitor', 'Monitoring', 'pulse'], ['backups', 'Zaxiralar', 'db'], ['broadcast', 'Xabarlar', 'bell'], ['audit', 'Jurnal', 'doc']], def: 'monitor',
    async load(tab) {
      if (tab === 'monitor') { const [m, s] = await Promise.all([api('/admin/system/monitor'), api('/admin/system')]); return { m, s }; }
      if (tab === 'backups') { const [s, audit] = await Promise.all([api('/admin/system'), api('/admin/audit/page?limit=5')]); return { s, audit }; }
      if (tab === 'broadcast') return { aud: await api('/admin/broadcast/audiences'), log: await api('/admin/audit/page?action=broadcast&limit=10') };
      const f = S.audf; return { audit: await api('/admin/audit/page?' + q({ q: f.q, action: f.action, limit: f.limit, offset: f.offset })) };
    },
    render(d, tab) {
      let body = '';
      if (tab === 'monitor') body = sysMonitor(d); else if (tab === 'backups') body = sysBackups(d); else if (tab === 'broadcast') body = sysBroadcast(d); else body = sysAudit(d);
      return `${head('Tizim', 'Tizim holati, zaxiralar va texnik sozlamalarni boshqaring.')}${tabsBar('sys', SEC.sys.tabs(), tab)}${body}`;
    },
    after(d, tab) { clearTimeout(S.bkTimer); if (tab === 'backups' && d.s.backup?.requested) S.bkTimer = setTimeout(() => { if (S.sec === 'sys' && S.tab === 'backups') load(true); }, 10000); },
  };
  function sysMonitor({ m, s }) {
    const h = m.host, db = m.database, ai = s.ai; const up = uptime(h.uptime_s);
    const hostOk = [h.cpu_pct, h.mem_pct, h.disk_pct].every(v => v == null || v < 85);
    const bar = v => (v == null ? '<div class="v">—</div><span class="muted xs">Noma\'lum</span>' : `<div class="v">${v}%</div><div class="meter ${v >= 90 ? 'bad' : v >= 75 ? 'warn' : ''}"><i style="width:${v}%"></i></div>`);
    return `<div class="row sp"><span class="stamp">Yangilangan: ${fmtDT(m.checked_at)}</span><button class="btn sec sm" data-act="reload">${I('refresh', 'ico s')}Yangilash</button></div>
    <div class="g g2">
      <div class="card"><div class="ch"><div class="ttl">${I('server', 'ico l')}<h2>Server holati</h2></div>${hostOk ? badge('ok', 'Normada', 'dot') : badge('warn', 'Diqqat', 'dot')}</div>
        <div class="mbox"><div><div class="k">CPU yuklamasi</div>${bar(h.cpu_pct)}</div><div><div class="k">Xotira (RAM)</div>${bar(h.mem_pct)}${h.mem_total_gb ? `<span class="muted xs">jami ${String(h.mem_total_gb).replace('.', ',')} GB</span>` : ''}</div>
        <div><div class="k">Disk</div>${bar(h.disk_pct)}<span class="muted xs">bo'sh ${String(h.disk_free_gb).replace('.', ',')} GB</span></div><div><div class="k">Uptime</div><div class="v" style="font-size:24px">${up ? esc(up[0]) : '—'}</div><span class="muted xs">${up ? esc(up[1]) : "Noma'lum"}</span></div></div></div>
      <div class="card"><div class="ch"><div class="ttl">${I('db', 'ico l')}<h2>Ma'lumotlar bazasi</h2></div>${db.ok ? badge('ok', 'Normada', 'dot') : badge('bad', 'Xato', 'dot')}</div>
        <div class="mbox"><div><div class="k">Ulanish holati</div><div class="v row" style="gap:8px">${db.ok ? `Faol ${I('checkc', 'ico l')}` : 'Xato'}</div><span class="muted xs">${esc(db.version ? (db.dialect === 'postgresql' ? 'PostgreSQL ' + db.version : db.version) : "Noma'lum")}${db.latency_ms != null ? ` · ${String(db.latency_ms).replace('.', ',')} ms` : ''}</span></div>
        <div><div class="k">Ma'lumotlar hajmi</div><div class="v">${bytes(db.size_bytes)}</div><span class="muted xs">${db.tables != null ? fmt(db.tables) + ' ta jadval' : "Noma'lum"}</span></div>
        <div><div class="k">Faol ulanishlar</div><div class="v">${db.connections != null ? `${fmt(db.connections)}${db.max_connections ? ' / ' + fmt(db.max_connections) : ''}` : '—'}</div><span class="muted xs">${db.max_connections ? 'Maksimal: ' + fmt(db.max_connections) : "Noma'lum"}</span></div></div></div>
    </div>
    <div class="g g3">
      <div class="card"><div class="ch"><div class="ttl">${I('ai', 'ico l')}<h2>AI servis</h2></div>${ai ? badge('ok', 'Ishlayapti', 'dot') : badge('bad', 'Javob bermayapti', 'dot')}</div>
        <dl class="kv"><dt>Model</dt><dd class="mono small">${esc(ai ? (ai.model_tag || ai.model_file || ai.model) : '—')}</dd><dt>Sinflar</dt><dd>${fmt(ai?.classes)}</dd><dt>Fayl</dt><dd>${ai?.model_size_mb ? String(ai.model_size_mb).replace('.', ',') + ' MB' : '—'}</dd></dl></div>
      <div class="card"><div class="ch"><div class="ttl">${I('layers', 'ico l')}<h2>Fon ishlari (tahlil)</h2></div>${m.jobs.failed ? badge('warn', `${m.jobs.failed} ta xato`) : badge('ok', 'Normada', 'dot')}</div>
        <dl class="kv"><dt>Navbatda</dt><dd>${fmt(m.jobs.queued)}</dd><dt>Ishlanmoqda</dt><dd>${fmt(m.jobs.processing)}</dd><dt>Tugagan</dt><dd>${fmt(m.jobs.done)}</dd><dt>Xato bilan</dt><dd>${fmt(m.jobs.failed)}</dd></dl></div>
      <div class="card"><div class="ch"><div class="ttl">${I('info', 'ico l')}<h2>Ilova</h2></div></div>
        <dl class="kv"><dt>Versiya</dt><dd class="mono">${esc(m.version)}</dd><dt>Muhit</dt><dd>${esc(m.environment)}</dd><dt>To'lovlar</dt><dd>${s.payment_mode === 'sandbox' ? badge('warn sm', 'Sinov rejimi') : badge('ok sm', 'Jonli')}</dd><dt>Foydalanuvchilar</dt><dd>${fmt(s.users)}</dd></dl></div>
    </div>`;
  }
  function sysBackups({ s, audit }) {
    const b = s.backup || {};
    return `<div class="card"><div class="ch"><div class="ttl">${I('db', 'ico l')}<div><h2>Zaxira nusxalari</h2><div class="sub">Baza va rasmlarning avtomatik (har kuni) va qo'lda olingan nusxalari.</div></div></div>
        ${b.available ? `<button class="btn pri" data-act="backup" ${b.requested ? 'disabled' : ''}>${b.requested ? `${I('clock', 'ico s')}So'raldi, navbatda…` : `${I('plus', 'ico s')}Zaxira yaratish`}</button>` : ''}</div>
      ${!b.available ? `<div class="banner info">${I('info')}<p>Zaxira holati faqat serverda ko'rinadi (zaxira papkasi backend'ga ulanmagan). Lokal muhitda bu bo'lim bo'sh.</p></div>`
      : `${b.requested ? `<div class="banner info">${I('refresh')}<p>Zaxira so'raldi — 1–5 daqiqada boshlanadi. Holat shu sahifada 10 soniyada yangilanadi.</p></div>` : ''}
        ${b.status ? `<div class="banner ${b.ok ? 'ok' : 'warn'}">${I(b.ok ? 'checkc' : 'alert')}<p>${esc(b.status)}${b.last_ok ? ` · oxirgi muvaffaqiyatli: ${fmtDT(b.last_ok)}` : ''}</p></div>` : ''}
        <div class="tw" style="margin-top:16px"><table><thead><tr><th>Sana va vaqt (UTC)</th><th>Turi</th><th class="n">Fayl hajmi</th><th>Holat</th><th>Saqlash joyi</th></tr></thead><tbody>
        ${(b.files || []).map(f => `<tr><td class="mono">${esc(f.name.replace(/^(\d{4})(\d\d)(\d\d)-?(\d\d)(\d\d).*/, '$1-$2-$3 $4:$5'))}</td><td>${f.media_mb == null ? "Faqat ma'lumotlar" : "To'liq zaxira (baza + rasmlar)"}</td>
          <td class="n">${mb(f.db_mb)}${f.media_mb != null ? ` + ${mb(f.media_mb)}` : ''}</td><td>${badge('ok', 'Muvaffaqiyatli', 'checkc')}</td><td>${b.offsite ? 'Server + bulut' : 'Server'}</td></tr>`).join('')}
        </tbody></table>${(b.files || []).length ? '' : emptyState("Hali zaxira nusxasi yo'q", "«Zaxira yaratish» bilan birinchisini oling.")}</div>
        <p class="muted small" style="margin-top:12px">Tiklash — xavfli amal, faqat serverdan bajariladi (<span class="mono">deploy/restore.sh</span>, docs/BACKUP.md). Yuklab olish xavfsizlik uchun panelda yo'q.</p>`}</div>
    <div class="card"><div class="ch"><div class="ttl">${I('doc', 'ico l')}<div><h2>Tizim jurnali</h2><div class="sub">Asosiy administrator amallari va tizim voqealari.</div></div></div><button class="btn sec sm" data-go="sys/audit">${I('ext', 'ico s')}Barchasini ko'rish</button></div>${auditTable(audit.items)}</div>`;
  }
  function sysBroadcast({ aud, log }) {
    return `<div class="g g2" style="align-items:start"><form class="card" data-form="broadcast" style="display:grid;gap:16px"><h2>Ommaviy xabar</h2>
        <div class="fld"><label for="bc-a">Auditoriya <span class="req" aria-hidden="true">*</span></label><select id="bc-a" name="audience">${aud.map(a => `<option value="${esc(a.key)}" data-n="${a.count}">${esc(a.title)} (${fmt(a.count)})</option>`).join('')}</select></div>
        <div class="fld"><label for="bc-h">Sarlavha <span class="req" aria-hidden="true">*</span></label><input id="bc-h" name="title" required minlength="3" maxlength="150" placeholder="Masalan: Ertaga kuchli yomg'ir"><span class="help">3–150 belgi</span></div>
        <div class="fld"><label for="bc-t">Matn <span class="req" aria-hidden="true">*</span></label><textarea id="bc-t" name="body" rows="4" required minlength="3" maxlength="1000" placeholder="Purkashni bugun kechqurunga ko'chiring."></textarea><span class="help">3–1000 belgi</span></div>
        <div class="row"><button class="btn pri" type="submit">${I('send', 'ico s')}Ko'rib chiqish va yuborish</button></div></form>
      <div class="col"><div class="card"><h2 style="margin-bottom:12px">Ko'rinishi (ilovada)</h2><div class="notif"><img src="/admin/logo.svg?v=1" alt=""><div style="min-width:0"><b id="pv-h">Sarlavha</b><p class="small muted" id="pv-t" style="white-space:pre-line">Xabar matni shu yerda ko'rinadi.</p><span class="xs muted">AgroYordam · hozir</span></div></div></div>
        <div class="card"><h2 style="margin-bottom:8px">Yuborilgan xabarlar</h2>${log.items.length ? `<div class="list">${log.items.map(a => `<div class="li"><div class="grow"><div class="t small">${esc(a.summary)}</div><div class="m">${esc(a.actor)} · ${fmtDT(a.created_at)}</div></div></div>`).join('')}</div>` : '<p class="muted small">Hali ommaviy xabar yuborilmagan.</p>'}</div></div></div>`;
  }
  const auditTable = items => (items.length ? `<div class="tw"><table><thead><tr><th>Sana va vaqt</th><th>Foydalanuvchi</th><th>Amal</th><th>Tafsilot</th></tr></thead><tbody>${items.map(a => `<tr><td class="num">${fmtDT(a.created_at)}</td><td>${esc(a.actor)}</td><td><span class="row" style="flex-wrap:nowrap"><span class="b ${actionDot(a.action)}" style="width:9px;height:9px;padding:0"></span>${esc(ACTIONS[a.action] || a.action)}</span></td><td class="wrap small">${esc(a.summary)}</td></tr>`).join('')}</tbody></table></div>` : emptyState("Jurnal bo'sh"));
  function sysAudit({ audit }) {
    const f = S.audf;
    return `<div class="card"><div class="ch"><div><h2>Harakatlar jurnali</h2><div class="sub">Kim, qanday amal, qachon. Jurnal tahrirlanmaydi; parol va tokenlar yozilmaydi.</div></div></div>
      <div class="filters" style="margin-bottom:16px"><label class="search"><span class="sr">Qidiruv</span>${I('search')}<input id="auq" data-q="audf" placeholder="Tafsilot yoki foydalanuvchi bo'yicha…" value="${esc(f.q)}"></label>
        ${sel('aua', 'Amal turi', [['', 'Barcha amallar'], ...audit.actions.map(a => [a, ACTIONS[a] || a])], f.action, 'audf', 'data-k="action"')}</div>
      ${auditTable(audit.items)}${pager(audit.total, f.limit, f.offset, 'audit')}</div>`;
  }

  // ---------- Toast, drawer, modal ----------
  function toast(m, bad = false) {
    document.querySelectorAll('.toast').forEach(t => t.remove());
    const t = document.createElement('div'); t.className = 'toast' + (bad ? ' bad' : ''); t.setAttribute('role', bad ? 'alert' : 'status');
    t.innerHTML = I(bad ? 'alert' : 'checkc'); const s = document.createElement('span'); s.textContent = m; t.append(s);
    document.body.append(t); clearTimeout(toast._t); toast._t = setTimeout(() => t.remove(), bad ? 6000 : 3500);
  }
  const fail = e => toast(e.message || String(e), true);
  let lastFocus = null;
  function closeDrawer(fromHash = false) {
    const had = document.querySelector('.drawer'); document.querySelectorAll('.scrim:not(.modal-scrim),.drawer').forEach(e => e.remove());
    if (had && S.drawerKind === 'user' && !fromHash && S.sec === 'users' && location.hash.startsWith('#users/')) history.back();
    S.drawerKind = null; S.drawerUser = null; if (lastFocus && document.contains(lastFocus)) lastFocus.focus();
  }
  function drawer(html, kind) {
    document.querySelectorAll('.scrim:not(.modal-scrim),.drawer').forEach(e => e.remove());
    lastFocus = document.activeElement; S.drawerKind = kind;
    const s = document.createElement('div'); s.className = 'scrim'; s.dataset.act = 'close';
    const d = document.createElement('aside'); d.className = 'drawer'; d.setAttribute('role', 'dialog'); d.setAttribute('aria-modal', 'true'); d.innerHTML = html;
    document.body.append(s, d); (d.querySelector('[data-act=close]') || d).focus();
  }
  let mFocus = null;
  function modal(html, wide = false) {
    closeModal(); mFocus = document.activeElement;
    const s = document.createElement('div'); s.className = 'scrim modal-scrim'; s.dataset.act = 'mclose';
    const m = document.createElement('div'); m.className = 'modal' + (wide ? ' wide' : ''); m.setAttribute('role', 'dialog'); m.setAttribute('aria-modal', 'true'); m.innerHTML = html;
    document.body.append(s, m); (m.querySelector('input,select,textarea') || m.querySelector('.btn.pri,.btn.dan,.btn.ok') || m.querySelector('button')).focus();
    return m;
  }
  function closeModal() { const had = document.querySelector('.modal'); document.querySelectorAll('.modal,.modal-scrim').forEach(e => e.remove()); if (had && mFocus && document.contains(mFocus)) mFocus.focus(); }
  // Tasdiq oynasi: tavsif va oqibat ko'rinadi, Cancel neytral, asosiy tugma aniq nomli
  function confirmBox({ title, text, ok, danger = false, field = null }) {
    return new Promise(res => {
      const m = modal(`<h3>${esc(title)}</h3><p class="muted">${text}</p>${field ? `<div class="fld"><label for="cf-in">${esc(field.label)}${field.required ? ' <span class="req">*</span>' : ''}</label>${field.options ? `<select id="cf-in">${field.options.map(o => `<option>${esc(o)}</option>`).join('')}</select>` : `<textarea id="cf-in" rows="3" maxlength="${field.max || 255}" placeholder="${esc(field.placeholder || '')}"></textarea>`}<span class="err" id="cf-err" hidden>${I('alert', 'ico s')}<span>Bu maydon majburiy</span></span></div>` : ''}
        <div class="acts"><button class="btn sec" data-c="0">Bekor qilish</button><button class="btn ${danger ? 'dan' : 'pri'}" data-c="1">${esc(ok)}</button></div>`);
      m.addEventListener('click', e => {
        const b = e.target.closest('[data-c]'); if (!b) return;
        if (b.dataset.c === '0') { closeModal(); res(null); return; }
        const v = field ? m.querySelector('#cf-in').value.trim() : true;
        if (field && field.required && !v) { const i = m.querySelector('#cf-in'); i.setAttribute('aria-invalid', 'true'); m.querySelector('#cf-err').hidden = false; i.focus(); return; }
        closeModal(); res(v);
      });
      m.dataset.resolve = '1'; m._res = res;
    });
  }

  // ---------- Karkas ----------
  const root = document.getElementById('root');
  const LEAF_ART = '<svg viewBox="0 0 140 160" aria-hidden="true"><path d="M70 158C70 110 60 72 30 40" fill="none" stroke="#6E9C7E" stroke-width="2"/><path d="M68 120c-30-6-48-28-50-58 28 4 46 24 50 58z" fill="#3E7A55"/><path d="M71 92c4-34 26-58 58-64-2 34-24 58-58 64z" fill="#4E8C64"/><path d="M58 60c-18-14-24-34-18-56 18 12 24 32 18 56z" fill="#5E9D73"/></svg>';
  function shell() {
    root.innerHTML = `<div class="app"><nav class="side" id="side" aria-label="Admin menyusi"><a class="brand" href="#dash" data-go="dash"><img src="/admin/logo.svg?v=1" alt=""><span>AgroYordam</span></a><div id="navs"></div>
      <div class="side-foot">${LEAF_ART}Tabiat bilan<br>bilim, hosil bilan<br>kelajak.</div></nav>
      <div class="main-wrap"><header class="top"><button class="btn ghost icon burger" data-act="burger" aria-label="Menyu" aria-controls="side" aria-expanded="false">${I('menu')}</button><nav class="crumbs" id="crumbs" aria-label="Joylashuv"></nav>
        <div class="top-r"><span id="env"></span>${themeSwitch()}<div class="acct"><button data-act="acct" aria-haspopup="menu" aria-expanded="false">${avatar(S.me.full_name, S.me.avatar_url)}<span class="who-t"><span class="nm" style="display:block">${esc(S.me.full_name)}</span><span class="rl">${esc((ROLES[S.me.role] || [, S.me.role])[1] === 'Admin' ? 'Tizim administratori' : (ROLES[S.me.role] || [, S.me.role])[1])}</span></span>${I('chevD', 'ico s')}</button></div></div></header>
      <main class="main" id="main" tabindex="-1"></main></div></div>`;
  }
  function paintNav() {
    const el = document.getElementById('navs'); if (!el) return;
    el.innerHTML = ORDER.map(k => { const n = SEC[k].badge && SEC[k].badge(); return `<button class="nav" data-go="${k}" ${S.sec === k ? 'aria-current="page"' : ''} title="${SEC[k].label}">${I(SEC[k].ic)}<span>${SEC[k].short || SEC[k].label}</span>${n ? `<span class="badge-n" aria-label="${n} ta yangi">${n}</span>` : ''}</button>`; }).join('');
    const sec = SEC[S.sec]; const tab = sec.tabs && sec.tabs().find(t => t[0] === S.tab);
    document.getElementById('crumbs').innerHTML = `<a href="#dash" data-go="dash" aria-label="Boshqaruv paneli">${I('home', 'ico s')}</a>${I('chevR', 'ico s')}${tab ? `<a href="#${S.sec}" data-go="${S.sec}">${esc(sec.label)}</a>${I('chevR', 'ico s')}<b>${esc(tab[1])}</b>` : `<b>${esc(sec.label)}</b>`}`;
    document.getElementById('env').innerHTML = S.mode === 'sandbox' ? `<span class="env" title="To'lovlar sinov rejimida — haqiqiy pul olinmaydi">${I('alert', 'ico s')}<span class="t">Sinov rejimi</span></span>` : S.mode === 'live' ? `<span class="env live">${I('checkc', 'ico s')}<span class="t">Jonli</span></span>` : '';
    document.title = `${tab ? tab[1] + ' · ' : ''}${sec.label} — AgroYordam admin`;
  }
  function skeleton() {
    return `<div class="head"><div><div class="sk" style="height:40px;width:320px"></div><div class="sk" style="height:20px;width:420px;margin-top:10px"></div></div></div>
      <div class="g g4">${'<div class="card kpi"><div class="sk" style="width:52px;height:52px;border-radius:999px"></div><div style="flex:1"><div class="sk" style="height:18px;width:70%"></div><div class="sk" style="height:32px;width:50%;margin-top:8px"></div></div></div>'.repeat(4)}</div>
      <div class="card"><div class="sk" style="height:260px"></div></div>`;
  }
  function paint() {
    const main = document.getElementById('main'); const sec = SEC[S.sec]; const d = S.data[keyOf()];
    hideTip(); paintNav();
    if (d === undefined) { main.innerHTML = skeleton(); return; }
    if (d instanceof Error) { main.innerHTML = `${head(sec.label, '')}${sec.tabs ? tabsBar(S.sec, sec.tabs(), S.tab, S.sec === 'ai' || S.sec === 'pay' ? 'seg' : '') : ''}<div class="card">${errState(d)}</div>`; return; }
    const y = window.scrollY; main.innerHTML = sec.render(d, S.tab); sec.after && sec.after(d, S.tab); window.scrollTo({ top: y });
  }
  async function load(keepOld = false) {
    const k = keyOf(), sec = S.sec, tab = S.tab;
    if (!keepOld || !S.data[k] || S.data[k] instanceof Error) { delete S.data[k]; paint(); }
    try { S.data[k] = await SEC[sec].load(tab); } catch (e) { if (e.code === 401 && !store.at) return; S.data[k] = e; }
    if (keyOf() === k) paint();
  }
  // Marshrut: hash o'zgarganda bo'lim/tab/drawer
  function route() {
    const { sec, a, b } = parseHash(); const def = SEC[sec].tabs ? SEC[sec].def : null;
    let tab = def ? (SEC[sec].tabs().some(t => t[0] === a) ? a : def) : null;
    const uid = sec === 'users' && a && /^[0-9a-f-]{36}$/i.test(a) ? a : null;
    const changed = sec !== S.sec || tab !== S.tab;
    S.sec = sec; S.tab = tab;
    document.getElementById('side')?.classList.remove('open');
    clearTimeout(S.trainTimer); clearTimeout(S.bkTimer);
    if (S.drawerKind === 'user' && !uid) closeDrawer(true);
    if (changed || !S.data[keyOf()]) { if (changed) { closeDrawer(true); window.scrollTo({ top: 0 }); } load(!changed); }
    else paint();
    if (uid && (!S.drawerUser || S.drawerUser.id !== uid)) openUser(uid);
    void b;
  }
  const go = path => { if (location.hash === '#' + path) route(); else location.hash = path; };
  async function act(fn, ok, btn) {
    if (btn) { if (btn.classList.contains('busy')) return; btn.classList.add('busy'); btn.setAttribute('aria-busy', 'true'); }
    try { await fn(); if (ok) toast(ok); Object.keys(S.data).forEach(k => { if (!k.startsWith(S.sec + ':') && k !== 'dash:') delete S.data[k]; }); delete S.data['dash:']; await load(true); return true; }
    catch (e) { fail(e); return false; }
    finally { if (btn) { btn.classList.remove('busy'); btn.removeAttribute('aria-busy'); } }
  }
  const findIn = (arr, id) => (arr || []).find(x => String(x.id) === String(id));

  // ---------- Hodisalar ----------
  document.addEventListener('click', async e => {
    const acctOpen = document.querySelector('.menu');
    if (acctOpen && !e.target.closest('.acct')) { acctOpen.remove(); document.querySelector('[data-act=acct]')?.setAttribute('aria-expanded', 'false'); }
    const t = e.target.closest('[data-act],[data-go],[data-tab]'); if (!t || t.disabled) return;
    if (t.tagName === 'SELECT' || (t.tagName === 'INPUT' && t.type !== 'button')) return; // o'zgarish "change" orqali
    if (t.dataset.go) { e.preventDefault(); closeDrawer(true); closeModal(); go(t.dataset.go); return; }
    if (t.dataset.tab) { go(`${t.dataset.sec}/${t.dataset.tab}`); return; }
    const a = t.dataset.act, v = t.dataset.v, d = S.data[keyOf()];
    switch (a) {
      case 'burger': { const s = document.getElementById('side'); s.classList.toggle('open'); t.setAttribute('aria-expanded', String(s.classList.contains('open'))); } break;
      case 'acct': {
        if (document.querySelector('.menu')) { document.querySelector('.menu').remove(); t.setAttribute('aria-expanded', 'false'); break; }
        const m = document.createElement('div'); m.className = 'menu'; m.setAttribute('role', 'menu');
        m.innerHTML = `<div style="padding:10px 12px"><b>${esc(S.me.full_name)}</b><div class="muted xs">@${esc(S.me.username)}</div></div><div style="padding:4px 12px 10px">${themeSwitch()}</div><button role="menuitem" data-act="logout">${I('logout', 'ico s')}Hisobdan chiqish</button>`;
        t.parentElement.append(m); t.setAttribute('aria-expanded', 'true'); m.querySelector('button').focus();
      } break;
      case 'tv': S.chartTable[v] = !S.chartTable[v]; paint(); break;
      case 'reload': load(); break;
      case 'close': closeDrawer(); break;
      case 'mclose': closeModal(); break;
      case 'logout': logout(); break;
      case 'theme': try { localStorage.setItem(THEME_KEY, v); } catch { /* maxfiy rejim */ } applyTheme(v); document.querySelectorAll('.themes button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.v === v))); if (S.me) paint(); break;
      case 'zoom': modal(`<div class="row sp"><h3>${esc(t.dataset.t || 'Rasm')}</h3><button class="btn ghost icon" data-act="mclose" aria-label="Yopish">${I('x')}</button></div><img class="zoom" src="${esc(t.dataset.src)}" alt="${esc(t.dataset.t || '')}">`, true); break;
      case 'page': { const k = t.dataset.k === 'users' ? S.uf : S.audf; k.offset = (Math.max(1, +v) - 1) * k.limit; load(true); } break;
      // Foydalanuvchilar
      case 'user': if (S.sec === 'users') { if (location.hash !== '#users/' + v) location.hash = 'users/' + v; } else { closeDrawer(true); location.hash = 'users/' + v; } break;
      case 'uclear': S.uf = { ...S.uf, q: '', role: 'all', state: 'all', region: '', plan: 'all', offset: 0 }; load(true); break;
      case 'utab': S.drawerUser.tab = v; paintUser(); break;
      case 'ushow': S.drawerUser.show = !S.drawerUser.show; paintUser(); break;
      case 'saverole': {
        const u = S.drawerUser.data; const role = document.getElementById('role-s').value; if (role === u.role) { toast("Rol o'zgarmadi"); break; }
        if (!await confirmBox({ title: "Rolni o'zgartirish", text: `«${esc(u.full_name)}»: ${esc(ROLES[u.role][1])} → <b>${esc(ROLES[role][1])}</b>. ${role === 'admin' ? "Admin barcha bo'limlarni boshqaradi." : ''}`, ok: "Rolni o'zgartirish" })) break;
        if (await act(() => api(`/admin/users/${u.id}/role`, { method: 'PUT', body: { role } }), 'Rol saqlandi', t)) openUser(u.id, 'lim');
      } break;
      case 'blockask': {
        const reason = await confirmBox({ title: 'Hisobni bloklash', text: `${esc(t.dataset.n)} ilovaga kira olmaydi. Ma'lumotlari saqlanadi; blokni istalgan vaqtda olib tashlash mumkin. Sabab jurnalga yoziladi.`, ok: 'Hisobni bloklash', danger: true, field: { label: 'Bloklash sababi', required: true, placeholder: 'Masalan: spam, reklama, haqorat', max: 200 } });
        if (reason && await act(() => api(`/admin/users/${v}/block?blocked=true&reason=${encodeURIComponent(reason)}`, { method: 'PUT' }), 'Hisob bloklandi')) openUser(v, 'lim');
      } break;
      case 'unblock': if (await act(() => api(`/admin/users/${v}/block?blocked=false`, { method: 'PUT' }), 'Blokdan chiqarildi', t)) openUser(v, 'lim'); break;
      case 'pwreset':
        if (!await confirmBox({ title: 'Vaqtinchalik parol berish', text: `${esc(t.dataset.n)} uchun yangi vaqtinchalik parol yaratiladi. Eski parol ishlamay qoladi va u barcha qurilmalardan chiqariladi.`, ok: 'Parol yaratish' })) break;
        api(`/admin/users/${v}/reset-password`, { method: 'POST' }).then(pwModal).catch(fail); break;
      case 'pwcopy': {
        const txt = `AgroYordam\nLogin: ${t.dataset.u}\nVaqtinchalik parol: ${t.dataset.p}`;
        (navigator.clipboard ? navigator.clipboard.writeText(txt) : Promise.reject(new Error('Brauzer nusxalashga ruxsat bermadi'))).then(() => { t.innerHTML = `${I('check', 'ico s')}Nusxalandi`; }).catch(fail);
      } break;
      // Boshqaruv / AI: tashxis ko'rish
      case 'diag': diagModal(d.queue.items[+v]); break;
      // Agronomlar
      case 'app': appDrawer(findIn(d.apps, v)); break;
      case 'expert': expertDrawer(findIn(d.experts, v)); break;
      case 'approve':
        if (!await confirmBox({ title: 'Arizani tasdiqlash', text: `${esc(t.dataset.n)} agronom bo'ladi: ilovasi agronom rejimida ochiladi, tekshiruv navbati va savollarga kirish beriladi.`, ok: 'Arizani tasdiqlash' })) break;
        if (await act(() => api(`/admin/expert-applications/${v}/approve`, { method: 'POST' }), "Ariza tasdiqlandi — foydalanuvchi endi agronom", t)) closeDrawer(); break;
      case 'appreject': {
        const reason = await confirmBox({ title: 'Arizani rad etish', text: `${esc(t.dataset.n)} sababni ilovada ko'radi va tuzatib qayta topshira oladi.`, ok: 'Arizani rad etish', danger: true, field: { label: 'Sabab', options: ['Hujjat yuklanmagan', "Hujjat o'qilmaydi", 'Tajriba yetarli emas', "Ma'lumot to'liq emas", "Mutaxassislik ko'rsatilmagan"] } });
        if (reason && await act(() => api(`/admin/expert-applications/${v}/reject`, { method: 'POST', body: { reason } }), 'Ariza rad etildi, sababi yuborildi')) closeDrawer();
      } break;
      case 'revoke':
        if (!await confirmBox({ title: "Agronom vakolatini to'xtatish", text: `${esc(t.dataset.n)} oddiy dehqon bo'lib qoladi: tekshiruv navbati va savollarga kira olmaydi. Hisob bloklanmaydi.`, ok: "Vakolatni to'xtatish", danger: true })) break;
        if (await act(() => api(`/admin/users/${v}/role`, { method: 'PUT', body: { role: 'user' } }), "Agronom vakolati to'xtatildi", t)) closeDrawer(); break;
      // AI
      case 'activate': {
        const force = !!t.dataset.force, rb = !!t.dataset.rb;
        if (!await confirmBox({ title: rb ? 'Oldingi versiyaga qaytarish' : 'Modelni faollashtirish', text: force ? `<b>${esc(v)}</b> dala rasmlari testisiz faollashtiriladi. Haqiqiy foydalanuvchilarda sifat noma'lum.` : rb ? `<b>${esc(v)}</b> versiyasiga qaytiladi (rollback). Yangi tashxislar shu model bilan qilinadi.` : `<b>${esc(v)}</b> faollashtiriladi. Kerak bo'lsa eski versiyaga qaytish mumkin.`, ok: rb ? 'Qaytarish' : 'Faollashtirish', danger: force })) break;
        act(() => api(`/admin/ai/models/${v}/activate`, { method: 'POST', body: { force } }), `${v} faollashtirildi`, t);
      } break;
      case 'train':
        if (!await confirmBox({ title: "Yangi o'qitishni boshlash", text: "GitHub Actions'da ~1 soat davom etadi. Tayyor bo'lgach yangi nomzod versiya «Model» tabida paydo bo'ladi; faollashtirish alohida.", ok: "O'qitishni boshlash" })) break;
        act(() => api('/admin/ai/training', { method: 'POST' }), "O'qitish boshlandi. Holati shu yerda yangilanib turadi", t); break;
      case 'export': api('/admin/dataset/export-link', { method: 'POST' }).then(r => { location.href = API + r.url; toast('Yuklab olish boshlandi (havola 10 daqiqa amal qiladi)'); }).catch(fail); break;
      // Bilimlar bazasi
      case 'kbitem': kbDrawer(findIn(d.list.items, v), S.tab); break;
      case 'kbf': S.kbf[t.dataset.k] = v; paint(); break;
      case 'kbclear': S.kbf = { q: '', plant: '', state: 'all' }; paint(); break;
      case 'revert':
        if (!await confirmBox({ title: "O'zgarishni qaytarish", text: "Oldingi matn tiklanadi va tarixga yangi yozuv tushadi.", ok: 'Qaytarish' })) break;
        act(() => api(`/admin/catalog-changes/${v}/revert`, { method: 'POST' }), "O'zgarish qaytarildi", t); break;
      // Moderatsiya
      case 'modsel': S.modSel = v; paint(); document.querySelector('.g75 > .card:last-child')?.scrollIntoView({ block: 'nearest', behavior: 'smooth' }); break;
      case 'modstart': case 'moddismiss': case 'modhide': {
        const x = d.items.find(i => i.target_id === S.modSel); if (!x) break;
        const note = (document.getElementById('mod-note')?.value || '').trim(); const body = { kind: x.kind, target_id: x.target_id, note: note || null };
        if (a === 'modstart') { act(() => api('/admin/moderation/start', { method: 'POST', body: { kind: x.kind, target_id: x.target_id } }), "Ko'rib chiqilmoqda tabiga o'tkazildi", t); break; }
        if (a === 'moddismiss') {
          if (!await confirmBox({ title: 'Shikoyatni rad etish', text: `${x.count} ta shikoyat yopiladi, kontent joyida qoladi. Muallifga xabar bormaydi.`, ok: 'Shikoyatni rad etish' })) break;
          if (await act(() => api('/admin/reports/dismiss', { method: 'POST', body }), 'Shikoyat rad etildi — kontent qoldi', t)) S.modSel = null; break;
        }
        const noun = { post: 'Post', comment: 'Izoh', message: 'Chat xabari' }[x.kind];
        if (!await confirmBox({ title: `${noun}ni yashirish`, text: `${noun} olib tashlanadi va muallifga${note ? ' sabab bilan' : ''} bildirishnoma boradi. Bu amalni qaytarib bo'lmaydi.`, ok: `${noun}ni yashirish`, danger: true })) break;
        if (await act(() => api('/admin/reports/hide', { method: 'POST', body }), `${noun} yashirildi, muallifga xabar berildi`, t)) S.modSel = null;
      } break;
      // To'lovlar
      case 'tx': txDrawer(findIn(d.list.items, v)); break;
      case 'payclear': S.payf = { from: '', to: '', provider: 'all', status: 'all', env: 'all' }; paint(); break;
      case 'csv': {
        const rows = filterTx(d.list.items); const cell = x => `"${String(x ?? '').replace(/"/g, '""')}"`;
        const csv = ['Sana;Foydalanuvchi;Buyurtma;Provayder;Summa;Valyuta;Tarif;Holat;Muhit', ...rows.map(r => [fmtDT(r.created_at), r.user, r.order, r.provider, r.amount, r.currency, PLAN[r.plan] || r.plan, txStatus(r)[1], r.sandbox ? 'Sinov' : r.paid ? 'Haqiqiy' : ''].map(cell).join(';'))].join('\n');
        const aEl = document.createElement('a'); aEl.href = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })); aEl.download = `tolovlar-${new Date().toISOString().slice(0, 10)}.csv`; aEl.click(); URL.revokeObjectURL(aEl.href);
      } break;
      // Tizim
      case 'backup':
        if (!await confirmBox({ title: 'Zaxira yaratish', text: "Baza va rasmlarning to'liq nusxasi olinadi (1–5 daqiqada boshlanadi). Ish vaqtida tizim sekinlashmaydi.", ok: 'Zaxira yaratish' })) break;
        act(() => api('/admin/system/backup-now', { method: 'POST' }), "Zaxira so'raldi: 1–5 daqiqada boshlanadi", t); break;
    }
  });
  // Select/date o'zgarishlari
  document.addEventListener('change', e => {
    const t = e.target; const a = t.dataset.act; if (!a) return;
    const k = t.dataset.k, v = t.value;
    switch (a) {
      case 'range': S.range = +v; load(); break;
      case 'metric': S.metric = v; paint(); break;
      case 'uf': S.uf[k] = v; S.uf.offset = 0; load(true); break;
      case 'af': S.af[k] = v; paint(); break;
      case 'kbf': S.kbf[k] = v; paint(); break;
      case 'dsf': S.dsf[k] = v; paint(); break;
      case 'modf': S.modf[k] = v; paint(); break;
      case 'payf': S.payf[k] = v; paint(); break;
      case 'subf': S.subf = v; paint(); break;
      case 'audf': S.audf[k] = v; S.audf.offset = 0; load(true); break;
      case 'psize': { const o = t.dataset.k === 'users' ? S.uf : S.audf; o.limit = +v; o.offset = 0; load(true); } break;
    }
  });
  // Qidiruv: 300 ms kechikish; serverdagi ro'yxat (users, audit) qayta yuklanadi, qolganlari joyida filtrlanadi
  let qTimer;
  document.addEventListener('input', e => {
    const t = e.target;
    if (t.id === 'mod-note') { document.getElementById('mod-cnt').textContent = `${t.value.length}/500`; return; }
    if (t.id === 'bc-h' || t.id === 'bc-t') { document.getElementById(t.id === 'bc-h' ? 'pv-h' : 'pv-t').textContent = t.value || (t.id === 'bc-h' ? 'Sarlavha' : "Xabar matni shu yerda ko'rinadi."); return; }
    const key = t.dataset.q; if (!key) return;
    S[key].q = t.value; clearTimeout(qTimer);
    qTimer = setTimeout(async () => {
      const pos = t.selectionStart;
      if (key === 'uf' || key === 'audf') { S[key].offset = 0; await load(true); } else paint();
      const i = document.getElementById(t.id); if (i) { i.focus(); i.setSelectionRange(pos, pos); }
    }, 300);
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      if (document.querySelector('.menu')) { document.querySelector('.menu').remove(); return; }
      if (document.querySelector('.modal')) { closeModal(); return; }
      if (document.querySelector('.drawer')) { closeDrawer(); return; }
      document.getElementById('side')?.classList.remove('open');
    }
    if (e.key === 'Enter' && e.target.matches('tr[tabindex]')) e.target.click();
    // Fokus modal/drawer ichida qoladi
    if (e.key === 'Tab') {
      const box = document.querySelector('.modal') || document.querySelector('.drawer'); if (!box) return;
      const f = [...box.querySelectorAll('button,a[href],input,select,textarea,[tabindex]:not([tabindex="-1"])')].filter(x => !x.disabled && x.offsetParent !== null);
      if (!f.length) return; const first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); } else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });
  document.addEventListener('submit', async e => {
    const f = e.target.closest('form[data-form]'); if (!f) return;
    e.preventDefault();
    const btn = f.querySelector('button[type=submit]');
    if (f.dataset.form === 'settings') {
      const body = {}; const diff = [];
      f.querySelectorAll('input[name]').forEach(i => { body[i.name] = +i.value; if (+i.value !== +i.dataset.old) diff.push(`<li>${esc(i.closest('.fld').querySelector('label').firstChild.textContent.trim())}: <s>${fmt(+i.dataset.old)}</s> → <b>${fmt(+i.value)}</b></li>`); });
      if (!diff.length) { toast("O'zgarish yo'q"); return; }
      if (!await confirmBox({ title: 'Tariflarni saqlash', text: `Quyidagi qiymatlar o'zgaradi:<ul style="margin:8px 0 0;padding-left:20px">${diff.join('')}</ul>`, ok: 'Saqlash' })) return;
      act(() => api('/admin/settings', { method: 'PUT', body }), 'Tariflar saqlandi', btn);
    } else if (f.dataset.form === 'broadcast') {
      const fd = new FormData(f); const opt = f.querySelector('select').selectedOptions[0];
      if (!await confirmBox({ title: 'Xabarni yuborish', text: `«${esc(fd.get('title'))}» <b>${fmt(+opt.dataset.n)}</b> kishiga (${esc(opt.textContent.replace(/\s*\(.*\)$/, ''))}) ilovada bildirishnoma bo'lib boradi. Yuborilgan xabarni qaytarib bo'lmaydi.`, ok: 'Yuborish' })) return;
      act(async () => { const r = await api('/admin/broadcast', { method: 'POST', body: { audience: fd.get('audience'), title: fd.get('title'), body: fd.get('body') } }); toast(`Xabar ${r.sent} kishiga yuborildi`); f.reset(); }, null, btn);
    } else if (f.dataset.form === 'login') login(f);
  });
  window.addEventListener('resize', hideTip);
  window.addEventListener('hashchange', () => { if (S.me) route(); });
  window.addEventListener('online', () => { if (S.me && S.data[keyOf()] instanceof Error) load(); });

  // ---------- Kirish ----------
  function showLogin(msg = '') {
    root.innerHTML = `<div class="login"><section class="login-hero" aria-hidden="true"><div class="brand"><img src="/admin/logo.svg?v=1" alt=""><span>AgroYordam</span></div>
        <h1>Platformani boshqarish markazi</h1><p>Foydalanuvchilar, agronomlar va xizmatlar — yagona boshqaruvda.</p>
        <svg class="leaves" viewBox="0 0 200 220"><g fill="none" stroke="#CFE3D5" stroke-width="1.6"><path d="M30 215C60 150 90 110 150 60"/><path d="M70 150c-30-8-46-34-44-64 30 6 46 30 44 64z"/><path d="M98 112c-2-32 16-56 48-66 4 32-14 58-48 66z"/><path d="M124 84c-26-10-38-34-32-60 26 10 38 34 32 60z"/><path d="M56 182c-24 2-44-14-50-38 26-2 44 14 50 38z"/></g></svg></section>
      <div class="login-side">${themeSwitch()}<form data-form="login" autocomplete="on" novalidate><span class="shield">${I('shieldLock')}</span>
        <div style="text-align:center"><h2>Admin panelga kirish</h2><p class="muted" style="margin-top:6px">Faqat vakolatli xodimlar uchun</p></div>
        <div class="fld"><label for="lg-u">Login yoki email</label><div class="inp-ic">${I('user')}<input id="lg-u" name="login" autocomplete="username" required placeholder="Login yoki emailingiz"></div></div>
        <div class="fld"><label for="lg-p">Parol</label><div class="pw inp-ic">${I('lock')}<input id="lg-p" name="password" type="password" autocomplete="current-password" required placeholder="Parolingizni kiriting"><button type="button" class="btn ghost icon sm" data-act="pwtoggle" aria-label="Parolni ko'rsatish" aria-pressed="false">${I('eye')}</button></div></div>
        <p class="err" role="alert">${msg ? I('alert', 'ico s') + esc(msg) : ''}</p>
        <button class="btn pri" type="submit" style="min-height:52px;font-size:17px">Kirish</button>
        <p class="muted small" style="text-align:center">Parolni unutgan bo'lsangiz, tizim administratoriga murojaat qiling.</p>
        <p class="safe">${I('lock', 'ico s')}Hisobingiz xavfsiz ulanish orqali himoyalanadi.</p></form>
        <a class="link" href="/">${I('chevL', 'ico s')}Ilovaga qaytish</a></div></div>`;
    document.getElementById('lg-u').focus();
  }
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-act=pwtoggle]'); if (!b) return;
    const i = document.getElementById('lg-p'); const show = i.type === 'password'; i.type = show ? 'text' : 'password';
    b.setAttribute('aria-pressed', String(show)); b.setAttribute('aria-label', show ? 'Parolni yashirish' : "Parolni ko'rsatish"); b.innerHTML = I(show ? 'eyeoff' : 'eye');
  });
  async function login(f) {
    const err = f.querySelector('.err'), btn = f.querySelector('button[type=submit]');
    const u = f.login.value.trim(), p = f.password.value;
    f.login.removeAttribute('aria-invalid'); f.password.removeAttribute('aria-invalid');
    if (!u || !p) { err.innerHTML = I('alert', 'ico s') + 'Login va parolni kiriting'; (u ? f.password : f.login).setAttribute('aria-invalid', 'true'); (u ? f.password : f.login).focus(); return; }
    err.textContent = ''; btn.classList.add('busy');
    try { store.set(await raw('/auth/login', { method: 'POST', body: { login: u, password: p }, auth: false })); await start(); }
    catch (e) { err.innerHTML = I('alert', 'ico s') + esc(e.message); btn.classList.remove('busy'); f.password.focus(); }
  }
  async function logout() {
    try { if (store.rt) await raw('/auth/logout', { method: 'POST', body: { refresh_token: store.rt } }); } catch { /* baribir chiqamiz */ }
    store.clear(); S.me = null; S.data = {}; closeDrawer(true); closeModal(); showLogin();
  }
  async function start() {
    if (!store.at) { showLogin(); return; }
    let me;
    try { me = await api('/users/me'); } catch (e) { if (e.code === 401) { store.clear(); showLogin(); } else { showLogin(e.message); } return; }
    if (!['admin', 'moderator'].includes(me.role)) { store.clear(); showLogin("Bu hisobda admin huquqi yo'q. Admin yoki moderator hisobi bilan kiring."); return; }
    S.me = me; shell();
    // Menyudagi raqamlar va muhit belgisi birinchi ochilishdan ko'rinsin
    api('/admin/dashboard?days=7').then(d => { S.badges = { agro: d.attention.applications, mod: d.attention.reports }; S.mode = d.payment_mode; paintNav(); }).catch(() => {});
    route();
  }
  start();
})();
