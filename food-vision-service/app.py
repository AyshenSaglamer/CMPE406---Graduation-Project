"""Food Vision API (Ayşenur): what food is on the plate, and where.

POST /predict-food takes one meal photo and answers in two parts:

- top_predictions: the whole photo classified by ResNet50 (Food-101 + 24 Turkish dishes, 125 classes, 77 % test
  accuracy). One plate, one dish: this is the answer.
- items: several foods on one plate. YOLO finds the food regions (bowl, pizza, sandwich, cake, fruit, ...) and each
  region is cropped and classified by the same ResNet50. Empty when YOLO is not available or finds nothing.

Only the backend calls it (POST /api/v1/ai/food -> FoodVisionClient). The photo is processed in memory and never
written to disk. Every answer is a suggestion: the patient must confirm it before anything is saved.
"""

import json
import logging
import os
import threading
from contextlib import asynccontextmanager
from io import BytesIO
from pathlib import Path

import torch
import torch.nn as nn
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError
from torchvision import models, transforms

log = logging.getLogger("food-vision")

BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = Path(os.getenv("FOOD_VISION_MODEL_DIR", BASE_DIR / "models"))
CLASS_FILE = MODEL_DIR / "food_classes.json"
WEIGHT_FILE = MODEL_DIR / "best_resnet50_foodvision.pth"
# YOLO weights for finding several foods on one plate. Optional: without them items is always empty.
DETECTOR_FILE = Path(os.getenv("FOOD_VISION_DETECTOR", MODEL_DIR / "yolo26n.pt"))
MULTI_FOOD_ENABLED = os.getenv("FOOD_VISION_MULTI_FOOD", "true").lower() == "true"

# Content type -> Pillow format. The declared type is only a first filter; the bytes decide (see read_image).
ALLOWED_TYPES = {
    "image/jpeg": "JPEG",
    "image/png": "PNG",
    "image/webp": "WEBP",
}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB, same as the backend
TOP_K = 3

# Decompression bombs: refuse photos above 50 MP (same limit as the backend) before decoding them.
MAX_PIXELS = 50_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS

# Multi-food detection. COCO classes that are a food or hold one (cups, glasses and the table are left out: they
# would crop drinks or the whole photo).
FOOD_REGION_CLASSES = {
    "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake",
}
DETECTION_MIN_CONFIDENCE = 0.35  # below this YOLO mostly sees things that are not there (an orange on a pizza)
DETECTION_MIN_AREA = 0.03        # a region smaller than 3 % of the photo is too small to classify
DETECTION_MAX_OVERLAP = 0.5      # IoU above which two regions are the same food
MAX_ITEMS = 5
CROP_PADDING = 0.08              # a little context around the region helps the classifier

DEVICE = torch.device("cpu")

food_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

# Filled at startup (lifespan). Tests replace them with small fakes.
food_classes: list[str] = []
food_model: nn.Module | None = None
detector = None  # ultralytics YOLO, or None
# The ultralytics predictor is not thread-safe; FastAPI runs predict_food in a thread pool.
detector_lock = threading.Lock()


def load_model() -> tuple[list[str], nn.Module]:
    with open(CLASS_FILE, "r", encoding="utf-8") as f:
        classes = json.load(f)

    model = models.resnet50(weights=None)
    model.fc = nn.Linear(2048, len(classes))
    model.load_state_dict(torch.load(WEIGHT_FILE, map_location=DEVICE, weights_only=True))
    model.to(DEVICE)
    model.eval()
    return classes, model


def load_detector():
    """YOLO for several foods on one plate, or None (then only the whole photo is classified)."""
    if not MULTI_FOOD_ENABLED:
        return None
    if not DETECTOR_FILE.is_file():
        log.warning("No detector weights at %s: multi-food detection is off", DETECTOR_FILE)
        return None
    try:
        from ultralytics import YOLO

        return YOLO(str(DETECTOR_FILE))
    except Exception:
        log.exception("Detector could not be loaded: multi-food detection is off")
        return None


@asynccontextmanager
async def lifespan(_: FastAPI):
    global food_classes, food_model, detector
    food_classes, food_model = load_model()
    detector = load_detector()
    print(f"ResNet50 loaded successfully! Classes: {len(food_classes)}. "
          f"Multi-food detection: {'on' if detector is not None else 'off'}")
    yield


app = FastAPI(title="Food Vision API", lifespan=lifespan)


@app.get("/")
def home():
    return {"message": "Food Vision API is running!"}


@app.get("/api/health")
def health():
    if food_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded.")
    return {
        "status": "healthy",
        "service": "Food Vision API",
        "classes": len(food_classes),
        "multi_food": detector is not None,
    }


