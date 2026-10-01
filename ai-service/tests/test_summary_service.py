from unittest.mock import patch

import pytest

from services.summary_service import (
    build_patient_summary,
)


VALID_RECORDS = [
    {
        "patient_id": "patient_123",
        "timestamp": "2026-10-01T06:00:00",
        "glucose_mg_dl": 110,
        "carbs_g": 20,
        "activity_minutes": 0,
    },
    {
        "patient_id": "patient_123",
        "timestamp": "2026-10-01T10:00:00",
        "glucose_mg_dl": 135,
        "carbs_g": 35,
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


MOCK_PREDICTION = {
    "prediction": "STABLE",
    "probabilities": {
        "HIGHER": 0.10,
        "LOWER": 0.20,
        "STABLE": 0.70,
    },
    "model_type": "XGBoost",
    "prediction_target": "next_glucose_trend",
    "source": "patient_history",
    "history_record_count": 3,
}


# =========================================================
# SUCCESS
# =========================================================

@patch(
    "services.summary_service."
    "predict_from_patient_history"
)
def test_build_patient_summary_success(
    mock_predict,
):
    mock_predict.return_value = MOCK_PREDICTION

    result = build_patient_summary(
        VALID_RECORDS
    )

    assert result["status"] == "SUCCESS"

    assert (
        result["patient_id"]
        == "patient_123"
    )

    assert result["record_count"] == 3

    assert (
        result["configured_range"][
            "low_mg_dl"
        ]
        == 70.0
    )

    assert (
        result["configured_range"][
            "high_mg_dl"
        ]
        == 180.0
    )

    statistics = result[
        "analytics"
    ]["glucose_statistics"]

    assert statistics["count"] == 3

    assert statistics["mean"] == 130.0

    assert statistics["minimum"] == 110.0

    assert statistics["maximum"] == 145.0

    time_in_range = result[
        "analytics"
    ]["time_in_range"]

    assert (
        time_in_range[
            "time_in_range_percentage"
        ]
        == 100.0
    )

    assert (
        result["ml_prediction"]["status"]
        == "AVAILABLE"
    )

    assert (
        result["ml_prediction"]["result"][
            "prediction"
        ]
        == "STABLE"
    )

    assert (
        result["insight_summary"]["status"]
        == "SUCCESS"
    )

    assert (
        result["insight_summary"][
            "insight_count"
        ]
        >= 1
    )


# =========================================================
# CONFIGURED RANGE
# =========================================================

@patch(
    "services.summary_service."
    "predict_from_patient_history"
)
def test_custom_range_is_used(
    mock_predict,
):
    mock_predict.return_value = MOCK_PREDICTION

    result = build_patient_summary(
        VALID_RECORDS,
        range_low=100,
        range_high=140,
    )

    configured = result[
        "configured_range"
    ]

    assert configured["low_mg_dl"] == 100.0
    assert configured["high_mg_dl"] == 140.0

    tir = result[
        "analytics"
    ]["time_in_range"]

    assert tir["lower_bound"] == 100.0
    assert tir["upper_bound"] == 140.0

    assert tir["in_range_count"] == 2
    assert tir["above_range_count"] == 1


# =========================================================
# VALIDATION
# =========================================================

def test_empty_history_rejected():
    with pytest.raises(
        ValueError,
        match="Patient history cannot be empty",
    ):
        build_patient_summary([])


def test_invalid_range_order_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "range_low must be lower "
            "than range_high"
        ),
    ):
        build_patient_summary(
            VALID_RECORDS,
            range_low=180,
            range_high=70,
        )


def test_equal_range_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "range_low must be lower "
            "than range_high"
        ),
    ):
        build_patient_summary(
            VALID_RECORDS,
            range_low=100,
            range_high=100,
        )


def test_non_positive_range_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "Range bounds must be "
            "greater than zero"
        ),
    ):
        build_patient_summary(
            VALID_RECORDS,
            range_low=0,
            range_high=180,
        )


def test_multiple_patients_rejected():
    records = [
        record.copy()
        for record in VALID_RECORDS
    ]

    records[2]["patient_id"] = (
        "patient_999"
    )

    with pytest.raises(
        ValueError,
        match=(
            "Summary history must contain "
            "exactly one patient"
        ),
    ):
        build_patient_summary(records)


# =========================================================
# ML AVAILABILITY
# =========================================================

@patch(
    "services.summary_service."
    "predict_from_patient_history"
)
def test_missing_model_does_not_break_summary(
    mock_predict,
):
    mock_predict.side_effect = (
        FileNotFoundError()
    )

    result = build_patient_summary(
        VALID_RECORDS
    )

    assert result["status"] == "SUCCESS"

    assert (
        result["ml_prediction"]["status"]
        == "MODEL_NOT_AVAILABLE"
    )

    assert (
        result["ml_prediction"]["result"]
        is None
    )

    # Analytics must still be available.
    assert (
        result["analytics"][
            "glucose_statistics"
        ]["count"]
        == 3
    )


# =========================================================
# SINGLE RECORD
# =========================================================

def test_single_record_supports_analytics():
    result = build_patient_summary(
        [VALID_RECORDS[0]]
    )

    assert result["status"] == "SUCCESS"

    assert result["record_count"] == 1

    assert (
        result["ml_prediction"]["status"]
        == "NOT_AVAILABLE"
    )

    assert (
        result["ml_prediction"]["result"]
        is None
    )


# =========================================================
# SAFETY
# =========================================================

@patch(
    "services.summary_service."
    "predict_from_patient_history"
)
def test_summary_contains_safety_disclaimer(
    mock_predict,
):
    mock_predict.return_value = MOCK_PREDICTION

    result = build_patient_summary(
        VALID_RECORDS
    )

    disclaimer = (
        result["disclaimer"].lower()
    )

    assert "does not provide" in disclaimer
    assert "medical diagnosis" in disclaimer
    assert "medication dosing advice" in disclaimer
