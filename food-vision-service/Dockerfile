# Food Vision API (Ayşenur): ResNet50 food classifier, POST /predict-food. Only the backend calls it (compose network,
# no port on the host).
#
# The trained weights are NOT in Git (.gitignore: *.pth). Put best_resnet50_foodvision.pth into models/ before
# building; without it the service stops at startup and the backend answers 503 for /api/v1/ai/food.
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# OpenCV (pulled in by ultralytics) needs these system libraries.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# CPU-only PyTorch first: the default wheels bring CUDA libraries (several GB) that a CPU server never uses.
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir -r requirements.txt

# app.py also loads the YOLO model for the older /upload-image endpoint; ultralytics downloads its weights on first
# use. Download them while building, so the container starts without internet access.
RUN python -c "from ultralytics import YOLO; YOLO('yolo26n.pt')"

COPY . .

# Not root inside the container.
RUN useradd --create-home --uid 10001 foodvision && mkdir -p uploads && chown -R foodvision /app
USER foodvision

EXPOSE 8001

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]
