"""PlantVillage → MobileNetV3-Large (transfer learning) → ONNX.

Tez va CPU'da ishlaydigan usul: ImageNet'da o'qitilgan backbone muzlatiladi, har bir rasmdan
1280 o'lchamli belgilar (features) bir marta olinadi (augmentatsiyali qo'shimcha ko'rinishlar bilan),
so'ng ustiga chiziqli klassifikator o'qitiladi. Natija bitta ONNX faylga yig'iladi.

    python training/train_plantvillage.py --data /path/PlantVillage-Dataset/raw/color --out models/agro.onnx

Dala dataseti (admin panel → AI va dataset → eksport ZIP). ZIP ichida ikki qism:
  train/<label>/<rasm> — o'qitishga qo'shiladi;
  test/<label>/<rasm>  — "dala rasmlari testi": hech qachon o'qitilmaydi, faqat baholanadi.
Rasm qaysi qismga tushishi tashxis id'siga bog'liq va o'zgarmaydi — test har safar halol bo'ladi.

    python training/train_plantvillage.py --data .../raw/color --extra /path/ds/train --field-test /path/ds/test \
        --baseline-model models/hozirgi.onnx

Dala rasmlari o'qitishda --extra-weight marta takrorlanadi (ular kamroq, lekin haqiqiy sharoitga yaqin),
yangi sinflar (masalan Cucumber_Powdery_mildew) avtomatik qo'shiladi. metrics.json da:
  val_accuracy_onnx            — PlantVillage (+ dala) validatsiyasi;
  field_test_accuracy          — yangi modelning dala rasmlari testidagi aniqligi (asosiy ko'rsatkich);
  baseline_field_test_accuracy — hozir ishlayotgan modelning aynan o'sha rasmlardagi aniqligi.
Yangi model faqat field_test_accuracy baseline'dan past bo'lmasa ishga tushiriladi (admin panel).

GitHub Actions: .github/workflows/train-model.yml (model-vN release'ga yuklaydi).
"""
import argparse
import json
import random
import sys
import time
from pathlib import Path

import torch
from PIL import Image
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.inference.preprocess import to_tensor  # noqa: E402  (servisdagi preprocessing bilan bir xil)
from app.models.labels import PLANTVILLAGE_CLASSES  # noqa: E402

