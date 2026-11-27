"""Old model vs new model on real photos whose food we know (not the test set: phone photos, web images).

    python compare_on_photos.py --photos C:/Users/ASUS/Desktop --old models/best_resnet50_foodvision.pth \\
        --new C:/Users/ASUS/Downloads/best_resnet50_foodvision.pth

The answer for each photo comes from LABELS below (file name -> class); photos not listed are skipped. Same
preprocessing as the service (app.py), whole photo only (no YOLO regions).
"""

import argparse
import json
from pathlib import Path

import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms

# File name (lower case) -> the class the model should answer. Foods the model has no class for (lentil soup,
# döner) are left out: no answer could be right.
LABELS = {
    "baklava1.jpeg": "baklava",
    "baklava2.jpeg": "baklava",
    "baklava3.jpeg": "baklava",
    "hamburger.jpeg": "hamburger",
    "lahmacun.jpeg": "lahmacun",
    "lahmacun_images.png": "lahmacun",
    "makarna.jpeg": "spaghetti_bolognese",
    "mantı.jpeg": "manti",
    "pizza-png.webp": "pizza",
    "yaprak sarma.jpeg": "yaprak_sarma",
}

TRANSFORM = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])


def load(path: Path, num_classes: int) -> nn.Module:
    model = models.resnet50(weights=None)
    model.fc = nn.Linear(2048, num_classes)
    model.load_state_dict(torch.load(path, map_location="cpu", weights_only=True))
    return model.eval()


@torch.inference_mode()
def top3(model: nn.Module, image: Image.Image, classes: list[str]) -> list[tuple[str, float]]:
    probabilities = torch.softmax(model(TRANSFORM(image).unsqueeze(0)), dim=1)[0]
    values, indices = probabilities.topk(3)
    return [(classes[i], round(100 * v.item(), 1)) for v, i in zip(values, indices)]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--photos", type=Path, required=True)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--classes", type=Path, default=Path(__file__).resolve().parents[1] / "models" / "food_classes.json")
    args = parser.parse_args()

    classes = json.loads(args.classes.read_text(encoding="utf-8"))
    old, new = load(args.old, len(classes)), load(args.new, len(classes))

    score = {"old top-1": 0, "new top-1": 0, "old top-3": 0, "new top-3": 0}
    photos = [p for p in sorted(args.photos.iterdir()) if p.name.lower() in LABELS]
    print(f"{'photo':22} {'answer':20} {'old model':28} {'new model':28}")
    for photo in photos:
        answer = LABELS[photo.name.lower()]
        image = Image.open(photo).convert("RGB")
        row = []
        for name, model in (("old", old), ("new", new)):
            guesses = top3(model, image, classes)
            score[f"{name} top-1"] += guesses[0][0] == answer
            score[f"{name} top-3"] += answer in [g for g, _ in guesses]
            mark = "OK " if guesses[0][0] == answer else ("~3 " if answer in [g for g, _ in guesses] else "NO ")
            row.append(f"{mark}{guesses[0][0]} {guesses[0][1]}%")
        print(f"{photo.name:22} {answer:20} {row[0]:28} {row[1]:28}")
    print(f"\n{len(photos)} photos | " + " | ".join(f"{k}: {v}" for k, v in score.items()))


if __name__ == "__main__":
    main()
