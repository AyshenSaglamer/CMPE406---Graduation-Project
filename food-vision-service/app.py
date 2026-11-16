
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pathlib import Path
from ultralytics import YOLO
from PIL import Image, UnidentifiedImageError
from io import BytesIO
from uuid import uuid4

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
