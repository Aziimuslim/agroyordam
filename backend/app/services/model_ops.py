"""AI modelni yaxshilash sikli: dala rasmlari → agronom tasdig'i → GitHub Actions'da qayta o'qitish → "model-vN" release →
admin panelda "dala rasmlari testi" bo'yicha solishtirish → ishga tushirish yoki qaytarish.

GitHub o'qish so'rovlari (release'lar, workflow holati) — ochiq repo uchun tokensiz (keshlanadi);
o'qitishni boshlash — GITHUB_TRAIN_TOKEN bilan.
"""
import hashlib
import re
import secrets
import time
from datetime import timedelta

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import utcnow
from app.models import AppSetting

TAG_RE = re.compile(r"^model-v(\d{1,4})$")
WORKFLOW = "train-model.yml"
TICKET_KEY = "dataset_ticket"
TICKET_TTL = timedelta(hours=3)

_cache: dict[str, tuple[float, object]] = {}
_metrics: dict[str, dict | None] = {}


class GitHubError(Exception):
    pass


def _headers(auth: bool = False) -> dict:
    h = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "agroyordam"}
    if settings.GITHUB_TRAIN_TOKEN:
        h["Authorization"] = f"Bearer {settings.GITHUB_TRAIN_TOKEN}"
    elif auth:
        raise GitHubError("GITHUB_TRAIN_TOKEN sozlanmagan")
    return h


async def gh(method: str, path: str, ttl: float = 0, **kw):
    """GitHub API so'rovi. ttl>0 — GET natijasi shuncha soniya keshlanadi (tokensiz limit soatiga 60 ta)."""
    key = f"{method} {path}"
    if ttl and key in _cache and _cache[key][0] > time.monotonic():
        return _cache[key][1]
    try:
        async with httpx.AsyncClient(base_url="https://api.github.com", timeout=20, follow_redirects=True) as c:
            r = await c.request(method, path, headers=_headers(auth=method != "GET"), **kw)
    except httpx.HTTPError as exc:
        raise GitHubError(f"GitHub bilan aloqa yo'q: {exc}") from exc
    if r.status_code >= 400:
        msg = r.json().get("message", "") if r.headers.get("content-type", "").startswith("application/json") else ""
        raise GitHubError(f"GitHub {r.status_code}: {msg}".strip())
    data = r.json() if r.content else None
    if ttl:
        _cache[key] = (time.monotonic() + ttl, data)
    return data


async def _release_metrics(rel: dict) -> dict | None:
    tag = rel["tag_name"]
    if tag in _metrics:
        return _metrics[tag]
    asset = next((a for a in rel.get("assets", []) if a["name"].endswith(".metrics.json")), None)
    data = None
    if asset:
        try:
            async with httpx.AsyncClient(timeout=20, follow_redirects=True) as c:
                r = await c.get(asset["browser_download_url"])
            data = r.json() if r.status_code == 200 else None
        except (httpx.HTTPError, ValueError):
            data = None
    _metrics[tag] = data
    return data


def version(tag: str) -> int:
    m = TAG_RE.match(tag)
    return int(m.group(1)) if m else -1


def pct(v: float | None) -> str:
    return "—" if v is None else f"{v * 100:.1f}%"


async def releases() -> list[dict]:
    """model-vN release'lari (yangisi birinchi) metrikalari bilan."""
    rels = await gh("GET", f"/repos/{settings.GITHUB_REPO}/releases", ttl=300, params={"per_page": 50})
    out = []
    for rel in rels or []:
        if not TAG_RE.match(rel["tag_name"]) or rel.get("draft"):
            continue
        m = await _release_metrics(rel) or {}
        out.append({
            "tag": rel["tag_name"], "created_at": rel.get("published_at") or rel.get("created_at"), "url": rel.get("html_url"),
            "classes": m.get("classes"), "val_accuracy": m.get("val_accuracy_onnx"),
            "field_test_accuracy": m.get("field_test_accuracy"), "field_test_samples": m.get("field_test_samples") or 0,
            "baseline_model": m.get("baseline_model"), "baseline_field_test_accuracy": m.get("baseline_field_test_accuracy"),
            "field_train_images": m.get("field_train_images") or 0,
        })
    return sorted(out, key=lambda r: -version(r["tag"]))


