import numpy as np
import pandas as pd
import pytest

from ml.target_builder import (
    TREND_HIGHER,
    TREND_LOWER,
    TREND_STABLE,
    classify_glucose_change,
    create_ml_dataset,
    create_trend_target,
    split_features_and_target,
)


# =========================================================
# TREND CLASSIFICATION
# =========================================================

def test_positive_change_classified_as_higher():
    result = classify_glucose_change(25)

    assert result == TREND_HIGHER


def test_negative_change_classified_as_lower():
    result = classify_glucose_change(-25)

    assert result == TREND_LOWER


def test_small_positive_change_classified_as_stable():
    result = classify_glucose_change(5)

    assert result == TREND_STABLE


def test_small_negative_change_classified_as_stable():
    result = classify_glucose_change(-5)

    assert result == TREND_STABLE


def test_zero_change_classified_as_stable():
    result = classify_glucose_change(0)

    assert result == TREND_STABLE


# =========================================================
# THRESHOLD BOUNDARIES
# =========================================================

def test_positive_boundary_is_stable():
    result = classify_glucose_change(
        10,
        stable_threshold=10,
    )

    assert result == TREND_STABLE


def test_negative_boundary_is_stable():
    result = classify_glucose_change(
        -10,
        stable_threshold=10,
    )

    assert result == TREND_STABLE


def test_value_above_boundary_is_higher():
    result = classify_glucose_change(
        10.1,
        stable_threshold=10,
    )

    assert result == TREND_HIGHER


def test_value_below_negative_boundary_is_lower():
    result = classify_glucose_change(
        -10.1,
        stable_threshold=10,
    )

    assert result == TREND_LOWER


def test_custom_threshold():
    assert (
        classify_glucose_change(
            15,
            stable_threshold=20,
        )
        == TREND_STABLE
    )

    assert (
        classify_glucose_change(
            25,
            stable_threshold=20,
        )
        == TREND_HIGHER
    )


# =========================================================
# INVALID CLASSIFICATION INPUT
# =========================================================

def test_negative_threshold_rejected():
    with pytest.raises(
        ValueError,
        match="Stable threshold cannot be negative",
    ):
        classify_glucose_change(
            10,
            stable_threshold=-1,
        )


def test_missing_glucose_change_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose change cannot be missing",
    ):
        classify_glucose_change(None)


def test_non_numeric_glucose_change_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose change must be numeric",
    ):
        classify_glucose_change("hello")


def test_nan_glucose_change_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose change must be finite",
    ):
        classify_glucose_change(np.nan)


def test_infinite_glucose_change_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose change must be finite",
    ):
        classify_glucose_change(np.inf)


# =========================================================
# TARGET CREATION
# =========================================================

def test_create_trend_target():
    dataframe = pd.DataFrame(
        {
            "glucose_change": [
                np.nan,
                30,
                5,
                -25,
            ]
        }
    )

    result = create_trend_target(dataframe)

    assert len(result) == 3

    assert (
        result.iloc[0]["trend_target"]
        == TREND_HIGHER
    )

    assert (
        result.iloc[1]["trend_target"]
        == TREND_STABLE
    )

    assert (
        result.iloc[2]["trend_target"]
        == TREND_LOWER
    )


def test_first_nan_change_removed():
    dataframe = pd.DataFrame(
        {
            "glucose_change": [
                np.nan,
                20,
                -20,
            ]
        }
    )

    result = create_trend_target(dataframe)

    assert len(result) == 2

    assert (
        result["glucose_change"]
        .isna()
        .sum()
        == 0
    )


def test_empty_dataframe_rejected():
    dataframe = pd.DataFrame()

    with pytest.raises(
        ValueError,
        match="Feature dataframe cannot be empty",
    ):
        create_trend_target(dataframe)


def test_missing_glucose_change_column_rejected():
    dataframe = pd.DataFrame(
        {
            "glucose_mg_dl": [
                100,
                120,
            ]
        }
    )

    with pytest.raises(
        ValueError,
        match=(
            "Feature dataframe must contain "
            "glucose_change"
        ),
    ):
        create_trend_target(dataframe)


def test_single_reading_cannot_create_target():
    dataframe = pd.DataFrame(
        {
            "glucose_change": [
                np.nan,
            ]
        }
    )

    with pytest.raises(
        ValueError,
        match=(
            "At least two glucose readings "
            "are required"
        ),
    ):
        create_trend_target(dataframe)


