import math

import pytest

from analytics.feature_engineering import create_ml_features


SAMPLE_RECORDS = [
    {
        "timestamp": "2026-09-01 08:00:00",
        "glucose_mg_dl": 100,
        "carbs_g": 30,
        "activity_minutes": 0,
    },
    {
        "timestamp": "2026-09-01 14:00:00",
        "glucose_mg_dl": 140,
        "carbs_g": 50,
        "activity_minutes": 20,
    },
    {
        "timestamp": "2026-09-02 09:00:00",
        "glucose_mg_dl": 120,
        "carbs_g": 25,
        "activity_minutes": 30,
    },
]


# =========================================================
# BASIC FEATURE ENGINEERING
# =========================================================

def test_create_ml_features():
    result = create_ml_features(SAMPLE_RECORDS)

    assert len(result) == 3

    expected_columns = {
        "timestamp",
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
        "hour_of_day",
        "day_of_week",
        "month",
        "is_weekend",
        "previous_glucose",
        "glucose_change",
    }

    assert expected_columns.issubset(
        set(result.columns)
    )


# =========================================================
# TIME FEATURES
# =========================================================

def test_hour_of_day():
    result = create_ml_features(SAMPLE_RECORDS)

    assert result.iloc[0]["hour_of_day"] == 8
    assert result.iloc[1]["hour_of_day"] == 14
    assert result.iloc[2]["hour_of_day"] == 9


def test_day_of_week():
    result = create_ml_features(SAMPLE_RECORDS)

    # 1 September 2026 = Tuesday
    # Pandas: Monday=0, Tuesday=1
    assert result.iloc[0]["day_of_week"] == 1
    assert result.iloc[1]["day_of_week"] == 1

    # 2 September 2026 = Wednesday
    assert result.iloc[2]["day_of_week"] == 2


def test_month_feature():
    result = create_ml_features(SAMPLE_RECORDS)

    assert result.iloc[0]["month"] == 9
    assert result.iloc[1]["month"] == 9
    assert result.iloc[2]["month"] == 9


def test_weekend_feature():
    records = [
        {
            "timestamp": "2026-09-05 10:00:00",
            "glucose_mg_dl": 110,
            "carbs_g": 30,
            "activity_minutes": 20,
        },
        {
            "timestamp": "2026-09-07 10:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 10,
        },
    ]

    result = create_ml_features(records)

    # 5 September 2026 = Saturday
    assert result.iloc[0]["is_weekend"] == 1

    # 7 September 2026 = Monday
    assert result.iloc[1]["is_weekend"] == 0


# =========================================================
# PREVIOUS GLUCOSE
# =========================================================

def test_previous_glucose():
    result = create_ml_features(SAMPLE_RECORDS)

    assert math.isnan(
        result.iloc[0]["previous_glucose"]
    )

    assert (
        result.iloc[1]["previous_glucose"]
        == 100
    )

    assert (
        result.iloc[2]["previous_glucose"]
        == 140
    )


# =========================================================
# GLUCOSE CHANGE
# =========================================================

def test_glucose_change():
    result = create_ml_features(SAMPLE_RECORDS)

    assert math.isnan(
        result.iloc[0]["glucose_change"]
    )

    assert (
        result.iloc[1]["glucose_change"]
        == 40
    )

    assert (
        result.iloc[2]["glucose_change"]
        == -20
    )


# =========================================================
# SORTING
# =========================================================

def test_records_sorted_before_feature_creation():
    records = [
        {
            "timestamp": "2026-09-03 08:00:00",
            "glucose_mg_dl": 150,
            "carbs_g": 30,
            "activity_minutes": 10,
        },
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 100,
            "carbs_g": 20,
            "activity_minutes": 20,
        },
        {
            "timestamp": "2026-09-02 08:00:00",
            "glucose_mg_dl": 130,
            "carbs_g": 40,
            "activity_minutes": 30,
        },
    ]

    result = create_ml_features(records)

    assert result.iloc[0]["glucose_mg_dl"] == 100
    assert result.iloc[1]["glucose_mg_dl"] == 130
    assert result.iloc[2]["glucose_mg_dl"] == 150

    assert (
        result.iloc[1]["previous_glucose"]
        == 100
    )

    assert (
        result.iloc[2]["previous_glucose"]
        == 130
    )


# =========================================================
# VALIDATION
# =========================================================

def test_empty_records_rejected():
    with pytest.raises(
        ValueError,
        match="Feature engineering records cannot be empty",
    ):
        create_ml_features([])


def test_missing_timestamp_rejected():
    records = [
        {
            "glucose_mg_dl": 120,
            "carbs_g": 30,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Each record must contain",
    ):
        create_ml_features(records)


def test_missing_glucose_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "carbs_g": 30,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Each record must contain",
    ):
        create_ml_features(records)


def test_missing_carbs_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 120,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Each record must contain",
    ):
        create_ml_features(records)


def test_missing_activity_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 30,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Each record must contain",
    ):
        create_ml_features(records)


def test_invalid_timestamp_rejected():
    records = [
        {
            "timestamp": "not-a-date",
            "glucose_mg_dl": 120,
            "carbs_g": 30,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="All timestamps must be valid",
    ):
        create_ml_features(records)


def test_non_numeric_glucose_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": "hello",
            "carbs_g": 30,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="glucose_mg_dl must contain numeric values",
    ):
        create_ml_features(records)


def test_zero_glucose_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 0,
            "carbs_g": 30,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Glucose values must be greater than zero",
    ):
        create_ml_features(records)


def test_negative_carbs_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": -10,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Carbohydrate values cannot be negative",
    ):
        create_ml_features(records)


def test_negative_activity_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 30,
            "activity_minutes": -10,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Activity minutes cannot be negative",
    ):
        create_ml_features(records)
