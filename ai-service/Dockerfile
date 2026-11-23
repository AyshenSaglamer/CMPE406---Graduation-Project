FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

# Build the deterministic synthetic XGBoost model used by
# DiaMate's development/demo prediction pipeline.
#
# This model is for software demonstration only.
# It is not clinically validated and must not be used for
# diagnosis, treatment, medication decisions, or dosing.
RUN python scripts/train_demo_model.py

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
