"""Tests for the Food Vision API. They do not need the real 95 MB weights: a tiny fake model stands in for ResNet50.

Run from food-vision-service/:  python -m pytest -q
"""

from io import BytesIO

import pytest
import torch
import torch.nn as nn
from fastapi.testclient import TestClient
from PIL import Image

import app as food_app

CLASSES = ["pizza", "hamburger", "lahmacun", "sushi"]


class FakeModel(nn.Module):
    """Always answers hamburger > pizza > lahmacun > sushi, whatever the photo."""

    def forward(self, x):
        logits = torch.tensor([[1.0, 3.0, 0.5, -1.0]])
        return logits.repeat(x.shape[0], 1)


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(food_app, "food_classes", CLASSES)
    monkeypatch.setattr(food_app, "food_model", FakeModel())
    monkeypatch.setattr(food_app, "detector", None)
    # Not used as a context manager, so the lifespan (which loads the real weights) does not run.
    return TestClient(food_app.app)


def image_bytes(fmt="JPEG", size=(64, 64)) -> bytes:
    buffer = BytesIO()
    Image.new("RGB", size, (200, 120, 40)).save(buffer, format=fmt)
    return buffer.getvalue()


def post(client, content: bytes, content_type="image/jpeg", name="meal.jpg"):
    return client.post("/predict-food", files={"file": (name, content, content_type)})


@pytest.mark.parametrize("fmt,content_type", [("JPEG", "image/jpeg"), ("PNG", "image/png"), ("WEBP", "image/webp")])
def test_predicts_top3_in_backend_format(client, fmt, content_type):
    response = post(client, image_bytes(fmt), content_type)

    assert response.status_code == 200
    body = response.json()
    # FastApiFoodResult in the backend reads exactly these fields.
    assert body["success"] is True
    assert body["model"] == "ResNet50"
    assert body["predicted_food"] == "hamburger"
    assert [p["food"] for p in body["top_predictions"]] == ["hamburger", "pizza", "lahmacun"]
    assert body["confidence"] == body["top_predictions"][0]["confidence"]
    assert all(0 <= p["confidence"] <= 1 for p in body["top_predictions"])
    assert body["requires_user_confirmation"] is True
    # No detector: one dish for the whole photo.
    assert body["items"] == []
    assert body["multiple_foods"] is False


def test_rejects_wrong_content_type(client):
    assert post(client, image_bytes(), "application/pdf", "meal.pdf").status_code == 400


def test_rejects_empty_file(client):
    assert post(client, b"").status_code == 400


def test_rejects_corrupted_image(client):
    assert post(client, image_bytes()[:100]).status_code == 400


def test_rejects_file_pretending_to_be_image(client):
    # The declared type and the name say JPEG, the bytes do not: the bytes decide.
    assert post(client, b"%PDF-1.4\n%fake meal photo\n", "image/jpeg", "meal.jpg").status_code == 400
    # A real image, but GIF is not allowed: caught by the format check after Pillow opens it.
    buffer = BytesIO()
    Image.new("RGB", (16, 16)).save(buffer, format="GIF")
    assert post(client, buffer.getvalue(), "image/jpeg", "meal.jpg").status_code == 400


def test_rejects_file_over_5_mb(client):
    too_big = image_bytes() + b"\0" * (5 * 1024 * 1024)
    assert post(client, too_big).status_code == 413


def test_rejects_decompression_bomb(client):
    # A small PNG file that claims ~64 MP: must be refused before it is decoded.
    assert post(client, image_bytes("PNG", (8000, 8000)), "image/png").status_code == 400


def test_does_not_write_photos_to_disk(client, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    post(client, image_bytes())
    assert list(tmp_path.iterdir()) == []


def test_upload_image_endpoint_is_gone(client):
    assert post(client, image_bytes()).status_code == 200
    assert client.post("/upload-image", files={"file": ("a.jpg", image_bytes(), "image/jpeg")}).status_code == 404


def test_health_and_predict_answer_503_without_model(monkeypatch):
    monkeypatch.setattr(food_app, "food_model", None)
    client = TestClient(food_app.app)
    assert client.get("/api/health").status_code == 503
    assert post(client, image_bytes()).status_code == 503


def test_health_when_model_loaded(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["classes"] == len(CLASSES)
    assert response.json()["multi_food"] is False


# --- several foods on one plate -------------------------------------------------------------------------------------

class FakeBox:
    def __init__(self, cls, conf, xyxy):
        self.cls = torch.tensor([cls])
        self.conf = torch.tensor([conf])
        self.xyxy = torch.tensor([xyxy])


class FakeDetector:
    """Mimics ultralytics YOLO.predict for a 200 x 100 photo with two bowls, a table and a tiny orange."""

    names = {45: "bowl", 49: "orange", 60: "dining table"}

    def __init__(self, boxes):
        self.boxes = boxes

    def predict(self, image, verbose=False, conf=0.25):
        class Result:
            pass

        result = Result()
        result.names = self.names
        result.boxes = self.boxes
        return [result]


TWO_BOWLS = [
    FakeBox(45, 0.9, [0, 0, 100, 100]),
    FakeBox(45, 0.8, [100, 0, 200, 100]),
    FakeBox(60, 0.9, [0, 0, 200, 100]),   # the table: not a food region
    FakeBox(49, 0.9, [10, 10, 14, 14]),   # too small
]


def test_finds_each_food_on_a_plate(client, monkeypatch):
    monkeypatch.setattr(food_app, "detector", FakeDetector(TWO_BOWLS))

    body = post(client, image_bytes(size=(200, 100))).json()

    assert body["multiple_foods"] is True
    assert len(body["items"]) == 2
    first, second = body["items"]
    assert first["detector_label"] == "bowl"
    assert first["box"] == [0.0, 0.0, 0.5, 1.0]  # normalised to the photo size
    assert second["box"] == [0.5, 0.0, 1.0, 1.0]
    assert [p["food"] for p in first["top_predictions"]] == ["hamburger", "pizza", "lahmacun"]
    # The whole-photo answer is still there for one-dish plates and older clients.
    assert body["predicted_food"] == "hamburger"


def test_detector_failure_keeps_whole_photo_answer(client, monkeypatch):
    class Broken:
        def predict(self, *args, **kwargs):
            raise RuntimeError("boom")

    monkeypatch.setattr(food_app, "detector", Broken())

    response = post(client, image_bytes())

    assert response.status_code == 200
    assert response.json()["items"] == []


def region(label, conf, box):
    return {"label": label, "confidence": conf, "box": box}


def test_select_regions_drops_duplicates_and_weak_ones():
    kept = food_app.select_regions([
        region("bowl", 0.9, [0, 0, 100, 100]),
        region("bowl", 0.7, [5, 5, 100, 100]),      # same bowl again (IoU > 0.5)
        region("pizza", 0.2, [100, 0, 200, 100]),   # not confident
        region("cup", 0.9, [100, 0, 200, 100]),     # drinks are not food regions
        region("cake", 0.6, [100, 0, 200, 100]),
    ], 200, 100)

    assert [(r["label"], r["confidence"]) for r in kept] == [("bowl", 0.9), ("cake", 0.6)]


def test_select_regions_keeps_at_most_five():
    many = [region("donut", 0.9 - i / 100, [i * 20, 0, i * 20 + 20, 100]) for i in range(8)]
    assert len(food_app.select_regions(many, 160, 100)) == food_app.MAX_ITEMS


def test_crop_adds_padding_inside_the_photo():
    image = Image.new("RGB", (200, 100))
    assert food_app.crop(image, [0, 0, 100, 50]).size == (108, 54)
