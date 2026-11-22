from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def valid_payload():
    return {
        "records": [
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T08:00:00",
                "glucose_mg_dl": 118,
                "carbs_g": 30,
                "activity_minutes": 10,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-02T08:00:00",
                "glucose_mg_dl": 123,
                "carbs_g": 25,
                "activity_minutes": 20,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-03T08:00:00",
                "glucose_mg_dl": 121,
                "carbs_g": 40,
                "activity_minutes": 15,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-04T08:00:00",
                "glucose_mg_dl": 126,
                "carbs_g": 35,
                "activity_minutes": 25,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-05T08:00:00",
                "glucose_mg_dl": 119,
                "carbs_g": 20,
                "activity_minutes": 30,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-06T08:00:00",
                "glucose_mg_dl": 170,
                "carbs_g": 45,
                "activity_minutes": 10,
            },
        ],
        "z_threshold": 2.0,
    }


def test_anomaly_endpoint_returns_200():
    response = client.post(
        "/api/v1/insights/anomaly",
        json=valid_payload(),
    )

    assert response.status_code == 200


def test_anomaly_endpoint_detects_unusual_reading():
    response = client.post(
        "/api/v1/insights/anomaly",
        json=valid_payload(),
    )

    data = response.json()

    assert data["patient_id"] == "patient-1"
    assert data["anomaly"]["is_anomaly"] is True

    assert (
        data["anomaly"]["absolute_z_score"]
        >= data["anomaly"]["threshold"]
    )


def test_anomaly_endpoint_excludes_current_from_baseline():
    response = client.post(
        "/api/v1/insights/anomaly",
        json=valid_payload(),
    )

    data = response.json()

    assert data["history_record_count"] == 6
    assert data["baseline_record_count"] == 5

    assert (
        data["anomaly"]["baseline"]["maximum"]
        == 126.0
    )


def test_anomaly_endpoint_uses_default_threshold():
    payload = valid_payload()

    payload.pop("z_threshold")

    response = client.post(
        "/api/v1/insights/anomaly",
        json=payload,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["anomaly"]["threshold"] == 2.0


def test_anomaly_endpoint_rejects_too_few_records():
    payload = valid_payload()

    payload["records"] = payload["records"][:5]

    response = client.post(
        "/api/v1/insights/anomaly",
        json=payload,
    )

    assert response.status_code == 422

    data = response.json()

    assert data["status"] == "ERROR"
    assert data["error"]["code"] == "VALIDATION_ERROR"


def test_anomaly_endpoint_rejects_invalid_threshold():
    payload = valid_payload()

    payload["z_threshold"] = 0

    response = client.post(
        "/api/v1/insights/anomaly",
        json=payload,
    )

    assert response.status_code == 422

    data = response.json()

    assert data["status"] == "ERROR"
    assert data["error"]["code"] == "VALIDATION_ERROR"


def test_anomaly_endpoint_rejects_multiple_patients():
    payload = valid_payload()

    payload["records"][0]["patient_id"] = "patient-2"

    response = client.post(
        "/api/v1/insights/anomaly",
        json=payload,
    )

    assert response.status_code == 422

    data = response.json()

    assert data["status"] == "ERROR"


def test_anomaly_endpoint_contains_safety_disclaimer():
    response = client.post(
        "/api/v1/insights/anomaly",
        json=valid_payload(),
    )

    data = response.json()

    disclaimer = data["anomaly"]["disclaimer"].lower()

    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer
    assert "medication" in disclaimer
