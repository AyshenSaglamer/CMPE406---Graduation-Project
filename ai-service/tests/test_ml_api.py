from unittest.mock import patch

from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


VALID_REQUEST = {
    "previous_glucose": 120,
    "carbs_g": 40,
    "activity_minutes": 30,
    "hour_of_day": 14,
    "day_of_week": 2,
    "month": 9,
    "is_weekend": 0,
}


MOCK_PREDICTION = {
    "prediction": "HIGHER",
    "probabilities": {
        "HIGHER": 0.70,
        "LOWER": 0.10,
        "STABLE": 0.20,
    },
    "features": {
        "previous_glucose": 120.0,
        "carbs_g": 40.0,
        "activity_minutes": 30.0,
        "hour_of_day": 14.0,
        "day_of_week": 2.0,
        "month": 9.0,
        "is_weekend": 0.0,
    },
    "model_type": "XGBoost",
    "purpose": (
        "experimental_glucose_trend_classification"
    ),
}


# =========================================================
# SUCCESSFUL PREDICTION
# =========================================================

def test_predict_trend_success():
    with patch(
        "main.predict_with_saved_model",
        return_value=MOCK_PREDICTION,
    ):
        response = client.post(
            "/api/v1/ml/predict-trend",
            json=VALID_REQUEST,
        )

    assert response.status_code == 200

    data = response.json()

    assert data["prediction"] == "HIGHER"

    assert data["model_type"] == "XGBoost"

    assert data["probabilities"] == {
        "HIGHER": 0.70,
        "LOWER": 0.10,
        "STABLE": 0.20,
    }


# =========================================================
# MODEL UNAVAILABLE
# =========================================================

def test_predict_trend_model_unavailable():
    with patch(
        "main.predict_with_saved_model",
        side_effect=FileNotFoundError(
            "Model file not found"
        ),
    ):
        response = client.post(
            "/api/v1/ml/predict-trend",
            json=VALID_REQUEST,
        )

    assert response.status_code == 503

    assert response.json() == {
        "detail": (
            "Glucose trend model is not "
            "currently available."
        )
    }


# =========================================================
# INTERNAL PREDICTION VALIDATION
# =========================================================

def test_predict_trend_value_error():
    with patch(
        "main.predict_with_saved_model",
        side_effect=ValueError(
            "Invalid prediction features."
        ),
    ):
        response = client.post(
            "/api/v1/ml/predict-trend",
            json=VALID_REQUEST,
        )

    assert response.status_code == 422

    assert response.json() == {
        "detail": "Invalid prediction features."
    }


# =========================================================
# UNEXPECTED ERROR
# =========================================================

def test_predict_trend_unexpected_error():
    with patch(
        "main.predict_with_saved_model",
        side_effect=RuntimeError(
            "Unexpected test error"
        ),
    ):
        response = client.post(
            "/api/v1/ml/predict-trend",
            json=VALID_REQUEST,
        )

    assert response.status_code == 500

    assert response.json() == {
        "detail": (
            "Glucose trend prediction failed."
        )
    }


# =========================================================
# PYDANTIC INPUT VALIDATION
# =========================================================

def test_missing_previous_glucose():
    request_data = VALID_REQUEST.copy()

    request_data.pop(
        "previous_glucose"
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_zero_previous_glucose():
    request_data = VALID_REQUEST.copy()

    request_data[
        "previous_glucose"
    ] = 0

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_carbs():
    request_data = VALID_REQUEST.copy()

    request_data["carbs_g"] = -1

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_activity():
    request_data = VALID_REQUEST.copy()

    request_data[
        "activity_minutes"
    ] = -1

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_invalid_hour():
    request_data = VALID_REQUEST.copy()

    request_data["hour_of_day"] = 24

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_invalid_day_of_week():
    request_data = VALID_REQUEST.copy()

    request_data["day_of_week"] = 7

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_invalid_month():
    request_data = VALID_REQUEST.copy()

    request_data["month"] = 13

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_invalid_weekend():
    request_data = VALID_REQUEST.copy()

    request_data["is_weekend"] = 2

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


# =========================================================
# MALFORMED / EMPTY REQUESTS
# =========================================================

def test_empty_request():
    response = client.post(
        "/api/v1/ml/predict-trend",
        json={},
    )

    assert response.status_code == 422


def test_malformed_json():
    response = client.post(
        "/api/v1/ml/predict-trend",
        content="{bad json",
        headers={
            "Content-Type": "application/json"
        },
    )

    assert response.status_code == 422
