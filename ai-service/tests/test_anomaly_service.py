import pytest

from services.anomaly_service import (
    analyze_patient_glucose_anomaly,
)


@pytest.fixture
def patient_records():
    return [
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
    ]


def test_anomaly_service_detects_unusual_latest_reading(
    patient_records,
):
    result = analyze_patient_glucose_anomaly(
        patient_records
    )

    assert result["patient_id"] == "patient-1"

    assert (
        result["anomaly"]["is_anomaly"]
        is True
    )

    assert (
        result["anomaly"]["absolute_z_score"]
        >= result["anomaly"]["threshold"]
    )


def test_latest_reading_is_not_in_baseline(
    patient_records,
):
    result = analyze_patient_glucose_anomaly(
        patient_records
    )

    assert result["history_record_count"] == 6
    assert result["baseline_record_count"] == 5

    assert (
        result["anomaly"]["baseline"]["count"]
        == 5
    )

    assert (
        result["anomaly"]["baseline"]["maximum"]
        == 126.0
    )

    # The latest reading is 170.
    # If it leaked into the baseline, maximum would
    # incorrectly become 170.
    assert (
        result["anomaly"]["baseline"]["maximum"]
        != 170.0
    )


def test_latest_record_selected_by_timestamp(
    patient_records,
):
    shuffled = [
        patient_records[5],
        patient_records[2],
        patient_records[0],
        patient_records[4],
        patient_records[1],
        patient_records[3],
    ]

    result = analyze_patient_glucose_anomaly(
        shuffled
    )

    assert (
        result["current_timestamp"]
        == "2026-10-06T08:00:00"
    )

    assert (
        result["anomaly"]["current_value"]
        == 170.0
    )


def test_typical_latest_reading_not_anomaly(
    patient_records,
):
    records = [
        record.copy()
        for record in patient_records
    ]

    records[-1][
        "glucose_mg_dl"
    ] = 122

    result = analyze_patient_glucose_anomaly(
        records
    )

    assert (
        result["anomaly"]["is_anomaly"]
        is False
    )


def test_service_returns_expected_metadata(
    patient_records,
):
    result = analyze_patient_glucose_anomaly(
        patient_records
    )

    assert (
        result["source"]
        == "patient_history"
    )

    assert result["purpose"] == (
        "personalized_glucose_"
        "anomaly_detection"
    )

    assert (
        result["anomaly"]["scope"]
        == "personalized_statistical_pattern"
    )


def test_custom_threshold_is_forwarded(
    patient_records,
):
    result = analyze_patient_glucose_anomaly(
        patient_records,
        z_threshold=3.0,
    )

    assert (
        result["anomaly"]["threshold"]
        == 3.0
    )


def test_empty_history_rejected():
    with pytest.raises(
        ValueError,
        match="cannot be empty",
    ):
        analyze_patient_glucose_anomaly(
            []
        )


def test_insufficient_history_rejected(
    patient_records,
):
    with pytest.raises(
        ValueError,
        match="At least 6 patient history records",
    ):
        analyze_patient_glucose_anomaly(
            patient_records[:5]
        )


def test_multiple_patients_rejected(
    patient_records,
):
    records = [
        record.copy()
        for record in patient_records
    ]

    records[0]["patient_id"] = "patient-2"

    with pytest.raises(
        ValueError,
        match="exactly one patient",
    ):
        analyze_patient_glucose_anomaly(
            records
        )


def test_safety_disclaimer_preserved(
    patient_records,
):
    result = analyze_patient_glucose_anomaly(
        patient_records
    )

    disclaimer = result[
        "anomaly"
    ]["disclaimer"].lower()

    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer
    assert "medication" in disclaimer