NORM = transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
VAL_TF = transforms.Compose([transforms.Resize(256), transforms.CenterCrop(224), transforms.ToTensor(), NORM])
AUG_TF = transforms.Compose([
    transforms.RandomResizedCrop(224, scale=(0.55, 1.0)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(),
    transforms.RandomRotation(25),
    transforms.ColorJitter(0.35, 0.35, 0.3, 0.04),
    transforms.RandomApply([transforms.GaussianBlur(5, (0.1, 1.5))], p=0.3),
    transforms.ToTensor(),
    NORM,
])


class Images(Dataset):
    def __init__(self, items, tf):
        self.items, self.tf = items, tf

    def __len__(self):
        return len(self.items)

    def __getitem__(self, i):
        path, y = self.items[i]
        return self.tf(Image.open(path).convert("RGB")), y


def build_backbone():
    m = models.mobilenet_v3_large(weights=models.MobileNet_V3_Large_Weights.IMAGENET1K_V2)
    m.classifier = nn.Sequential(*list(m.classifier.children())[:3])  # Linear(960→1280) + Hardswish + Dropout
    return m.eval()


@torch.no_grad()
def extract(backbone, items, tf, batch, workers):
    dl = DataLoader(Images(items, tf), batch_size=batch, num_workers=workers)
    feats, ys = [], []
    for x, y in dl:
        feats.append(backbone(x))
        ys.append(y)
    return torch.cat(feats), torch.cat(ys)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="PlantVillage raw/color papkasi")
    ap.add_argument("--out", default="models/agro.onnx")
    ap.add_argument("--per-class", type=int, default=450, help="har sinfdan maksimal rasm soni")
    ap.add_argument("--val-frac", type=float, default=0.15)
    ap.add_argument("--aug-views", type=int, default=2)
    ap.add_argument("--epochs", type=int, default=120)
    ap.add_argument("--batch", type=int, default=64)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--extra", action="append", default=[], help="dala dataseti papkasi (<label>/<rasm>), bir necha marta berish mumkin")
    ap.add_argument("--extra-weight", type=int, default=3, help="dala rasmlarini o'qitishda necha marta takrorlash")
    ap.add_argument("--field-test", action="append", default=[], help="dala rasmlari testi papkasi (<label>/<rasm>) — o'qitilmaydi")
    ap.add_argument("--baseline-model", help="hozir ishlayotgan model (.onnx, yonida .labels.txt) — dala testida solishtirish uchun")
    ap.add_argument("--min-accuracy", type=float, default=0.85, help="ONNX validatsiya aniqligi shundan past bo'lsa — xato")
    args = ap.parse_args()

    random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.set_num_threads(max(1, torch.get_num_threads()))
    exts = {".jpg", ".jpeg", ".png", ".webp"}
    def folders(roots) -> dict[str, list[Path]]:
        out: dict[str, list[Path]] = {}
        for root in roots:
            for d in sorted(p for p in Path(root).iterdir() if p.is_dir()):
                out.setdefault(d.name, []).extend(sorted(f for f in d.iterdir() if f.suffix.lower() in exts))
        return out

    extra = folders(args.extra)
    field_test = folders(args.field_test)
    labels = sorted(set(PLANTVILLAGE_CLASSES.values()) | set(extra) | set(field_test))
    idx = {lbl: i for i, lbl in enumerate(labels)}

    train, val, field_val = [], [], []
    for label, files in extra.items():
        random.shuffle(files)
        n_val = int(len(files) * args.val_frac) if len(files) >= 10 else 0
        field_val += [(f, idx[label]) for f in files[:n_val]]
        train += [(f, idx[label]) for f in files[n_val:]] * args.extra_weight
        print(f"[dala] {label:27s} train={len(files) - n_val:4d} val={n_val}")
    val += field_val
    for folder, label in PLANTVILLAGE_CLASSES.items():
        files = sorted(p for p in (Path(args.data) / folder).iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png"})
        random.shuffle(files)
        files = files[: args.per_class]
        n_val = max(10, int(len(files) * args.val_frac))
        val += [(f, idx[label]) for f in files[:n_val]]
        train += [(f, idx[label]) for f in files[n_val:]]
        print(f"{label:32s} train={len(files) - n_val:4d} val={n_val}")
    print(f"Jami: {len(labels)} sinf, train={len(train)}, val={len(val)}", flush=True)

    backbone = build_backbone()
    t0 = time.time()
    xs, ys = [], []
    x, y = extract(backbone, train, VAL_TF, args.batch, args.workers)
    xs.append(x)
    ys.append(y)
    for v in range(args.aug_views):
        x, y = extract(backbone, train, AUG_TF, args.batch, args.workers)
        xs.append(x)
        ys.append(y)
        print(f"augmentatsiya ko'rinishi {v + 1}/{args.aug_views} tayyor ({time.time() - t0:.0f}s)", flush=True)
    xtr, ytr = torch.cat(xs), torch.cat(ys)
    xva, yva = extract(backbone, val, VAL_TF, args.batch, args.workers)
    print(f"Belgilar olindi: {xtr.shape} / {xva.shape} ({time.time() - t0:.0f}s)", flush=True)

    counts = torch.bincount(ytr, minlength=len(labels)).float()
    weights = (counts.sum() / (len(labels) * counts)).clamp(max=5)
    head = nn.Linear(xtr.shape[1], len(labels))
    opt = torch.optim.AdamW(head.parameters(), lr=2e-3, weight_decay=1e-4)
    sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, args.epochs)
    loss_fn = nn.CrossEntropyLoss(weight=weights, label_smoothing=0.05)
    best_acc, best_state = 0.0, None
    for epoch in range(args.epochs):
        head.train()
        perm = torch.randperm(len(xtr))
        for i in range(0, len(perm), 256):
            b = perm[i:i + 256]
            opt.zero_grad()
            loss_fn(head(xtr[b]), ytr[b]).backward()
            opt.step()
        sched.step()
        head.eval()
        with torch.no_grad():
            acc = (head(xva).argmax(1) == yva).float().mean().item()
        if acc > best_acc:
            best_acc, best_state = acc, {k: v.clone() for k, v in head.state_dict().items()}
        if (epoch + 1) % 20 == 0:
            print(f"epoch {epoch + 1}: val_acc={acc:.4f} (best {best_acc:.4f})", flush=True)
    head.load_state_dict(best_state)

    # Yagona model: backbone + klassifikator
    model = build_backbone()
    model.classifier.append(head)
    model.eval()
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(model, torch.randn(1, 3, 224, 224), str(out), input_names=["input"], output_names=["logits"],
                      dynamic_axes={"input": {0: "batch"}, "logits": {0: "batch"}}, opset_version=17, dynamo=False)
    out.with_suffix(".labels.txt").write_text("\n".join(labels) + "\n")

    # ONNX'ni servisdagi aynan o'sha preprocessing bilan tekshiramiz
    import onnxruntime as ort

    sess = ort.InferenceSession(str(out), providers=["CPUExecutionProvider"])
    correct = 0
    per_class = {lbl: [0, 0] for lbl in labels}
    for path, yi in val:
        pred = int(sess.run(None, {"input": to_tensor(Image.open(path))})[0][0].argmax())
        correct += pred == yi
        per_class[labels[yi]][0] += pred == yi
        per_class[labels[yi]][1] += 1
    onnx_acc = correct / len(val)
    field_set = {str(f) for f, _ in field_val}
    field_ok = sum(
        int(sess.run(None, {"input": to_tensor(Image.open(p))})[0][0].argmax()) == yi for p, yi in field_val
    ) if field_val else 0

    # Dala rasmlari testi: yangi model va hozirgi (baseline) model aynan bir xil rasmlarda
    test_items = [(f, lbl) for lbl, files in field_test.items() for f in files]
    new_test = evaluate(str(out), labels, test_items)
    base_test = None
    if args.baseline_model and test_items:
        bpath = Path(args.baseline_model)
        blabels = bpath.with_suffix(".labels.txt").read_text().split()
        base_test = evaluate(str(bpath), blabels, test_items)
    metrics = {
        "arch": "mobilenet_v3_large (ImageNet) + linear head",
        "dataset": "PlantVillage (raw/color)",
        "classes": len(labels),
        "train_samples": len(train),
        "val_samples": len(val),
        "val_accuracy_torch": round(best_acc, 4),
        "val_accuracy_onnx": round(onnx_acc, 4),
        "field_train_images": sum(len(v) for v in extra.values()) - len(field_set),
        "field_val_samples": len(field_val),
        "val_accuracy_field": round(field_ok / len(field_val), 4) if field_val else None,
        "field_test_samples": len(test_items),
        "field_test_accuracy": new_test["accuracy"],
        "field_test_per_class": new_test["per_class"],
        "baseline_model": Path(args.baseline_model).name if args.baseline_model else None,
        "baseline_field_test_accuracy": base_test["accuracy"] if base_test else None,
        "baseline_field_test_per_class": base_test["per_class"] if base_test else None,
        "per_class_accuracy": {k: round(c / t, 4) for k, (c, t) in per_class.items()},
    }
    out.with_suffix(".metrics.json").write_text(json.dumps(metrics, indent=2, ensure_ascii=False))
    print(json.dumps(metrics, indent=2, ensure_ascii=False))
    if onnx_acc < args.min_accuracy:
        sys.exit(f"ONNX aniqligi juda past: {onnx_acc:.3f}")


def evaluate(model_path: str, labels: list[str], items: list[tuple[Path, str]]) -> dict:
    """ONNX modelni servisdagi preprocessing bilan baholaydi. Model bilmaydigan sinf — xato hisoblanadi (halol)."""
    if not items:
        return {"accuracy": None, "per_class": {}}
    import onnxruntime as ort

    sess = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
    ok, per = 0, {}
    for path, lbl in items:
        pred = labels[int(sess.run(None, {"input": to_tensor(Image.open(path))})[0][0].argmax())]
        hit = pred == lbl
        ok += hit
        c = per.setdefault(lbl, [0, 0])
        c[0] += hit
        c[1] += 1
    return {"accuracy": round(ok / len(items), 4), "per_class": {k: {"correct": c, "total": t} for k, (c, t) in per.items()}}


if __name__ == "__main__":
    main()
