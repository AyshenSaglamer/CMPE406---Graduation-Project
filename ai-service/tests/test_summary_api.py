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


VALID_REQUEST = {
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
    ],
    "range_low": 70,
    "range_high": 180,
}


MOCK_SUMMARY = {
    "status": "SUCCESS",
    "patient_id": "patient_123",
    "record_count": 2,
    "configured_range": {
        "low_mg_dl": 70.0,
        "high_mg_dl": 180.0,
    },
    "analytics": {
        "glucose_statistics": {
            "count": 2,
            "mean": 132.5,
            "minimum": 120.0,
            "maximum": 145.0,
            "standard_deviation": 12.5,
        },
        "time_in_range": {
            "total_readings": 2,
            "below_range_count": 0,
            "in_range_count": 2,
            "above_range_count": 0,
            "below_range_percentage": 0.0,
            "time_in_range_percentage": 100.0,
            "above_range_percentage": 0.0,
            "lower_bound": 70.0,
            "upper_bound": 180.0,
        },
    },
    "ml_prediction": {
        "status": "AVAILABLE",
        "result": {
            "prediction": "STABLE",
        },
    },
    "insight_summary": {
        "status": "SUCCESS",
        "insight_count": 5,
        "insights": [
            "Example insight."
        ],
    },
    "purpose": (
        "diabetes_self_management_support"
    ),
    "disclaimer": (
        "This summary describes patterns "
        "in logged data and does not provide "
        "medical diagnosis, treatment, or "
        "medication dosing advice."
    ),
}


# =========================================================
# SUCCESS
# =========================================================

@patch("main.build_patient_summary")
def test_summary_endpoint_success(
    mock_summary,
):
    mock_summary.return_value = MOCK_SUMMARY

    response = client.post(
        "/api/v1/insights/summary",
        json=VALID_REQUEST,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"

    assert (
        data["patient_id"]
        == "patient_123"
    )

    assert data["record_count"] == 2

    assert (
        data["ml_prediction"]["status"]
        == "AVAILABLE"
    )

    assert (
        data["insight_summary"]["status"]
        == "SUCCESS"
    )


# =========================================================
# REQUEST FORWARDING
# =========================================================

@patch("main.build_patient_summary")
def test_summary_forwards_records_and_range(
    mock_summary,
):
    mock_summary.return_value = MOCK_SUMMARY

    response = client.post(
        "/api/v1/insights/summary",
        json=VALID_REQUEST,
    )

    assert response.status_code == 200

    mock_summary.assert_called_once()

    call = mock_summary.call_args

    records = call.kwargs["records"]

    assert len(records) == 2

    assert (
        records[0]["patient_id"]
        == "patient_123"
    )

    assert (
        records[1]["glucose_mg_dl"]
        == 145
    )

    assert (
        call.kwargs["range_low"]
        == 70
    )

    assert (
        call.kwargs["range_high"]
        == 180
    )


# =========================================================
# DEFAULT RANGE
# =========================================================

@patch("main.build_patient_summary")
def test_default_range(
    mock_summary,
):
    mock_summary.return_value = MOCK_SUMMARY

    request_data = {
        "records": VALID_REQUEST["records"]
    }

    response = client.post(
        "/api/v1/insights/summary",
        json=request_data,
    )

    assert response.status_code == 200

    call = mock_summary.call_args

    assert (
        call.kwargs["range_low"]
        == 70.0
    )

    assert (
        call.kwargs["range_high"]
        == 180.0
    )


# =========================================================
# REQUEST VALIDATION
# =========================================================

def test_empty_records_rejected():
    response = client.post(
        "/api/v1/insights/summary",
        json={
            "records": [],
        },
    )

    assert response.status_code == 422


def test_missing_records_rejected():
    response = client.post(
        "/api/v1/insights/summary",
        json={
            "range_low": 70,
            "range_high": 180,
        },
    )

    assert response.status_code == 422


def test_zero_glucose_rejected():
    request_data = {
        "records": [
            {
                **record
            }
            for record in VALID_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][0]["glucose_mg_dl"] = 0

    response = client.post(
        "/api/v1/insights/summary",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_carbs_rejected():
    request_data = {
        "records": [
            {
                **record
            }
            for record in VALID_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][0]["carbs_g"] = -1

    response = client.post(
        "/api/v1/insights/summary",
        json=request_data,
    )

    assert response.status_code == 422


def test_negative_activity_rejected():
    request_data = {
        "records": [
            {
                **record
            }
            for record in VALID_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][0]["activity_minutes"] = -1

    response = client.post(
        "/api/v1/insights/summary",
        json=request_data,
    )

    assert response.status_code == 422


def test_whitespace_patient_id_rejected():
    request_data = {
        "records": [
            {
                **record
            }
            for record in VALID_REQUEST[
                "records"
            ]
        ]
    }

    request_data[
        "records"
    ][0]["patient_id"] = "   "

    response = client.post(
        "/api/v1/insights/summary",
        json=request_data,
    )

    assert response.status_code == 422


def test_non_positive_lower_range_rejected():
    response = client.post(
        "/api/v1/insights/summary",
        json={
            "records": VALID_REQUEST[
                "records"
            ],
            "range_low": 0,
            "range_high": 180,
        },
    )

    assert response.status_code == 422


def test_non_positive_upper_range_rejected():
    response = client.post(
        "/api/v1/insights/summary",
        json={
            "records": VALID_REQUEST[
                "records"
            ],
            "range_low": 70,
            "range_high": 0,
        },
    )

    assert response.status_code == 422


def test_malformed_json_rejected():
    response = client.post(
        "/api/v1/insights/summary",
        content="{invalid-json",
        headers={
            "Content-Type": "application/json",
        },
    )

    assert response.status_code == 422


# =========================================================
# SCHEMA VALIDATION
# =========================================================

def test_invalid_range_order_returns_422():
    response = client.post(
        "/api/v1/insights/summary",
        json={
            "records": VALID_REQUEST[
                "records"
            ],
            "range_low": 180,
            "range_high": 70,
        },
    )

    body = response.json()

    assert response.status_code == 422
    assert body["status"] == "ERROR"

    assert (
        body["error"]["code"]
        == "VALIDATION_ERROR"
    )

    assert (
        "range_low must be less than range_high"
        in body["error"]["message"]
    )


# =========================================================
# SERVICE VALIDATION
# =========================================================

@patch("main.build_patient_summary")
def test_multiple_patients_returns_422(
    mock_summary,
):
    mock_summary.side_effect = ValueError(
        "Summary history must contain "
        "exactly one patient."
    )

    response = client.post(
        "/api/v1/insights/summary",
        json=VALID_REQUEST,
    )

    assert_api_error(
        response,
        status_code=422,
        code="INVALID_INPUT",
        message=(
            "Summary history must contain "
            "exactly one patient."
        ),
    )


# =========================================================
# UNEXPECTED SERVICE ERROR
# =========================================================

@patch("main.build_patient_summary")
def test_unexpected_error_returns_500(
    mock_summary,
):
    mock_summary.side_effect = RuntimeError(
        "Unexpected failure"
    )

    response = client.post(
        "/api/v1/insights/summary",
        json=VALID_REQUEST,
    )

    assert_api_error(
        response,
        status_code=500,
        code="INTERNAL_ERROR",
        message=(
            "Patient insight summary "
            "generation failed."
        ),
    )
