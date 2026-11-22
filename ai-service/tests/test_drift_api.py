from unittest.mock import patch

from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


# ============================================================
# HELPERS
# ============================================================


def make_record(
    day,
    glucose,
    *,
    patient_id="patient-1",
    month=9,
):
    return {
        "patient_id": patient_id,
        "timestamp": (
            f"2026-{month:02d}-{day:02d}T10:00:00"
        ),
        "glucose_mg_dl": glucose,
        "carbs_g": 30.0,
        "activity_minutes": 20.0,
    }


def valid_payload():
    return {
        "reference_records": [
            make_record(1, 110),
            make_record(2, 115),
            make_record(3, 120),
            make_record(4, 125),
            make_record(5, 130),
            make_record(6, 122),
        ],
        "current_records": [
            make_record(
                1,
                170,
                month=10,
            ),
            make_record(
                2,
                180,
                month=10,
            ),
            make_record(
                3,
                190,
                month=10,
            ),
            make_record(
                4,
                200,
                month=10,
            ),
        ],
        "mean_shift_threshold": 1.0,
    }


MOCK_DRIFT_RESULT = {
    "patient_id": "patient-1",
    "drift_detected": True,
    "status": "DRIFT_DETECTED",
    "drifted_features": [
        "glucose_mg_dl",
    ],
    "drifted_feature_count": 1,
    "feature_count": 8,
    "reference_record_count": 5,
    "current_record_count": 3,
    "mean_shift_threshold": 1.0,
    "features": {
        "glucose_mg_dl": {
            "reference_mean": 122.4,
            "current_mean": 190.0,
            "reference_std": 5.0,
            "absolute_mean_difference": 67.6,
            "standardized_mean_shift": 13.52,
            "drift_detected": True,
        }
    },
    "method": "standardized_mean_shift",
    "scope": "model_input_data_drift",
    "disclaimer": (
        "Model-input drift describes changes in "
        "the statistical distribution of data "
        "presented to the machine-learning system. "
        "It does not represent diagnosis, clinical "
        "deterioration, medical risk, treatment "
        "advice, or evidence that an individual "
        "prediction is incorrect."
    ),
    "source": "patient_history",
    "purpose": "model_input_drift_monitoring",
}


# ============================================================
# SUCCESS
# ============================================================


@patch("main.analyze_model_drift")
def test_drift_endpoint_returns_200(
    mock_analyze,
):
    mock_analyze.return_value = (
        MOCK_DRIFT_RESULT
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=valid_payload(),
    )

    assert response.status_code == 200


@patch("main.analyze_model_drift")
def test_drift_endpoint_returns_result(
    mock_analyze,
):
    mock_analyze.return_value = (
        MOCK_DRIFT_RESULT
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=valid_payload(),
    )

    body = response.json()

    assert (
        body["patient_id"]
        == "patient-1"
    )

    assert (
        body["drift_detected"]
        is True
    )

    assert (
        body["status"]
        == "DRIFT_DETECTED"
    )

    assert (
        "glucose_mg_dl"
        in body["drifted_features"]
    )


@patch("main.analyze_model_drift")
def test_drift_endpoint_passes_records(
    mock_analyze,
):
    mock_analyze.return_value = (
        MOCK_DRIFT_RESULT
    )

    payload = valid_payload()

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 200

    mock_analyze.assert_called_once()

    kwargs = (
        mock_analyze.call_args.kwargs
    )

    assert (
        len(
            kwargs[
                "reference_records"
            ]
        )
        == 6
    )

    assert (
        len(
            kwargs[
                "current_records"
            ]
        )
        == 4
    )

    assert (
        kwargs[
            "mean_shift_threshold"
        ]
        == 1.0
    )


@patch("main.analyze_model_drift")
def test_custom_threshold_is_passed(
    mock_analyze,
):
    mock_analyze.return_value = (
        MOCK_DRIFT_RESULT
    )

    payload = valid_payload()

    payload[
        "mean_shift_threshold"
    ] = 2.0

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 200

    kwargs = (
        mock_analyze.call_args.kwargs
    )

    assert (
        kwargs[
            "mean_shift_threshold"
        ]
        == 2.0
    )


# ============================================================
# SCHEMA VALIDATION
# ============================================================


def test_too_few_reference_records_returns_422():
    payload = valid_payload()

    payload["reference_records"] = (
        payload[
            "reference_records"
        ][:5]
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 422


def test_too_few_current_records_returns_422():
    payload = valid_payload()

    payload["current_records"] = (
        payload[
            "current_records"
        ][:3]
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 422


def test_negative_threshold_returns_422():
    payload = valid_payload()

    payload[
        "mean_shift_threshold"
    ] = -1.0

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 422


def test_zero_threshold_returns_422():
    payload = valid_payload()

    payload[
        "mean_shift_threshold"
    ] = 0.0

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 422


def test_missing_reference_records_returns_422():
    payload = valid_payload()

    payload.pop(
        "reference_records"
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 422


def test_missing_current_records_returns_422():
    payload = valid_payload()

    payload.pop(
        "current_records"
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=payload,
    )

    assert response.status_code == 422


# ============================================================
# SERVICE ERRORS
# ============================================================


@patch("main.analyze_model_drift")
def test_different_patient_error_returns_422(
    mock_analyze,
):
    mock_analyze.side_effect = ValueError(
        "Reference and current patient histories "
        "must belong to the same patient."
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=valid_payload(),
    )

    assert response.status_code == 422

    body = response.json()

    assert body["status"] == "ERROR"

    assert (
        body["error"]["code"]
        == "INVALID_INPUT"
    )

    assert (
        "same patient"
        in body["error"]["message"]
    )


@patch("main.analyze_model_drift")
def test_unexpected_error_returns_500(
    mock_analyze,
):
    mock_analyze.side_effect = (
        RuntimeError(
            "Unexpected failure"
        )
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=valid_payload(),
    )

    assert response.status_code == 500

    body = response.json()

    assert body["status"] == "ERROR"

    assert (
        body["error"]["code"]
        == "INTERNAL_ERROR"
    )

    assert (
        body["error"]["message"]
        == "Model-input drift analysis failed."
    )


# ============================================================
# METADATA / SAFETY
# ============================================================


@patch("main.analyze_model_drift")
def test_drift_metadata_is_returned(
    mock_analyze,
):
    mock_analyze.return_value = (
        MOCK_DRIFT_RESULT
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=valid_payload(),
    )

    body = response.json()

    assert (
        body["method"]
        == "standardized_mean_shift"
    )

    assert (
        body["scope"]
        == "model_input_data_drift"
    )

    assert (
        body["source"]
        == "patient_history"
    )

    assert (
        body["purpose"]
        == "model_input_drift_monitoring"
    )


@patch("main.analyze_model_drift")
def test_drift_safety_disclaimer(
    mock_analyze,
):
    mock_analyze.return_value = (
        MOCK_DRIFT_RESULT
    )

    response = client.post(
        "/api/v1/ml/drift",
        json=valid_payload(),
    )

    disclaimer = (
        response.json()[
            "disclaimer"
        ].lower()
    )

    assert "diagnosis" in disclaimer

    assert (
        "clinical deterioration"
        in disclaimer
    )

    assert "treatment" in disclaimer
