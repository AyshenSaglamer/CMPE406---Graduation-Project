from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def valid_payload():
    return {
        "records": [
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T08:00:00",
                "glucose_mg_dl": 110.0,
                "carbs_g": 30.0,
                "activity_minutes": 10.0,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T12:00:00",
                "glucose_mg_dl": 125.0,
                "carbs_g": 40.0,
                "activity_minutes": 20.0,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T18:00:00",
                "glucose_mg_dl": 118.0,
                "carbs_g": 25.0,
                "activity_minutes": 30.0,
            },
        ],
        "large_gap_hours": 24.0,
    }


def test_data_quality_endpoint_returns_200():
    response = client.post(
        "/api/v1/insights/data-quality",
        json=valid_payload(),
    )

    assert response.status_code == 200


def test_data_quality_endpoint_returns_patient():
    response = client.post(
        "/api/v1/insights/data-quality",
        json=valid_payload(),
    )

    data = response.json()

    assert data["patient_id"] == "patient-1"


def test_clean_history_returns_good_quality():
    response = client.post(
        "/api/v1/insights/data-quality",
        json=valid_payload(),
    )

    data = response.json()

    assert data["quality_status"] == "GOOD"
    assert data["issues"] == []
    assert data["record_count"] == 3


def test_large_gap_is_detected():
    payload = valid_payload()

    payload["records"][2]["timestamp"] = (
        "2026-10-04T18:00:00"
    )

    response = client.post(
        "/api/v1/insights/data-quality",
        json=payload,
    )

    assert response.status_code == 200

    data = response.json()

    assert (
        "LARGE_LOGGING_GAPS"
        in data["issues"]
    )

    assert (
        data["time_gaps"]["large_gap_count"]
        >= 1
    )


def test_custom_gap_threshold_is_used():
    payload = valid_payload()

    payload["large_gap_hours"] = 2.0

    response = client.post(
        "/api/v1/insights/data-quality",
        json=payload,
    )

    assert response.status_code == 200

    data = response.json()

    assert (
        data["time_gaps"][
            "large_gap_threshold_hours"
        ]
        == 2.0
    )


def test_multiple_patients_are_rejected():
    payload = valid_payload()

    payload["records"][1]["patient_id"] = (
        "patient-2"
    )

    response = client.post(
        "/api/v1/insights/data-quality",
        json=payload,
    )

    assert response.status_code == 422


def test_invalid_gap_threshold_is_rejected():
    payload = valid_payload()

    payload["large_gap_hours"] = -1

    response = client.post(
        "/api/v1/insights/data-quality",
        json=payload,
    )

    assert response.status_code == 422

    data = response.json()

    assert data["status"] == "ERROR"

    assert (
        data["error"]["code"]
        == "VALIDATION_ERROR"
    )


def test_metadata_is_returned():
    response = client.post(
        "/api/v1/insights/data-quality",
        json=valid_payload(),
    )

    data = response.json()

    assert (
        data["source"]
        == "patient_history"
    )

    assert (
        data["purpose"]
        == "data_quality_analysis"
    )

    assert (
        data["method"]
        == "deterministic_quality_checks"
    )


def test_safety_disclaimer_is_returned():
    response = client.post(
        "/api/v1/insights/data-quality",
        json=valid_payload(),
    )

    data = response.json()

    disclaimer = data["disclaimer"].lower()

    assert "data quality" in disclaimer
    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer
