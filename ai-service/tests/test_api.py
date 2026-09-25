from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_glucose_api():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "My glucose is 125"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_GLUCOSE"
    assert data["value"] == 125.0
    assert data["unit"] == "mg/dL"
    assert data["status"] == "SUCCESS"


def test_insulin_api():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "I took 6 units of insulin"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_INSULIN"
    assert data["value"] == 6.0
    assert data["status"] == "SUCCESS"


def test_activity_api():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "I walked for 30 minutes"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_ACTIVITY"
    assert data["value"] == 30.0
    assert data["unit"] == "minutes"
    assert data["status"] == "SUCCESS"


def test_missing_text_api():
    response = client.post(
        "/api/v1/nlp/parse",
        json={},
    )

    assert response.status_code == 422
