from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def valid_payload():
    return {
        "records": [
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T08:00:00",
                "glucose_mg_dl": 108,
                "carbs_g": 30,
                "activity_minutes": 10,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-02T09:00:00",
                "glucose_mg_dl": 112,
                "carbs_g": 25,
                "activity_minutes": 20,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-03T14:00:00",
                "glucose_mg_dl": 128,
                "carbs_g": 40,
                "activity_minutes": 15,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-04T15:00:00",
                "glucose_mg_dl": 132,
                "carbs_g": 35,
                "activity_minutes": 25,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-05T19:00:00",
                "glucose_mg_dl": 125,
                "carbs_g": 20,
                "activity_minutes": 30,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-06T20:00:00",
                "glucose_mg_dl": 130,
                "carbs_g": 45,
                "activity_minutes": 10,
            },
        ]
    }


def test_baseline_endpoint_returns_200():
    response = client.post(
        "/api/v1/insights/baseline",
        json=valid_payload(),
    )

    assert response.status_code == 200


def test_baseline_endpoint_patient_id():
    response = client.post(
        "/api/v1/insights/baseline",
        json=valid_payload(),
    )

    data = response.json()

    assert data["patient_id"] == "patient-1"


def test_baseline_endpoint_overall_baseline():
    response = client.post(
        "/api/v1/insights/baseline",
        json=valid_payload(),
    )

    data = response.json()

    baseline = data["overall_baseline"]

    assert baseline["count"] == 6
    assert baseline["mean"] == 122.5
    assert baseline["minimum"] == 108.0
    assert baseline["maximum"] == 132.0


def test_baseline_endpoint_time_of_day():
    response = client.post(
        "/api/v1/insights/baseline",
        json=valid_payload(),
    )

    data = response.json()

    periods = data[
        "time_of_day_baselines"
    ]

    assert periods["MORNING"]["mean"] == 110.0
    assert periods["AFTERNOON"]["mean"] == 130.0
    assert periods["EVENING"]["mean"] == 127.5

    assert (
        periods["NIGHT"]["available"]
        is False
    )


def test_baseline_endpoint_day_types():
    response = client.post(
        "/api/v1/insights/baseline",
        json=valid_payload(),
    )

    data = response.json()

    day_types = data[
        "day_type_baselines"
    ]

    assert (
        day_types["WEEKDAY"]["available"]
        is True
    )

    assert (
        day_types["WEEKEND"]["available"]
        is True
    )


def test_baseline_endpoint_metadata():
    response = client.post(
        "/api/v1/insights/baseline",
        json=valid_payload(),
    )

    data = response.json()

    assert (
        data["scope"]
        == "personalized_historical_pattern"
    )

    assert (
        data["method"]
        == "descriptive_baseline_learning"
    )

    assert (
        data["source"]
        == "patient_history"
    )

    assert (
        data["purpose"]
        == "personalized_baseline_learning"
    )


def test_baseline_endpoint_rejects_too_few_records():
    payload = valid_payload()

    payload["records"] = (
        payload["records"][:4]
    )

    response = client.post(
        "/api/v1/insights/baseline",
        json=payload,
    )

    assert response.status_code == 422

    data = response.json()

    assert data["status"] == "ERROR"
    assert (
        data["error"]["code"]
        == "VALIDATION_ERROR"
    )


def test_baseline_endpoint_rejects_multiple_patients():
    payload = valid_payload()

    payload["records"][0][
        "patient_id"
    ] = "patient-2"

    response = client.post(
        "/api/v1/insights/baseline",
        json=payload,
    )

    assert response.status_code == 422


def test_baseline_endpoint_rejects_invalid_timestamp():
    payload = valid_payload()

    payload["records"][0][
        "timestamp"
    ] = "not-a-real-timestamp"

    response = client.post(
        "/api/v1/insights/baseline",
        json=payload,
    )

    assert response.status_code == 422


def test_baseline_endpoint_contains_safety_disclaimer():
    response = client.post(
        "/api/v1/insights/baseline",
        json=valid_payload(),
    )

    data = response.json()

    disclaimer = data[
        "disclaimer"
    ].lower()

    assert "not medical target ranges" in disclaimer
    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer
    assert "medication" in disclaimer
