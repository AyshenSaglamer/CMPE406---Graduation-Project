from pathlib import Path

import pandas as pd
import pytest

import ml.training as training_module
from ml.training import (
    chronological_train_test_split,
    create_xgboost_classifier,
    train_glucose_trend_model,
)


# =========================================================
# CHRONOLOGICAL SPLIT
# =========================================================

def test_chronological_train_test_split():
    X = pd.DataFrame(
        {
            "value": list(range(10))
        }
    )

    y = pd.Series(
        [
            "LOWER",
            "STABLE",
            "HIGHER",
            "LOWER",
            "STABLE",
            "HIGHER",
            "LOWER",
            "STABLE",
            "HIGHER",
            "LOWER",
        ]
    )

    (
        X_train,
        X_test,
        y_train,
        y_test,
    ) = chronological_train_test_split(
        X,
        y,
        test_ratio=0.2,
    )

    assert len(X_train) == 8
    assert len(X_test) == 2

    assert len(y_train) == 8
    assert len(y_test) == 2

    # Earlier records must remain in training.
    assert list(X_train["value"]) == list(
        range(8)
    )

    # Latest records must remain in testing.
    assert list(X_test["value"]) == [8, 9]


def test_chronological_split_preserves_order():
    X = pd.DataFrame(
        {
            "value": [
                10,
                20,
                30,
                40,
                50,
            ]
        }
    )

    y = pd.Series(
        [
            "LOWER",
            "STABLE",
            "HIGHER",
            "LOWER",
            "STABLE",
        ]
    )

    (
        X_train,
        X_test,
        _,
        _,
    ) = chronological_train_test_split(
        X,
        y,
        test_ratio=0.4,
    )

    assert list(X_train["value"]) == [
        10,
        20,
        30,
    ]

    assert list(X_test["value"]) == [
        40,
        50,
    ]


# =========================================================
# SPLIT VALIDATION
# =========================================================

def test_mismatched_feature_target_lengths_rejected():
    X = pd.DataFrame(
        {
            "value": [
                1,
                2,
                3,
                4,
                5,
            ]
        }
    )

    y = pd.Series(
        [
            "LOWER",
            "STABLE",
        ]
    )

    with pytest.raises(
        ValueError,
        match=(
            "Features and target must contain "
            "the same number of rows"
        ),
    ):
        chronological_train_test_split(
            X,
            y,
        )


def test_too_few_records_rejected():
    X = pd.DataFrame(
        {
            "value": [
                1,
                2,
                3,
                4,
            ]
        }
    )

    y = pd.Series(
        [
            "LOWER",
            "STABLE",
            "HIGHER",
            "LOWER",
        ]
    )

    with pytest.raises(
        ValueError,
        match=(
            "At least five ML records "
            "are required"
        ),
    ):
        chronological_train_test_split(
            X,
            y,
        )


def test_zero_test_ratio_rejected():
    X = pd.DataFrame(
        {
            "value": list(range(10))
        }
    )

    y = pd.Series(
        ["STABLE"] * 10
    )

    with pytest.raises(
        ValueError,
        match=(
            "Test ratio must be between "
            "0 and 1"
        ),
    ):
        chronological_train_test_split(
            X,
            y,
            test_ratio=0,
        )


def test_test_ratio_one_rejected():
    X = pd.DataFrame(
        {
            "value": list(range(10))
        }
    )

    y = pd.Series(
        ["STABLE"] * 10
    )

    with pytest.raises(
        ValueError,
        match=(
            "Test ratio must be between "
            "0 and 1"
        ),
    ):
        chronological_train_test_split(
            X,
            y,
            test_ratio=1,
        )


# =========================================================
# MODEL CREATION
# =========================================================

def test_xgboost_classifier_created():
    model = create_xgboost_classifier()

    assert model is not None

    assert model.get_params()[
        "objective"
    ] == "multi:softprob"

    assert model.get_params()[
        "n_estimators"
    ] == 100

    assert model.get_params()[
        "random_state"
    ] == 42


# =========================================================
# SYNTHETIC TRAINING DATA
# =========================================================

