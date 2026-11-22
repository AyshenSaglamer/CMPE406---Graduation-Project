import pytest

from services.drift_service import (
    _prepare_drift_features,
    analyze_model_drift,
)


# ============================================================
# TEST DATA
# ============================================================


def reference_records():
    """
    Six raw records become five ML-ready records because
    the first record has no previous_glucose value.
    """

    return [
        {
            "patient_id": "patient-1",
            "timestamp": "2026-09-01T08:00:00",
            "glucose_mg_dl": 110.0,
            "carbs_g": 30.0,
            "activity_minutes": 20.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-09-02T10:00:00",
            "glucose_mg_dl": 120.0,
            "carbs_g": 40.0,
            "activity_minutes": 30.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-09-03T12:00:00",
            "glucose_mg_dl": 130.0,
            "carbs_g": 35.0,
            "activity_minutes": 25.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-09-04T14:00:00",
            "glucose_mg_dl": 125.0,
            "carbs_g": 45.0,
            "activity_minutes": 35.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-09-05T16:00:00",
            "glucose_mg_dl": 115.0,
            "carbs_g": 25.0,
            "activity_minutes": 15.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-09-06T18:00:00",
            "glucose_mg_dl": 122.0,
            "carbs_g": 32.0,
            "activity_minutes": 22.0,
        },
    ]


def current_records():
    """
    Four raw records become three ML-ready records.
    """

    return [
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-01T08:00:00",
            "glucose_mg_dl": 112.0,
            "carbs_g": 31.0,
            "activity_minutes": 21.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-02T10:00:00",
            "glucose_mg_dl": 121.0,
            "carbs_g": 39.0,
            "activity_minutes": 29.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-03T12:00:00",
            "glucose_mg_dl": 128.0,
            "carbs_g": 36.0,
            "activity_minutes": 26.0,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-04T14:00:00",
            "glucose_mg_dl": 124.0,
            "carbs_g": 43.0,
            "activity_minutes": 33.0,
        },
    ]


def clearly_drifted_current_records():
    records = current_records()

    records[0]["glucose_mg_dl"] = 175.0
    records[1]["glucose_mg_dl"] = 185.0
    records[2]["glucose_mg_dl"] = 195.0
    records[3]["glucose_mg_dl"] = 205.0

    return records


# ============================================================
# FEATURE PREPARATION
# ============================================================


def test_prepare_reference_features():
    dataframe = _prepare_drift_features(
        reference_records(),
        dataset_name="Reference",
    )

    # Six raw records -> five usable sequential records.
    assert len(dataframe) == 5


def test_prepare_current_features():
    dataframe = _prepare_drift_features(
        current_records(),
        dataset_name="Current",
    )

    # Four raw records -> three usable sequential records.
    assert len(dataframe) == 3


def test_previous_glucose_uses_past_record():
    dataframe = _prepare_drift_features(
        reference_records(),
        dataset_name="Reference",
    )

    first_row = dataframe.iloc[0]

    assert (
        first_row["glucose_mg_dl"]
        == 120.0
    )

    assert (
        first_row["previous_glucose"]
        == 110.0
    )


def test_time_features_are_created():
    dataframe = _prepare_drift_features(
        reference_records(),
        dataset_name="Reference",
    )

    first_row = dataframe.iloc[0]

    # First usable row is:
    # 2026-09-02T10:00:00

    assert (
        first_row["hour_of_day"]
        == 10
    )

    assert (
        first_row["month"]
        == 9
    )

    assert (
        first_row["is_weekend"]
        == 0
    )


def test_prepared_data_contains_required_features():
    dataframe = _prepare_drift_features(
        reference_records(),
        dataset_name="Reference",
    )

    expected = {
        "glucose_mg_dl",
        "previous_glucose",
        "carbs_g",
        "activity_minutes",
        "hour_of_day",
        "day_of_week",
        "month",
        "is_weekend",
    }

    assert (
        set(dataframe.columns)
        == expected
    )


