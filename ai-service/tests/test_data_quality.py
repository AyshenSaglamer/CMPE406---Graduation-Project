import pandas as pd
import pytest

from analytics.data_quality import (
    analyze_data_quality,
)


def clean_dataframe():
    """
    Create a small valid patient-history dataset.
    """

    return pd.DataFrame(
        [
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
        ]
    )


def test_clean_data_is_good():
    dataframe = clean_dataframe()

    result = analyze_data_quality(
        dataframe
    )

    assert (
        result["quality_status"]
        == "GOOD"
    )

    assert result["issues"] == []

    assert result["record_count"] == 3


def test_clean_data_has_no_missing_values():
    dataframe = clean_dataframe()

    result = analyze_data_quality(
        dataframe
    )

    missing = result[
        "missing_values"
    ]

    assert (
        missing["total_missing_values"]
        == 0
    )

    assert (
        missing["has_missing_values"]
        is False
    )


def test_missing_value_is_detected():
    dataframe = clean_dataframe()

    dataframe.loc[
        1,
        "carbs_g",
    ] = None

    result = analyze_data_quality(
        dataframe
    )

    assert (
        result["quality_status"]
        == "ISSUES_DETECTED"
    )

    assert (
        "MISSING_VALUES"
        in result["issues"]
    )

    assert (
        result[
            "missing_values"
        ][
            "missing_by_field"
        ][
            "carbs_g"
        ]
        == 1
    )


def test_duplicate_record_is_detected():
    dataframe = clean_dataframe()

    duplicate = (
        dataframe.iloc[[0]]
        .copy()
    )

    dataframe = pd.concat(
        [
            dataframe,
            duplicate,
        ],
        ignore_index=True,
    )

    result = analyze_data_quality(
        dataframe
    )

    assert (
        "DUPLICATE_RECORDS"
        in result["issues"]
    )

    assert (
        result[
            "duplicates"
        ][
            "duplicate_record_count"
        ]
        == 1
    )

    assert (
        result[
            "duplicates"
        ][
            "has_duplicate_records"
        ]
        is True
    )


def test_invalid_timestamp_is_detected():
    dataframe = clean_dataframe()

    dataframe.loc[
        1,
        "timestamp",
    ] = "not-a-date"

    result = analyze_data_quality(
        dataframe
    )

    assert (
        "INVALID_TIMESTAMPS"
        in result["issues"]
    )

    assert (
        result[
            "time_gaps"
        ][
            "invalid_timestamp_count"
        ]
        == 1
    )


def test_large_logging_gap_is_detected():
    dataframe = pd.DataFrame(
        [
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T08:00:00",
                "glucose_mg_dl": 110.0,
                "carbs_g": 20.0,
                "activity_minutes": 10.0,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-03T08:00:00",
                "glucose_mg_dl": 120.0,
                "carbs_g": 30.0,
                "activity_minutes": 20.0,
            },
        ]
    )

    result = analyze_data_quality(
        dataframe,
        large_gap_hours=24.0,
    )

    assert (
        "LARGE_LOGGING_GAPS"
        in result["issues"]
    )

    assert (
        result[
            "time_gaps"
        ][
            "large_gap_count"
        ]
        == 1
    )

    assert (
        result[
            "time_gaps"
        ][
            "largest_gap_hours"
        ]
        == 48.0
    )


def test_exact_threshold_is_not_large_gap():
    dataframe = pd.DataFrame(
        [
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T08:00:00",
                "glucose_mg_dl": 110.0,
                "carbs_g": 20.0,
                "activity_minutes": 10.0,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-02T08:00:00",
                "glucose_mg_dl": 120.0,
                "carbs_g": 30.0,
                "activity_minutes": 20.0,
            },
        ]
    )

    result = analyze_data_quality(
        dataframe,
        large_gap_hours=24.0,
    )

    assert (
        result[
            "time_gaps"
        ][
            "large_gap_count"
        ]
        == 0
    )


def test_missing_required_column_is_rejected():
    dataframe = clean_dataframe()

    dataframe = dataframe.drop(
        columns=[
            "glucose_mg_dl"
        ]
    )

    with pytest.raises(
        ValueError,
        match="Missing required columns",
    ):
        analyze_data_quality(
            dataframe
        )


def test_empty_dataframe_is_rejected():
    dataframe = pd.DataFrame()

    with pytest.raises(
        ValueError,
        match=(
            "Patient history cannot be empty"
        ),
    ):
        analyze_data_quality(
            dataframe
        )


@pytest.mark.parametrize(
    "large_gap_hours",
    [
        0,
        -1,
        float("inf"),
        float("-inf"),
        float("nan"),
    ],
)
def test_invalid_gap_threshold_is_rejected(
    large_gap_hours,
):
    dataframe = clean_dataframe()

    with pytest.raises(
        ValueError,
        match=(
            "large_gap_hours must be "
            "a positive finite number"
        ),
    ):
        analyze_data_quality(
            dataframe,
            large_gap_hours=(
                large_gap_hours
            ),
        )


def test_metadata_is_returned():
    dataframe = clean_dataframe()

    result = analyze_data_quality(
        dataframe
    )

    assert (
        result["scope"]
        == "patient_history_data_quality"
    )

    assert (
        result["method"]
        == "deterministic_quality_checks"
    )


def test_safety_disclaimer_is_returned():
    dataframe = clean_dataframe()

    result = analyze_data_quality(
        dataframe
    )

    disclaimer = (
        result["disclaimer"]
        .lower()
    )

    assert "data quality" in disclaimer
    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer
