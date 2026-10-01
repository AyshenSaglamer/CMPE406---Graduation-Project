import pandas as pd
import pytest

from ml.future_target_builder import (
    MODEL_FEATURES,
    TREND_HIGHER,
    TREND_LOWER,
    TREND_STABLE,
    classify_future_change,
    create_future_trend_dataset,
    split_future_features_and_target,
)


def create_patient_records():
    return [
        # Patient A
        {
            "patient_id": "patient_a",
            "timestamp": "2026-01-01T08:00:00",
            "glucose_mg_dl": 100,
            "carbs_g": 20,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient_a",
            "timestamp": "2026-01-01T12:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 0,
        },
        {
            "patient_id": "patient_a",
            "timestamp": "2026-01-01T16:00:00",
            "glucose_mg_dl": 125,
            "carbs_g": 30,
            "activity_minutes": 20,
        },
        {
            "patient_id": "patient_a",
            "timestamp": "2026-01-01T20:00:00",
            "glucose_mg_dl": 95,
            "carbs_g": 25,
            "activity_minutes": 30,
        },

        # Patient B
        {
            "patient_id": "patient_b",
            "timestamp": "2026-01-01T08:00:00",
            "glucose_mg_dl": 200,
            "carbs_g": 50,
            "activity_minutes": 0,
        },
        {
            "patient_id": "patient_b",
            "timestamp": "2026-01-01T12:00:00",
            "glucose_mg_dl": 170,
            "carbs_g": 35,
            "activity_minutes": 15,
        },
        {
            "patient_id": "patient_b",
            "timestamp": "2026-01-01T16:00:00",
            "glucose_mg_dl": 175,
            "carbs_g": 45,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient_b",
            "timestamp": "2026-01-01T20:00:00",
            "glucose_mg_dl": 210,
            "carbs_g": 60,
            "activity_minutes": 0,
        },
    ]


# =========================================================
# CLASSIFICATION
# =========================================================

def test_future_change_higher():
    assert (
        classify_future_change(20)
        == TREND_HIGHER
    )


def test_future_change_lower():
    assert (
        classify_future_change(-20)
        == TREND_LOWER
    )


def test_future_change_stable():
    assert (
        classify_future_change(5)
        == TREND_STABLE
    )


def test_threshold_boundaries_are_stable():
    assert (
        classify_future_change(10)
        == TREND_STABLE
    )

    assert (
        classify_future_change(-10)
        == TREND_STABLE
    )


def test_invalid_threshold_rejected():
    with pytest.raises(
        ValueError,
        match="Stable threshold cannot be negative",
    ):
        classify_future_change(
            20,
            stable_threshold=-1,
        )


def test_non_numeric_change_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose change must be numeric",
    ):
        classify_future_change("hello")


# =========================================================
# FUTURE TARGET CREATION
# =========================================================

def test_future_dataset_created():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    assert not dataset.empty

    assert "next_glucose" in dataset.columns

    assert (
        "future_glucose_change"
        in dataset.columns
    )

    assert "trend_target" in dataset.columns


def test_next_glucose_is_patient_specific():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    patient_a = dataset[
        dataset["patient_id"] == "patient_a"
    ].reset_index(drop=True)

    patient_b = dataset[
        dataset["patient_id"] == "patient_b"
    ].reset_index(drop=True)

    # For Patient A, the usable middle records are:
    # current 120 -> next 125
    # current 125 -> next 95

    assert (
        patient_a.loc[
            0,
            "glucose_mg_dl",
        ]
        == 120
    )

    assert (
        patient_a.loc[
            0,
            "next_glucose",
        ]
        == 125
    )

    assert (
        patient_a.loc[
            1,
            "glucose_mg_dl",
        ]
        == 125
    )

    assert (
        patient_a.loc[
            1,
            "next_glucose",
        ]
        == 95
    )

    # Patient B must use only Patient B records.

    assert (
        patient_b.loc[
            0,
            "glucose_mg_dl",
        ]
        == 170
    )

    assert (
        patient_b.loc[
            0,
            "next_glucose",
        ]
        == 175
    )

    assert (
        patient_b.loc[
            1,
            "glucose_mg_dl",
        ]
        == 175
    )

    assert (
        patient_b.loc[
            1,
            "next_glucose",
        ]
        == 210
    )


def test_patient_boundaries_do_not_cross():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    patient_a = dataset[
        dataset["patient_id"] == "patient_a"
    ]

    patient_b = dataset[
        dataset["patient_id"] == "patient_b"
    ]

    # Patient A's final reading must never use
    # Patient B's first glucose reading as its future.
    assert not (
        (
            patient_a["glucose_mg_dl"] == 95
        )
        & (
            patient_a["next_glucose"] == 200
        )
    ).any()

    assert not (
        (
            patient_b["glucose_mg_dl"] == 210
        )
        & (
            patient_b["next_glucose"] == 100
        )
    ).any()


def test_future_targets_are_correct():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    patient_a = dataset[
        dataset["patient_id"] == "patient_a"
    ].reset_index(drop=True)

    patient_b = dataset[
        dataset["patient_id"] == "patient_b"
    ].reset_index(drop=True)

    # Patient A:
    # 120 -> 125 = +5 = STABLE
    # 125 -> 95 = -30 = LOWER

    assert (
        patient_a.loc[0, "trend_target"]
        == TREND_STABLE
    )

    assert (
        patient_a.loc[1, "trend_target"]
        == TREND_LOWER
    )

    # Patient B:
    # 170 -> 175 = +5 = STABLE
    # 175 -> 210 = +35 = HIGHER

    assert (
        patient_b.loc[0, "trend_target"]
        == TREND_STABLE
    )

    assert (
        patient_b.loc[1, "trend_target"]
        == TREND_HIGHER
    )


# =========================================================
# FEATURE / TARGET SPLIT
# =========================================================

def test_future_feature_split():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    X, y = split_future_features_and_target(
        dataset
    )

    assert list(X.columns) == MODEL_FEATURES

    assert len(X) == len(y)

    assert len(X) > 0


def test_future_information_does_not_leak_into_features():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    X, _ = split_future_features_and_target(
        dataset
    )

    forbidden_columns = {
        "next_glucose",
        "future_glucose_change",
        "trend_target",
    }

    for column in forbidden_columns:
        assert column not in X.columns


def test_patient_id_is_not_model_feature():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    X, _ = split_future_features_and_target(
        dataset
    )

    assert "patient_id" not in X.columns


def test_current_glucose_is_available_as_feature():
    dataset = create_future_trend_dataset(
        create_patient_records()
    )

    X, _ = split_future_features_and_target(
        dataset
    )

    assert "glucose_mg_dl" in X.columns


# =========================================================
# INSUFFICIENT SEQUENTIAL DATA
# =========================================================

def test_too_few_sequential_records_rejected():
    records = [
        {
            "patient_id": "patient_a",
            "timestamp": "2026-01-01T08:00:00",
            "glucose_mg_dl": 100,
            "carbs_g": 20,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient_a",
            "timestamp": "2026-01-01T12:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 30,
            "activity_minutes": 20,
        },
    ]

    with pytest.raises(
        ValueError,
        match="Not enough sequential patient records",
    ):
        create_future_trend_dataset(records)