# ============================================================
# SERVICE SUCCESS
# ============================================================


def test_drift_service_returns_patient():
    result = analyze_model_drift(
        reference_records(),
        current_records(),
    )

    assert (
        result["patient_id"]
        == "patient-1"
    )


def test_service_returns_drift_result():
    result = analyze_model_drift(
        reference_records(),
        current_records(),
    )

    assert "drift_detected" in result
    assert "status" in result
    assert "features" in result


def test_clear_shift_detects_drift():
    result = analyze_model_drift(
        reference_records(),
        clearly_drifted_current_records(),
    )

    assert (
        result["drift_detected"]
        is True
    )

    assert (
        "glucose_mg_dl"
        in result["drifted_features"]
    )


def test_service_record_counts_are_feature_counts():
    result = analyze_model_drift(
        reference_records(),
        current_records(),
    )

    assert (
        result["reference_record_count"]
        == 5
    )

    assert (
        result["current_record_count"]
        == 3
    )


def test_custom_threshold_is_passed():
    result = analyze_model_drift(
        reference_records(),
        current_records(),
        mean_shift_threshold=2.0,
    )

    assert (
        result["mean_shift_threshold"]
        == 2.0
    )


# ============================================================
# PATIENT SAFETY / CONSISTENCY
# ============================================================


def test_different_patients_are_rejected():
    current = current_records()

    for record in current:
        record["patient_id"] = "patient-2"

    with pytest.raises(
        ValueError,
        match="same patient",
    ):
        analyze_model_drift(
            reference_records(),
            current,
        )


def test_multiple_reference_patients_are_rejected():
    reference = reference_records()

    reference[2]["patient_id"] = (
        "patient-2"
    )

    with pytest.raises(
        ValueError,
        match="exactly one patient",
    ):
        analyze_model_drift(
            reference,
            current_records(),
        )


def test_multiple_current_patients_are_rejected():
    current = current_records()

    current[1]["patient_id"] = (
        "patient-2"
    )

    with pytest.raises(
        ValueError,
        match="exactly one patient",
    ):
        analyze_model_drift(
            reference_records(),
            current,
        )


# ============================================================
# EMPTY / INSUFFICIENT DATA
# ============================================================


def test_empty_reference_is_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "Reference patient history "
            "cannot be empty"
        ),
    ):
        analyze_model_drift(
            [],
            current_records(),
        )


def test_empty_current_is_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "Current patient history "
            "cannot be empty"
        ),
    ):
        analyze_model_drift(
            reference_records(),
            [],
        )


def test_too_few_reference_raw_records_are_rejected():
    reference = (
        reference_records()[:5]
    )

    # 5 raw records become only 4 ML-ready rows.
    with pytest.raises(
        ValueError,
        match="at least 5 records",
    ):
        analyze_model_drift(
            reference,
            current_records(),
        )


def test_too_few_current_raw_records_are_rejected():
    current = (
        current_records()[:3]
    )

    # 3 raw records become only 2 ML-ready rows.
    with pytest.raises(
        ValueError,
        match="at least 3 records",
    ):
        analyze_model_drift(
            reference_records(),
            current,
        )


# ============================================================
# METADATA / SAFETY
# ============================================================


def test_service_metadata():
    result = analyze_model_drift(
        reference_records(),
        current_records(),
    )

    assert (
        result["source"]
        == "patient_history"
    )

    assert (
        result["purpose"]
        == "model_input_drift_monitoring"
    )

    assert (
        result["scope"]
        == "model_input_data_drift"
    )

    assert (
        result["method"]
        == "standardized_mean_shift"
    )


def test_service_contains_safety_disclaimer():
    result = analyze_model_drift(
        reference_records(),
        current_records(),
    )

    disclaimer = (
        result["disclaimer"]
        .lower()
    )

    assert "diagnosis" in disclaimer

    assert (
        "clinical deterioration"
        in disclaimer
    )

    assert "treatment" in disclaimer
