"""EfficientNet-B0 transfer learning → ONNX eksport.

Dataset tuzilmasi (PlantVillage'dan boshlab, keyin real rasmlar bilan fine-tune):
    data/train/<ai_label>/*.jpg
    data/val/<ai_label>/*.jpg
<ai_label> nomlari app/models/labels.py va backend diseases.ai_label bilan bir xil bo'lishi shart.

Ishga tushirish:
    pip install -r training/requirements.txt
    python training/train.py --data data --epochs 10 --out models/agro.onnx
So'ng AI service'ni MODEL_PATH=models/agro.onnx bilan ishga tushiring.
"""
import argparse
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader
from torchvision import datasets, models, transforms


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data")
    ap.add_argument("--epochs", type=int, default=10)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=3e-4)
    ap.add_argument("--arch", choices=["efficientnet_b0", "mobilenet_v3_large"], default="efficientnet_b0")
    ap.add_argument("--out", default="models/agro.onnx")
    args = ap.parse_args()

    norm = transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    train_tf = transforms.Compose([
        transforms.RandomResizedCrop(224, scale=(0.7, 1.0)), transforms.RandomHorizontalFlip(),
        transforms.ColorJitter(0.3, 0.3, 0.2), transforms.ToTensor(), norm,
    ])
    val_tf = transforms.Compose([transforms.Resize(256), transforms.CenterCrop(224), transforms.ToTensor(), norm])
    train_ds = datasets.ImageFolder(Path(args.data) / "train", train_tf)
    val_ds = datasets.ImageFolder(Path(args.data) / "val", val_tf)
    train_dl = DataLoader(train_ds, batch_size=args.batch, shuffle=True, num_workers=4)
    val_dl = DataLoader(val_ds, batch_size=args.batch, num_workers=4)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    n = len(train_ds.classes)
    if args.arch == "efficientnet_b0":
        model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
        model.classifier[1] = nn.Linear(model.classifier[1].in_features, n)
    else:
        model = models.mobilenet_v3_large(weights=models.MobileNet_V3_Large_Weights.DEFAULT)
        model.classifier[3] = nn.Linear(model.classifier[3].in_features, n)
    model.to(device)

    opt = torch.optim.AdamW(model.parameters(), lr=args.lr)
    sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, args.epochs)
    loss_fn = nn.CrossEntropyLoss(label_smoothing=0.1)
    best = 0.0
    for epoch in range(args.epochs):
        model.train()
        for x, y in train_dl:
            x, y = x.to(device), y.to(device)
            opt.zero_grad()
            loss_fn(model(x), y).backward()
            opt.step()
        sched.step()
        model.eval()
        correct = total = 0
        with torch.no_grad():
            for x, y in val_dl:
                pred = model(x.to(device)).argmax(1).cpu()
                correct += (pred == y).sum().item()
                total += len(y)
        acc = correct / max(1, total)
        print(f"epoch {epoch + 1}: val_acc={acc:.4f}")
        if acc > best:
            best = acc
            torch.save(model.state_dict(), "best.pt")

    model.load_state_dict(torch.load("best.pt", map_location=device))
    model.eval().cpu()
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(model, torch.randn(1, 3, 224, 224), out, input_names=["input"], output_names=["logits"],
                      dynamic_axes={"input": {0: "batch"}, "logits": {0: "batch"}}, opset_version=17)
    out.with_suffix(".labels.txt").write_text("\n".join(train_ds.classes))
    print(f"ONNX saqlandi: {out} (best val_acc={best:.4f})")


if __name__ == "__main__":
    main()