def create_training_records():
    """
    Create deterministic synthetic records containing
    LOWER, STABLE, and HIGHER trend examples.

    These records exist only to test the software
    training pipeline. They are not clinical data.
    """

    glucose_pattern = [
        100,
        130,  # HIGHER
        135,  # STABLE
        105,  # LOWER
        140,  # HIGHER
        145,  # STABLE
        110,  # LOWER
        150,  # HIGHER
        155,  # STABLE
        120,  # LOWER
        160,  # HIGHER
        165,  # STABLE
        130,  # LOWER
        170,  # HIGHER
        175,  # STABLE
        140,  # LOWER
        180,  # HIGHER
        185,  # STABLE
        150,  # LOWER
        190,  # HIGHER
        195,  # STABLE
        160,  # LOWER
        200,  # HIGHER
        205,  # STABLE
        170,  # LOWER
        210,  # HIGHER
        215,  # STABLE
        180,  # LOWER
        220,  # HIGHER
        225,  # STABLE
        190,  # LOWER
    ]

    records = []

    start_time = pd.Timestamp(
        "2026-01-01 08:00:00"
    )

    for index, glucose in enumerate(
        glucose_pattern
    ):
        timestamp = (
            start_time
            + pd.Timedelta(
                hours=index * 4
            )
        )

        records.append(
            {
                "timestamp": (
                    timestamp.isoformat()
                ),
                "glucose_mg_dl": glucose,
                "carbs_g": (
                    20
                    + (index % 5) * 10
                ),
                "activity_minutes": (
                    (index % 4) * 10
                ),
            }
        )

    return records


# =========================================================
# COMPLETE TRAINING PIPELINE
# =========================================================

def test_train_glucose_trend_model():
    records = create_training_records()

    result = train_glucose_trend_model(
        records,
        test_ratio=0.2,
        save_model=False,
    )

    assert result["status"] == "trained"

    assert (
        result["training_sample_size"]
        > 0
    )

    assert (
        result["test_sample_size"]
        > 0
    )

    assert "metrics" in result

    assert (
        0.0
        <= result["metrics"]["accuracy"]
        <= 1.0
    )

    assert (
        "classification_report"
        in result["metrics"]
    )


def test_training_uses_expected_features():
    records = create_training_records()

    result = train_glucose_trend_model(
        records,
        save_model=False,
    )

    assert result["feature_names"] == [
        "previous_glucose",
        "carbs_g",
        "activity_minutes",
        "hour_of_day",
        "day_of_week",
        "month",
        "is_weekend",
    ]

    # Leakage-sensitive columns must not appear.
    assert (
        "glucose_change"
        not in result["feature_names"]
    )

    assert (
        "glucose_mg_dl"
        not in result["feature_names"]
    )

    assert (
        "trend_target"
        not in result["feature_names"]
    )


def test_training_contains_all_classes():
    records = create_training_records()

    result = train_glucose_trend_model(
        records,
        save_model=False,
    )

    assert set(result["classes"]) == {
        "HIGHER",
        "LOWER",
        "STABLE",
    }


# =========================================================
# MODEL ARTIFACT TEST
# =========================================================

def test_model_artifacts_are_saved(
    tmp_path,
    monkeypatch,
):
    model_path = (
        tmp_path
        / "glucose_trend_xgboost.joblib"
    )

    encoder_path = (
        tmp_path
        / "trend_label_encoder.joblib"
    )

    monkeypatch.setattr(
        training_module,
        "MODEL_DIRECTORY",
        tmp_path,
    )

    monkeypatch.setattr(
        training_module,
        "MODEL_PATH",
        model_path,
    )

    monkeypatch.setattr(
        training_module,
        "LABEL_ENCODER_PATH",
        encoder_path,
    )

    records = create_training_records()

    result = train_glucose_trend_model(
        records,
        save_model=True,
    )

    assert model_path.exists()
    assert encoder_path.exists()

    assert "artifacts" in result

    assert (
        Path(
            result["artifacts"]["model_path"]
        ).exists()
    )

    assert (
        Path(
            result[
                "artifacts"
            ][
                "label_encoder_path"
            ]
        ).exists()
    )
