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
    message=None,
):
    assert response.status_code == status_code

    body = response.json()

    assert body["status"] == "ERROR"
    assert body["error"]["code"] == code

    if message is not None:
        assert body["error"]["message"] == message

    return body


VALID_REQUEST = {
    "glucose_mg_dl": 135,
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
        "glucose_mg_dl": 135.0,
        "previous_glucose": 120.0,
        "carbs_g": 40.0,
        "activity_minutes": 30.0,
        "hour_of_day": 14.0,
        "day_of_week": 2.0,
        "month": 9.0,
        "is_weekend": 0.0,
    },
    "model_type": "XGBoost",
    "prediction_target": "next_glucose_trend",
    "purpose": (
        "experimental_future_glucose_"
        "trend_classification"
    ),
}


# =========================================================
# SUCCESS
# =========================================================

@patch("main.predict_with_saved_model")
def test_predict_trend_success(
    mock_predict,
):
    mock_predict.return_value = (
        MOCK_PREDICTION
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=VALID_REQUEST,
    )

    assert response.status_code == 200

    body = response.json()

    assert body["prediction"] == "HIGHER"

    assert (
        body["model_type"]
        == "XGBoost"
    )

    assert (
        body["prediction_target"]
        == "next_glucose_trend"
    )

    assert body["probabilities"] == {
        "HIGHER": 0.70,
        "LOWER": 0.10,
        "STABLE": 0.20,
    }

    mock_predict.assert_called_once()

    sent_features = (
        mock_predict.call_args.args[0]
    )

    assert (
        sent_features["glucose_mg_dl"]
        == 135
    )

    assert (
        sent_features["previous_glucose"]
        == 120
    )


# =========================================================
# MODEL / PREDICTION ERRORS
# =========================================================

@patch("main.predict_with_saved_model")
def test_model_unavailable_returns_503(
    mock_predict,
):
    mock_predict.side_effect = (
        FileNotFoundError(
            "Model file not found"
        )
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=VALID_REQUEST,
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


@patch("main.predict_with_saved_model")
def test_prediction_validation_error_returns_422(
    mock_predict,
):
    mock_predict.side_effect = ValueError(
        "Invalid prediction input"
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=VALID_REQUEST,
    )

    body = assert_api_error(
        response,
        status_code=422,
        code="INVALID_INPUT",
    )

    assert (
        "Invalid prediction input"
        in body["error"]["message"]
    )


@patch("main.predict_with_saved_model")
def test_unexpected_prediction_error_returns_500(
    mock_predict,
):
    mock_predict.side_effect = RuntimeError(
        "Unexpected failure"
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=VALID_REQUEST,
    )

    assert_api_error(
        response,
        status_code=500,
        code="INTERNAL_ERROR",
        message=(
            "Glucose trend prediction failed."
        ),
    )


# =========================================================
# REQUIRED FIELDS
# =========================================================

def test_missing_current_glucose_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data.pop(
        "glucose_mg_dl"
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_missing_previous_glucose_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data.pop(
        "previous_glucose"
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_empty_json_returns_422():
    response = client.post(
        "/api/v1/ml/predict-trend",
        json={},
    )

    assert response.status_code == 422


def test_malformed_json_returns_422():
    response = client.post(
        "/api/v1/ml/predict-trend",
        content="{invalid-json",
        headers={
            "Content-Type": "application/json"
        },
    )

    assert response.status_code == 422


# =========================================================
# GLUCOSE VALIDATION
# =========================================================

def test_zero_current_glucose_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data[
        "glucose_mg_dl"
    ] = 0

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_current_glucose_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data[
        "glucose_mg_dl"
    ] = -10

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_zero_previous_glucose_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data[
        "previous_glucose"
    ] = 0

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


# =========================================================
# CARBS / ACTIVITY VALIDATION
# =========================================================

def test_negative_carbs_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data["carbs_g"] = -1

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_activity_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data[
        "activity_minutes"
    ] = -1

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


# =========================================================
# TIME FEATURE VALIDATION
# =========================================================

def test_invalid_hour_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data["hour_of_day"] = 24

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_invalid_day_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data["day_of_week"] = 7

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_invalid_month_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data["month"] = 13

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_invalid_weekend_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data["is_weekend"] = 2

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


# =========================================================
# TYPE VALIDATION
# =========================================================

def test_non_numeric_current_glucose_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data[
        "glucose_mg_dl"
    ] = "hello"

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


def test_non_numeric_carbs_returns_422():
    request_data = VALID_REQUEST.copy()

    request_data["carbs_g"] = "hello"

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=request_data,
    )

    assert response.status_code == 422


# =========================================================
# FUTURE-DATA LEAKAGE PROTECTION
# =========================================================

@patch("main.predict_with_saved_model")
def test_future_fields_are_not_required(
    mock_predict,
):
    mock_predict.return_value = (
        MOCK_PREDICTION
    )

    response = client.post(
        "/api/v1/ml/predict-trend",
        json=VALID_REQUEST,
    )

    assert response.status_code == 200

    sent_features = (
        mock_predict.call_args.args[0]
    )

    assert (
        "next_glucose"
        not in sent_features
    )

    assert (
        "future_glucose_change"
        not in sent_features
    )

    assert (
        "trend_target"
        not in sent_features
    )
