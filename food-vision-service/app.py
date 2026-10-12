
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pathlib import Path

app = FastAPI(title="Food Vision API")

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


@app.get("/")
def home():
    return {
        "message": "Food Vision API is running!"
    }


@app.post("/upload-image")
async def upload_image(file: UploadFile = File(...)):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG, and WEBP images are allowed."
        )

    contents = await file.read()

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

    extension = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp"
    }[file.content_type]

    image_path = UPLOAD_DIR / f"uploaded_image{extension}"
    image_path.write_bytes(contents)

    return JSONResponse({
        "message": "Image uploaded successfully!",
        "filename": image_path.name,
        "size_bytes": len(contents),
        "food_recognition": "Not implemented yet"
    })