def read_image(file: UploadFile) -> Image.Image:
    """Checks the upload and returns it as an RGB image, or raises 400/413."""
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPG, PNG, and WEBP images are allowed.")

    contents = file.file.read(MAX_FILE_SIZE + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="Image must be 5 MB or smaller.")

    try:
        probe = Image.open(BytesIO(contents))
        image_format = probe.format
        # Pillow only warns between 1x and 2x MAX_IMAGE_PIXELS, so check the header size ourselves before decoding.
        if probe.width * probe.height > MAX_PIXELS:
            raise HTTPException(status_code=400, detail="Image resolution is too large.")
        probe.verify()
        if image_format not in ALLOWED_TYPES.values():
            raise HTTPException(status_code=400, detail="Unsupported image format.")
        return Image.open(BytesIO(contents)).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        raise HTTPException(status_code=400, detail="Invalid or corrupted image file.")


def iou(a: list[float], b: list[float]) -> float:
    """Intersection over union of two [x1, y1, x2, y2] boxes."""
    ix = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = ix * iy
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.0


def select_regions(detections: list[dict], width: int, height: int) -> list[dict]:
    """Keeps the food regions worth classifying: food classes, confident, big enough, not duplicates.

    detections: [{"label": "bowl", "confidence": 0.8, "box": [x1, y1, x2, y2] in pixels}, ...].
    """
    area = float(width * height)
    candidates = sorted(
        (d for d in detections
         if d["label"] in FOOD_REGION_CLASSES
         and d["confidence"] >= DETECTION_MIN_CONFIDENCE
         and (d["box"][2] - d["box"][0]) * (d["box"][3] - d["box"][1]) / area >= DETECTION_MIN_AREA),
        key=lambda d: d["confidence"],
        reverse=True,
    )
    kept: list[dict] = []
    for d in candidates:
        if all(iou(d["box"], k["box"]) <= DETECTION_MAX_OVERLAP for k in kept):
            kept.append(d)
        if len(kept) == MAX_ITEMS:
            break
    return kept


def detect_regions(image: Image.Image) -> list[dict]:
    if detector is None:
        return []
    try:
        with detector_lock:
            result = detector.predict(image, verbose=False, conf=DETECTION_MIN_CONFIDENCE)[0]
        detections = [
            {
                "label": result.names[int(box.cls)],
                "confidence": float(box.conf),
                "box": [float(v) for v in box.xyxy[0].tolist()],
            }
            for box in result.boxes
        ]
    except Exception:
        # The whole-photo answer still works; multi-food is an extra.
        log.exception("Detection failed")
        return []
    return select_regions(detections, image.width, image.height)


def crop(image: Image.Image, box: list[float]) -> Image.Image:
    x1, y1, x2, y2 = box
    pad_x, pad_y = (x2 - x1) * CROP_PADDING, (y2 - y1) * CROP_PADDING
    return image.crop((
        max(0, int(x1 - pad_x)), max(0, int(y1 - pad_y)),
        min(image.width, int(x2 + pad_x)), min(image.height, int(y2 + pad_y)),
    ))


def classify(images: list[Image.Image]) -> list[list[dict]]:
    """Top-3 guesses for each image, in one batch."""
    batch = torch.stack([food_transform(img) for img in images]).to(DEVICE)
    with torch.inference_mode():
        probabilities = torch.softmax(food_model(batch), dim=1)
        top_probabilities, top_indices = torch.topk(probabilities, k=min(TOP_K, len(food_classes)), dim=1)
    return [
        [
            {"food": food_classes[index.item()], "confidence": round(probability.item(), 4)}
            for probability, index in zip(top_probabilities[row], top_indices[row])
        ]
        for row in range(len(images))
    ]


# Plain `def`, not `async def`: FastAPI runs it in a thread pool, so one slow model pass does not block other
# requests (the event loop stays free).
@app.post("/predict-food")
def predict_food(file: UploadFile = File(...)):
    if food_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded.")

    image = read_image(file)
    regions = detect_regions(image)

    try:
        guesses = classify([image] + [crop(image, r["box"]) for r in regions])
    except Exception:
        raise HTTPException(status_code=500, detail="Food classification failed.")

    top_predictions = guesses[0]
    items = [
        {
            # Normalised to 0..1 so the app can draw it on any size of the photo.
            "box": [round(region["box"][0] / image.width, 4), round(region["box"][1] / image.height, 4),
                    round(region["box"][2] / image.width, 4), round(region["box"][3] / image.height, 4)],
            "detector_label": region["label"],
            "detector_confidence": round(region["confidence"], 4),
            "top_predictions": item_guesses,
        }
        for region, item_guesses in zip(regions, guesses[1:])
    ]

    return {
        "success": True,
        "model": "ResNet50",
        "predicted_food": top_predictions[0]["food"],
        "confidence": top_predictions[0]["confidence"],
        "top_predictions": top_predictions,
        "items": items,
        "multiple_foods": len(items) >= 2,
        "requires_user_confirmation": True,
    }
