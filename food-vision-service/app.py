
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pathlib import Path
from ultralytics import YOLO
from PIL import Image, UnidentifiedImageError
from io import BytesIO
from uuid import uuid4

import json
import torch
import torch.nn as nn

from torchvision import models, transforms

app = FastAPI(title="Food Vision API")

# Upload directory
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

# Allowed image formats
ALLOWED_TYPES = {
    "image/jpeg": "JPEG",
    "image/png": "PNG",
    "image/webp": "WEBP"
}

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

# Load YOLO model
model = YOLO("yolo26n.pt")


# Load trained ResNet50 food classification model
BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "models"

CLASS_FILE = MODEL_DIR / "food_classes.json"
WEIGHT_FILE = MODEL_DIR / "best_resnet50_foodvision.pth"

with open(CLASS_FILE, "r", encoding="utf-8") as f:
    food_classes = json.load(f)

DEVICE = torch.device("cpu")

food_model = models.resnet50(weights=None)
food_model.fc = nn.Linear(2048, len(food_classes))

state_dict = torch.load(
    WEIGHT_FILE,
    map_location=DEVICE,
    weights_only=True
)

food_model.load_state_dict(state_dict)
food_model.to(DEVICE)
food_model.eval()

# Image preprocessing used for ResNet50
food_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])

print(f"ResNet50 loaded successfully! Classes: {len(food_classes)}")


@app.get("/")
def home():
    return {
        "message": "Food Vision API is running!"
    }


@app.get("/api/health")
def health():
    return {
        "status": "healthy",
        "service": "Food Vision API"
    }


@app.post("/predict-food")
async def predict_food(file: UploadFile = File(...)):

    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG, and WEBP images are allowed."
        )

    contents = await file.read(MAX_FILE_SIZE + 1)

    if not contents:
        raise HTTPException(
            status_code=400,
            detail="The uploaded file is empty."
        )

    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail="Image must be 5 MB or smaller."
        )

    try:
        image = Image.open(BytesIO(contents))
        image_format = image.format
        image.verify()

        if image_format not in ALLOWED_TYPES.values():
            raise HTTPException(
                status_code=400,
                detail="Unsupported image format."
            )

        image = Image.open(BytesIO(contents)).convert("RGB")

    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="Invalid or corrupted image file."
        )

    try:
        input_tensor = food_transform(image).unsqueeze(0).to(DEVICE)

        with torch.inference_mode():
            outputs = food_model(input_tensor)
            probabilities = torch.softmax(outputs, dim=1)

            top_probabilities, top_indices = torch.topk(
                probabilities, k=3, dim=1
            )

        top_predictions = []

        for probability, index in zip(
            top_probabilities[0], top_indices[0]
        ):
            top_predictions.append({
                "food": food_classes[index.item()],
                "confidence": round(probability.item(), 4)
            })

        return {
            "success": True,
            "model": "ResNet50",
            "predicted_food": top_predictions[0]["food"],
            "confidence": top_predictions[0]["confidence"],
            "top_predictions": top_predictions,
            "requires_user_confirmation": True
        }

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Food classification failed."
        )


@app.post("/upload-image")
async def upload_image(file: UploadFile = File(...)):

    # 1. Check MIME type
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG, and WEBP images are allowed."
        )

    # 2. Read maximum 5 MB + 1 byte
    contents = await file.read(MAX_FILE_SIZE + 1)

    if not contents:
        raise HTTPException(
            status_code=400,
            detail="The uploaded file is empty."
        )

    # 3. Check file size
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail="Image must be 5 MB or smaller."
        )

    # 4. Verify actual image content
    try:
        image = Image.open(BytesIO(contents))
        image_format = image.format
        image.verify()

    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="Invalid or corrupted image file."
        )

    if image_format not in ALLOWED_TYPES.values():
        raise HTTPException(
            status_code=400,
            detail="Unsupported image format."
        )

    # 5. Generate unique filename
    extension = {
        "JPEG": ".jpg",
        "PNG": ".png",
        "WEBP": ".webp"
    }[image_format]

    filename = f"{uuid4().hex}{extension}"
    image_path = UPLOAD_DIR / filename

    # 6. Save image
    image_path.write_bytes(contents)

    # 7. Run YOLO detection
    try:
        results = model.predict(
            source=str(image_path),
            verbose=False
        )

        detections = []

        for box in results[0].boxes:
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])

            detections.append({
                "name": results[0].names[class_id],
                "confidence": round(confidence, 4)
            })

    except Exception:
        # Remove uploaded file if AI processing fails
        image_path.unlink(missing_ok=True)

        raise HTTPException(
            status_code=500,
            detail="Food recognition failed."
        )

    # 8. Return result
    return JSONResponse({
        "success": True,
        "message": "Image uploaded and analyzed successfully!",
        "filename": filename,
        "size_bytes": len(contents),
        "detections": detections
    })