def can_activate(rel: dict, active_tag: str | None) -> tuple[bool, str | None, bool]:
    """→ (ruxsat, sabab, majburlash mumkinmi). Qoida: yangi model faqat dala rasmlari testida yomonlashmasa ishga tushadi."""
    if rel["tag"] == active_tag:
        return False, "Hozir shu versiya ishlayapti", False
    if active_tag and version(rel["tag"]) < version(active_tag):
        return True, None, False  # qaytarish (rollback) har doim mumkin
    new, base = rel["field_test_accuracy"], rel["baseline_field_test_accuracy"]
    if new is None or base is None or not rel["field_test_samples"]:
        return False, "Dala rasmlari testi yo'q (tasdiqlangan test rasmlari yetarli emas)", True
    if new < base:
        return False, f"Dala testida yomonroq: {pct(new)} < {pct(base)}", False
    return True, None, False


async def default_ref() -> str:
    if settings.GITHUB_TRAIN_REF:
        return settings.GITHUB_TRAIN_REF
    repo = await gh("GET", f"/repos/{settings.GITHUB_REPO}", ttl=3600)
    return repo["default_branch"]


async def dispatch(dataset_url: str, baseline_tag: str | None) -> None:
    await gh("POST", f"/repos/{settings.GITHUB_REPO}/actions/workflows/{WORKFLOW}/dispatches", json={
        "ref": await default_ref(),
        "inputs": {"dataset_url": dataset_url, "baseline_tag": baseline_tag or "model-v1"},
    })
    _cache.pop(f"GET /repos/{settings.GITHUB_REPO}/actions/workflows/{WORKFLOW}/runs", None)


STEP_TITLES = [
    ("Dala dataseti", "Datasetni yuklab olish"),
    ("PlantVillage", "PlantVillage rasmlari"),
    ("Hozirgi model", "Hozirgi modelni olish"),
    ("O'qitish", "O'qitish va dala testida baholash"),
    ("Yangi versiya", "Nomzod versiyani chiqarish"),
]


async def runs() -> list[dict]:
    data = await gh("GET", f"/repos/{settings.GITHUB_REPO}/actions/workflows/{WORKFLOW}/runs", ttl=20,
                    params={"per_page": 5, "event": "workflow_dispatch"})
    out = []
    for i, r in enumerate((data or {}).get("workflow_runs", [])):
        item = {"id": r["id"], "status": r["status"], "conclusion": r.get("conclusion"), "url": r["html_url"],
                "created_at": r.get("created_at"), "updated_at": r.get("updated_at"), "steps": []}
        if i == 0:  # faqat oxirgisining bosqichlari
            jobs = await gh("GET", f"/repos/{settings.GITHUB_REPO}/actions/runs/{r['id']}/jobs",
                            ttl=20 if r["status"] != "completed" else 3600)
            steps = (jobs or {}).get("jobs", [{}])[0].get("steps", []) if jobs and jobs.get("jobs") else []
            for prefix, title in STEP_TITLES:
                st = next((s for s in steps if s["name"].startswith(prefix)), None)
                item["steps"].append({"title": title, "status": st["status"] if st else "queued",
                                      "conclusion": st.get("conclusion") if st else None})
        out.append(item)
    return out


# ---------- Bir martalik dataset havolasi (GitHub Actions uchun) ----------
async def new_ticket(db: AsyncSession) -> str:
    """3 soatlik, bir martalik havola kaliti. Yangisi eskisini bekor qiladi."""
    t = secrets.token_urlsafe(32)
    value = f"{hashlib.sha256(t.encode()).hexdigest()}:{int((utcnow() + TICKET_TTL).timestamp())}"
    row = await db.get(AppSetting, TICKET_KEY)
    if row is None:
        db.add(AppSetting(key=TICKET_KEY, value=value))
    else:
        row.value = value
    return t


async def use_ticket(db: AsyncSession, t: str) -> bool:
    row = await db.get(AppSetting, TICKET_KEY)
    if row is None:
        return False
    digest, _, exp = row.value.partition(":")
    ok = secrets.compare_digest(digest, hashlib.sha256(t.encode()).hexdigest()) and int(exp or 0) > utcnow().timestamp()
    if ok:
        await db.delete(row)  # bir martalik
        await db.commit()
    return ok


def public_url() -> str:
    if settings.PUBLIC_URL:
        return settings.PUBLIC_URL.rstrip("/")
    origins = [o for o in settings.cors_origins if o.startswith("https://")]
    return origins[0].rstrip("/") if origins else ""
