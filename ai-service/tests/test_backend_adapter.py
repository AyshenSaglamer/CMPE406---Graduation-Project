import numpy as np
import pandas as pd
import pytest

from data.backend_adapter import (
    create_patient_features,
    normalize_backend_records,
)


# =========================================================
# TEST DATA
# =========================================================

VALID_RECORDS = [
    {
        "patient_id": "patient_1",
        "timestamp": "2026-10-01T14:00:00",
        "glucose_mg_dl": 145,
        "carbs_g": 40,
        "activity_minutes": 20,
    },
    {
        "patient_id": "patient_1",
        "timestamp": "2026-10-01T10:00:00",
        "glucose_mg_dl": 120,
        "carbs_g": 25,
        "activity_minutes": 10,
    },
]


# =========================================================
# NORMALIZATION
# =========================================================

def test_normalize_backend_records_success():
    dataframe = normalize_backend_records(
        VALID_RECORDS
    )

    assert isinstance(
        dataframe,
        pd.DataFrame,
    )

    assert len(dataframe) == 2

    assert list(dataframe.columns) == [
        "patient_id",
        "timestamp",
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
    ]


def test_records_are_sorted_by_timestamp():
    dataframe = normalize_backend_records(
        VALID_RECORDS
    )

    assert (
        dataframe.iloc[0]["glucose_mg_dl"]
        == 120
    )

    assert (
        dataframe.iloc[1]["glucose_mg_dl"]
        == 145
    )

    assert (
        dataframe.iloc[0]["timestamp"]
        < dataframe.iloc[1]["timestamp"]
    )


def test_patient_id_is_trimmed():
    records = [
        {
            **VALID_RECORDS[0],
            "patient_id": "  patient_1  ",
        }
    ]

    dataframe = normalize_backend_records(
        records
    )

    assert (
        dataframe.iloc[0]["patient_id"]
        == "patient_1"
    )


def test_numeric_strings_are_converted():
    records = [
        {
            "patient_id": "patient_1",
            "timestamp": "2026-10-01T10:00:00",
            "glucose_mg_dl": "120",
            "carbs_g": "25",
            "activity_minutes": "10",
        }
    ]

    dataframe = normalize_backend_records(
        records
    )

    assert (
        dataframe.iloc[0]["glucose_mg_dl"]
        == 120
    )

    assert (
        dataframe.iloc[0]["carbs_g"]
        == 25
    )

    assert (
        dataframe.iloc[0]["activity_minutes"]
        == 10
    )


# =========================================================
# REQUIRED DATA VALIDATION
# =========================================================

def test_empty_records_rejected():
    with pytest.raises(
        ValueError,
        match="Backend records cannot be empty",
    ):
        normalize_backend_records([])


def test_missing_required_field_rejected():
    records = [
        {
            "patient_id": "patient_1",
            "timestamp": "2026-10-01T10:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 25,
        }
    ]

    with pytest.raises(
        ValueError,
        match="missing required fields",
    ):
        normalize_backend_records(records)


def test_empty_patient_id_rejected():
    records = [
        {
            **VALID_RECORDS[0],
            "patient_id": "   ",
        }
    ]

    with pytest.raises(
        ValueError,
        match="patient_id cannot be empty",
    ):
        normalize_backend_records(records)


def test_invalid_timestamp_rejected():
    records = [
        {
            **VALID_RECORDS[0],
            "timestamp": "not-a-date",
        }
    ]

    with pytest.raises(
        ValueError,
        match="timestamps must be valid",
    ):
        normalize_backend_records(records)


# =========================================================
# NUMERIC VALIDATION
# =========================================================

@pytest.mark.parametrize(
    "field",
    [
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
    ],
)
def test_non_numeric_values_rejected(field):
    records = [
        {
            **VALID_RECORDS[0],
            field: "hello",
        }
    ]

    with pytest.raises(
        ValueError,
        match="numeric values",
    ):
        normalize_backend_records(records)