# =========================================================
# COMPLETE ML DATASET
# =========================================================

def test_create_ml_dataset():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 100,
            "carbs_g": 20,
            "activity_minutes": 30,
        },
        {
            "timestamp": "2026-09-01 12:00:00",
            "glucose_mg_dl": 130,
            "carbs_g": 50,
            "activity_minutes": 10,
        },
        {
            "timestamp": "2026-09-01 18:00:00",
            "glucose_mg_dl": 135,
            "carbs_g": 30,
            "activity_minutes": 20,
        },
        {
            "timestamp": "2026-09-02 08:00:00",
            "glucose_mg_dl": 105,
            "carbs_g": 20,
            "activity_minutes": 40,
        },
    ]

    result = create_ml_dataset(records)

    assert len(result) == 3

    assert "trend_target" in result.columns

    assert (
        result.iloc[0]["trend_target"]
        == TREND_HIGHER
    )

    assert (
        result.iloc[1]["trend_target"]
        == TREND_STABLE
    )

    assert (
        result.iloc[2]["trend_target"]
        == TREND_LOWER
    )


# =========================================================
# FEATURE / TARGET SPLIT
# =========================================================

def _create_sample_ml_dataset():
    return pd.DataFrame(
        {
            "timestamp": pd.to_datetime(
                [
                    "2026-09-01 12:00:00",
                    "2026-09-01 18:00:00",
                    "2026-09-02 08:00:00",
                ]
            ),
            "glucose_mg_dl": [
                130,
                135,
                105,
            ],
            "previous_glucose": [
                100,
                130,
                135,
            ],
            "glucose_change": [
                30,
                5,
                -30,
            ],
            "carbs_g": [
                50,
                30,
                20,
            ],
            "activity_minutes": [
                10,
                20,
                40,
            ],
            "hour_of_day": [
                12,
                18,
                8,
            ],
            "day_of_week": [
                1,
                1,
                2,
            ],
            "month": [
                9,
                9,
                9,
            ],
            "is_weekend": [
                0,
                0,
                0,
            ],
            "trend_target": [
                TREND_HIGHER,
                TREND_STABLE,
                TREND_LOWER,
            ],
        }
    )


def test_split_features_and_target():
    dataset = _create_sample_ml_dataset()

    X, y = split_features_and_target(dataset)

    assert len(X) == 3
    assert len(y) == 3

    assert list(X.columns) == [
        "previous_glucose",
        "carbs_g",
        "activity_minutes",
        "hour_of_day",
        "day_of_week",
        "month",
        "is_weekend",
    ]


# =========================================================
# DATA LEAKAGE PROTECTION
# =========================================================

def test_glucose_change_not_in_model_features():
    dataset = _create_sample_ml_dataset()

    X, _ = split_features_and_target(dataset)

    assert "glucose_change" not in X.columns


def test_current_glucose_not_in_model_features():
    dataset = _create_sample_ml_dataset()

    X, _ = split_features_and_target(dataset)

    assert "glucose_mg_dl" not in X.columns


def test_timestamp_not_in_model_features():
    dataset = _create_sample_ml_dataset()

    X, _ = split_features_and_target(dataset)

    assert "timestamp" not in X.columns


def test_target_not_in_model_features():
    dataset = _create_sample_ml_dataset()

    X, _ = split_features_and_target(dataset)

    assert "trend_target" not in X.columns


def test_target_values_preserved():
    dataset = _create_sample_ml_dataset()

    _, y = split_features_and_target(dataset)

    assert list(y) == [
        TREND_HIGHER,
        TREND_STABLE,
        TREND_LOWER,
    ]


# =========================================================
# SPLIT VALIDATION
# =========================================================

def test_empty_ml_dataset_rejected():
    dataframe = pd.DataFrame()

    with pytest.raises(
        ValueError,
        match="ML dataset cannot be empty",
    ):
        split_features_and_target(dataframe)


def test_missing_target_rejected():
    dataframe = pd.DataFrame(
        {
            "previous_glucose": [100],
        }
    )

    with pytest.raises(
        ValueError,
        match="ML dataset must contain trend_target",
    ):
        split_features_and_target(dataframe)


def test_missing_required_feature_rejected():
    dataframe = _create_sample_ml_dataset()

    dataframe = dataframe.drop(
        columns=["carbs_g"]
    )

    with pytest.raises(
        ValueError,
        match="ML dataset is missing required features",
    ):
        split_features_and_target(dataframe)
