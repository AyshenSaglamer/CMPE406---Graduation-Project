"""Food Vision API (Ayşenur): ResNet50 food classifier, POST /predict-food.

Only the backend calls it (POST /api/v1/ai/food -> FoodVisionClient). The photo is classified in memory and never
written to disk. The answer is a suggestion: the patient must confirm it before anything is saved.
"""

import json
import os
from contextlib import asynccontextmanager
from io import BytesIO
from pathlib import Path

import torch
import torch.nn as nn
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError
from torchvision import models, transforms

BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = Path(os.getenv("FOOD_VISION_MODEL_DIR", BASE_DIR / "models"))
CLASS_FILE = MODEL_DIR / "food_classes.json"
WEIGHT_FILE = MODEL_DIR / "best_resnet50_foodvision.pth"

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

DEVICE = torch.device("cpu")

food_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

# Filled at startup (lifespan). Tests replace them with a small fake model.
food_classes: list[str] = []
food_model: nn.Module | None = None


def load_model() -> tuple[list[str], nn.Module]:
    with open(CLASS_FILE, "r", encoding="utf-8") as f:
        classes = json.load(f)

    model = models.resnet50(weights=None)
    model.fc = nn.Linear(2048, len(classes))
    model.load_state_dict(torch.load(WEIGHT_FILE, map_location=DEVICE, weights_only=True))
    model.to(DEVICE)
    model.eval()
    return classes, model


@asynccontextmanager
async def lifespan(_: FastAPI):
    global food_classes, food_model
    food_classes, food_model = load_model()
    print(f"ResNet50 loaded successfully! Classes: {len(food_classes)}")
    yield


app = FastAPI(title="Food Vision API", lifespan=lifespan)


@app.get("/")
def home():
    return {"message": "Food Vision API is running!"}


@app.get("/api/health")
def health():
    ready = food_model is not None
    if not ready:
        raise HTTPException(status_code=503, detail="Model not loaded.")
    return {"status": "healthy", "service": "Food Vision API", "classes": len(food_classes)}


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


# Plain `def`, not `async def`: FastAPI runs it in a thread pool, so one slow ResNet50 pass does not block
# other requests (the event loop stays free).
@app.post("/predict-food")
def predict_food(file: UploadFile = File(...)):
    if food_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded.")

    image = read_image(file)

    try:
        input_tensor = food_transform(image).unsqueeze(0).to(DEVICE)
        with torch.inference_mode():
            probabilities = torch.softmax(food_model(input_tensor), dim=1)
            top_probabilities, top_indices = torch.topk(probabilities, k=min(TOP_K, len(food_classes)), dim=1)
    except Exception:
        raise HTTPException(status_code=500, detail="Food classification failed.")

    top_predictions = [
        {"food": food_classes[index.item()], "confidence": round(probability.item(), 4)}
        for probability, index in zip(top_probabilities[0], top_indices[0])
    ]

    return {
        "success": True,
        "model": "ResNet50",
        "predicted_food": top_predictions[0]["food"],
        "confidence": top_predictions[0]["confidence"],
        "top_predictions": top_predictions,
        "requires_user_confirmation": True,
    }