@pytest.mark.parametrize(
    "field",
    [
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
    ],
)
def test_infinite_values_rejected(field):
    records = [
        {
            **VALID_RECORDS[0],
            field: np.inf,
        }
    ]

    with pytest.raises(
        ValueError,
        match="finite values",
    ):
        normalize_backend_records(records)


def test_zero_glucose_rejected():
    records = [
        {
            **VALID_RECORDS[0],
            "glucose_mg_dl": 0,
        }
    ]

    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        normalize_backend_records(records)


def test_negative_glucose_rejected():
    records = [
        {
            **VALID_RECORDS[0],
            "glucose_mg_dl": -10,
        }
    ]

    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        normalize_backend_records(records)


def test_negative_carbs_rejected():
    records = [
        {
            **VALID_RECORDS[0],
            "carbs_g": -1,
        }
    ]

    with pytest.raises(
        ValueError,
        match="cannot be negative",
    ):
        normalize_backend_records(records)


def test_negative_activity_rejected():
    records = [
        {
            **VALID_RECORDS[0],
            "activity_minutes": -1,
        }
    ]

    with pytest.raises(
        ValueError,
        match="cannot be negative",
    ):
        normalize_backend_records(records)


# =========================================================
# FEATURE ENGINEERING
# =========================================================

def test_time_features_are_created():
    records = [
        {
            "patient_id": "patient_1",
            "timestamp": "2026-10-03T14:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 25,
            "activity_minutes": 10,
        }
    ]

    dataframe = create_patient_features(
        records
    )

    assert dataframe.iloc[0]["hour_of_day"] == 14
    assert dataframe.iloc[0]["day_of_week"] == 5
    assert dataframe.iloc[0]["month"] == 10
    assert dataframe.iloc[0]["is_weekend"] == 1


def test_previous_glucose_is_patient_specific():
    records = [
        {
            "patient_id": "patient_a",
            "timestamp": "2026-10-01T10:00:00",
            "glucose_mg_dl": 100,
            "carbs_g": 10,
            "activity_minutes": 0,
        },
        {
            "patient_id": "patient_b",
            "timestamp": "2026-10-01T11:00:00",
            "glucose_mg_dl": 200,
            "carbs_g": 20,
            "activity_minutes": 0,
        },
        {
            "patient_id": "patient_a",
            "timestamp": "2026-10-01T12:00:00",
            "glucose_mg_dl": 130,
            "carbs_g": 30,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient_b",
            "timestamp": "2026-10-01T13:00:00",
            "glucose_mg_dl": 180,
            "carbs_g": 15,
            "activity_minutes": 20,
        },
    ]

    dataframe = create_patient_features(
        records
    )

    patient_a = dataframe[
        dataframe["patient_id"] == "patient_a"
    ].reset_index(drop=True)

    patient_b = dataframe[
        dataframe["patient_id"] == "patient_b"
    ].reset_index(drop=True)

    assert pd.isna(
        patient_a.iloc[0]["previous_glucose"]
    )

    assert (
        patient_a.iloc[1]["previous_glucose"]
        == 100
    )

    assert pd.isna(
        patient_b.iloc[0]["previous_glucose"]
    )

    assert (
        patient_b.iloc[1]["previous_glucose"]
        == 200
    )


def test_glucose_change_is_patient_specific():
    records = [
        {
            "patient_id": "patient_a",
            "timestamp": "2026-10-01T10:00:00",
            "glucose_mg_dl": 100,
            "carbs_g": 0,
            "activity_minutes": 0,
        },
        {
            "patient_id": "patient_a",
            "timestamp": "2026-10-01T12:00:00",
            "glucose_mg_dl": 130,
            "carbs_g": 0,
            "activity_minutes": 0,
        },
    ]

    dataframe = create_patient_features(
        records
    )

    assert pd.isna(
        dataframe.iloc[0]["glucose_change"]
    )

    assert (
        dataframe.iloc[1]["glucose_change"]
        == 30
    )
