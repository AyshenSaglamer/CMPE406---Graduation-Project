from unittest.mock import patch

from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


# =========================================================
# ERROR CONTRACT HELPER
# =========================================================

def assert_api_error(
    response,
    *,
    status_code,
    code,
    message,
):
    assert response.status_code == status_code

    body = response.json()

    assert body["status"] == "ERROR"
    assert body["error"]["code"] == code
    assert body["error"]["message"] == message


VALID_HISTORY_REQUEST = {
    "records": [
        {
            "patient_id": "patient_123",
            "timestamp": "2026-10-01T10:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 25,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient_123",
            "timestamp": "2026-10-01T14:00:00",
            "glucose_mg_dl": 145,
            "carbs_g": 40,
            "activity_minutes": 20,
        },
    ]
}


MOCK_HISTORY_PREDICTION = {
    "prediction": "STABLE",
    "probabilities": {
        "HIGHER": 0.0274,
        "LOWER": 0.0674,
        "STABLE": 0.9052,
    },
    "features": {
        "glucose_mg_dl": 145.0,
        "previous_glucose": 120.0,
        "carbs_g": 40.0,
        "activity_minutes": 20.0,
        "hour_of_day": 14.0,
        "day_of_week": 3.0,
        "month": 10.0,
        "is_weekend": 0.0,
    },
    "model_type": "XGBoost",
    "prediction_target": "next_glucose_trend",
    "purpose": (
        "experimental_future_glucose_"
        "trend_classification"
    ),
    "source": "patient_history",
    "history_record_count": 2,
}


# =========================================================
# SUCCESS
# =========================================================

@patch("main.predict_from_patient_history")
def test_history_prediction_success(
    mock_predict,
):
    mock_predict.return_value = (
        MOCK_HISTORY_PREDICTION
    )

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=VALID_HISTORY_REQUEST,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["prediction"] == "STABLE"

    assert (
        data["prediction_target"]
        == "next_glucose_trend"
    )

    assert (
        data["source"]
        == "patient_history"
    )

    assert (
        data["history_record_count"]
        == 2
    )

    assert (
        data["features"]["glucose_mg_dl"]
        == 145.0
    )

    assert (
        data["features"]["previous_glucose"]
        == 120.0
    )

    mock_predict.assert_called_once()


def test_history_request_is_forwarded(
    monkeypatch,
):
    captured_records = {}

    def fake_prediction(records):
        captured_records["records"] = records

        return MOCK_HISTORY_PREDICTION

    monkeypatch.setattr(
        "main.predict_from_patient_history",
        fake_prediction,
    )

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=VALID_HISTORY_REQUEST,
    )

    assert response.status_code == 200

    records = captured_records["records"]

    assert len(records) == 2

    assert (
        records[0]["patient_id"]
        == "patient_123"
    )

    assert (
        records[1]["glucose_mg_dl"]
        == 145
    )


# =========================================================
# REQUEST VALIDATION
# =========================================================

def test_empty_records_rejected():
    response = client.post(
        "/api/v1/ml/predict-from-history",
        json={
            "records": [],
        },
    )

    assert response.status_code == 422


def test_single_record_rejected():
    response = client.post(
        "/api/v1/ml/predict-from-history",
        json={
            "records": [
                VALID_HISTORY_REQUEST[
                    "records"
                ][0]
            ]
        },
    )

    assert response.status_code == 422


def test_missing_records_rejected():
    response = client.post(
        "/api/v1/ml/predict-from-history",
        json={},
    )

    assert response.status_code == 422


def test_malformed_json_rejected():
    response = client.post(
        "/api/v1/ml/predict-from-history",
        content="{invalid-json",
        headers={
            "Content-Type": "application/json",
        },
    )

    assert response.status_code == 422


# =========================================================
# PATIENT VALIDATION
# =========================================================

def test_empty_patient_id_rejected():
    request_data = {
        "records": [
            record.copy()
            for record in VALID_HISTORY_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][0]["patient_id"] = "   "

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=request_data,
    )

    assert response.status_code == 422


@patch("main.predict_from_patient_history")
def test_multiple_patients_returns_422(
    mock_predict,
):
    mock_predict.side_effect = ValueError(
        "Prediction history must contain "
        "exactly one patient."
    )

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=VALID_HISTORY_REQUEST,
    )

    assert_api_error(
        response,
        status_code=422,
        code="INVALID_INPUT",
        message=(
            "Prediction history must contain "
            "exactly one patient."
        ),
    )


# =========================================================
# HEALTH DATA VALIDATION
# =========================================================

def test_zero_glucose_rejected():
    request_data = {
        "records": [
            record.copy()
            for record in VALID_HISTORY_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][1]["glucose_mg_dl"] = 0

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_carbs_rejected():
    request_data = {
        "records": [
            record.copy()
            for record in VALID_HISTORY_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][1]["carbs_g"] = -1

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_activity_rejected():
    request_data = {
        "records": [
            record.copy()
            for record in VALID_HISTORY_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][1]["activity_minutes"] = -1

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=request_data,
    )

    assert response.status_code == 422


# =========================================================
# SERVICE ERRORS
# =========================================================

@patch("main.predict_from_patient_history")
def test_model_unavailable_returns_503(
    mock_predict,
):
    mock_predict.side_effect = FileNotFoundError(
        "Model not found"
    )

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=VALID_HISTORY_REQUEST,
    )

    assert_api_error(
        response,
        status_code=503,
        code="SERVICE_UNAVAILABLE",
        message=(
            "Glucose trend model is not "
            "currently available."
        ),
    )


@patch("main.predict_from_patient_history")
def test_unexpected_error_returns_500(
    mock_predict,
):
    mock_predict.side_effect = RuntimeError(
        "Unexpected failure"
    )

    response = client.post(
        "/api/v1/ml/predict-from-history",
        json=VALID_HISTORY_REQUEST,
    )

    assert_api_error(
        response,
        status_code=500,
        code="INTERNAL_ERROR",
        message=(
            "Patient history prediction failed."
        ),
    )
