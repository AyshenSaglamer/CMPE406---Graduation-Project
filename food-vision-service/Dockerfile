# Food Vision API (Ayşenur): ResNet50 food classifier + YOLO food regions, POST /predict-food. Only the backend calls
# it (compose network, no port on the host).
#
# The trained weights are NOT in Git (.gitignore: *.pth). Put best_resnet50_foodvision.pth into models/ before
# building; without it the service stops at startup and the backend answers 503 for /api/v1/ai/food.
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# ultralytics writes its settings here; the home directory of the service user is not needed.
ENV YOLO_CONFIG_DIR=/tmp/Ultralytics
ENV FOOD_VISION_DETECTOR=/opt/yolo/yolo26n.pt

# OpenCV (pulled in by ultralytics) needs these system libraries.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# CPU-only PyTorch first: the default wheels bring CUDA libraries (several GB) that a CPU server never uses.
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir torch==2.13.0 torchvision==0.28.0 --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir -r requirements.txt

# YOLO weights for multi-food detection, downloaded while building so the container starts without internet access.
# Without them the service still works: only the whole photo is classified (items is empty).
RUN mkdir -p /opt/yolo && cd /opt/yolo && python -c "from ultralytics import YOLO; YOLO('yolo26n.pt')"

COPY . .

# Not root inside the container. Photos are processed in memory, nothing is written to disk.
RUN useradd --create-home --uid 10001 foodvision && chown -R foodvision /app
USER foodvision

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/api/health')"

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]
