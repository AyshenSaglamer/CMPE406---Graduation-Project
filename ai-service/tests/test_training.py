from pathlib import Path

import pandas as pd
import pytest

import ml.training as training_module
from ml.future_target_builder import MODEL_FEATURES
from ml.training import (
    chronological_train_test_split,
    create_xgboost_classifier,
    patient_temporal_train_test_split,
    train_glucose_trend_model,
)


# =========================================================
# TEST DATA
# =========================================================

def create_training_records():
    """
    Deterministic synthetic multi-patient records.

    Used only to test the DiaMate ML software pipeline.
    These records are not clinical data.
    """

    records = []

    # Repeating changes deliberately create:
    # HIGHER, STABLE and LOWER future targets.
    patterns = {
        "patient_a": [
            100, 130, 135, 105, 140, 145, 110,
            150, 155, 120, 160, 165, 130,
            170, 175, 140, 180, 185, 150,
            190, 195, 160, 200, 205, 170,
        ],
        "patient_b": [
            160, 125, 130, 170, 175, 140, 180,
            185, 150, 190, 195, 160, 200,
            205, 170, 210, 215, 180, 220,
            225, 190, 230, 235, 200, 240,
        ],
    }

    for patient_number, (
        patient_id,
        glucose_pattern,
    ) in enumerate(patterns.items()):

        start_time = pd.Timestamp(
            "2026-01-01 08:00:00"
        )

        for index, glucose in enumerate(
            glucose_pattern
        ):
            timestamp = (
                start_time
                + pd.Timedelta(hours=index * 4)
            )

            records.append(
                {
                    "patient_id": patient_id,
                    "timestamp": timestamp.isoformat(),
                    "glucose_mg_dl": glucose,
                    "carbs_g": (
                        20
                        + ((index + patient_number) % 5)
                        * 10
                    ),
                    "activity_minutes": (
                        (
                            index
                            + patient_number
                        )
                        % 4
                    )
                    * 10,
                }
            )

    return records


# =========================================================
# LEGACY ORDERED SPLIT HELPER
# =========================================================

def test_chronological_train_test_split():
    X = pd.DataFrame(
        {
            "value": list(range(10)),
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

    assert list(
        X_train["value"]
    ) == list(range(8))

    assert list(
        X_test["value"]
    ) == [8, 9]


def test_chronological_split_rejects_bad_ratio():
    X = pd.DataFrame(
        {"value": list(range(10))}
    )

    y = pd.Series(
        ["STABLE"] * 10
    )

    with pytest.raises(
        ValueError,
        match="Test ratio must be between 0 and 1",
    ):
        chronological_train_test_split(
            X,
            y,
            test_ratio=1,
        )


# =========================================================
# PATIENT TEMPORAL SPLIT
# =========================================================

def create_temporal_dataset():
    rows = []

    for patient_id in [
        "patient_a",
        "patient_b",
    ]:
        for index in range(10):
            rows.append(
                {
                    "patient_id": patient_id,
                    "timestamp": (
                        pd.Timestamp(
                            "2026-01-01 08:00:00"
                        )
                        + pd.Timedelta(
                            hours=index * 4
                        )
                    ),
                    "glucose_mg_dl": (
                        100 + index
                    ),
                    "previous_glucose": (
                        99 + index
                    ),
                    "carbs_g": 30,
                    "activity_minutes": 20,
                    "hour_of_day": (
                        (8 + index * 4) % 24
                    ),
                    "day_of_week": 3,
                    "month": 1,
                    "is_weekend": 0,
                    "trend_target": (
                        "STABLE"
                    ),
                }
            )

    return pd.DataFrame(rows)


def test_patient_temporal_split():
    dataset = create_temporal_dataset()

    (
        train_dataset,
        test_dataset,
    ) = patient_temporal_train_test_split(
        dataset,
        test_ratio=0.2,
    )

    for patient_id in [
        "patient_a",
        "patient_b",
    ]:
        patient_train = train_dataset[
            train_dataset["patient_id"]
            == patient_id
        ]

        patient_test = test_dataset[
            test_dataset["patient_id"]
            == patient_id
        ]

        assert len(patient_train) == 8
        assert len(patient_test) == 2


def test_patient_temporal_split_preserves_time():
    dataset = create_temporal_dataset()

    (
        train_dataset,
        test_dataset,
    ) = patient_temporal_train_test_split(
        dataset,
        test_ratio=0.2,
    )

    for patient_id in [
        "patient_a",
        "patient_b",
    ]:
        patient_train = train_dataset[
            train_dataset["patient_id"]
            == patient_id
        ]

        patient_test = test_dataset[
            test_dataset["patient_id"]
            == patient_id
        ]

        assert (
            patient_train["timestamp"].max()
            <
            patient_test["timestamp"].min()
        )


def test_patient_temporal_split_rejects_empty():
    with pytest.raises(
        ValueError,
        match="ML dataset cannot be empty",
    ):
        patient_temporal_train_test_split(
            pd.DataFrame()
        )


def test_patient_temporal_split_rejects_bad_ratio():
    dataset = create_temporal_dataset()

    with pytest.raises(
        ValueError,
        match="Test ratio must be between 0 and 1",
    ):
        patient_temporal_train_test_split(
            dataset,
            test_ratio=0,
        )


# =========================================================
# XGBOOST
# =========================================================

def test_xgboost_classifier_created():
    model = create_xgboost_classifier()

    assert model is not None

    params = model.get_params()

    assert (
        params["objective"]
        == "multi:softprob"
    )

    assert params["n_estimators"] == 100
    assert params["random_state"] == 42


# =========================================================
# COMPLETE FUTURE TRAINING PIPELINE
# =========================================================

def test_train_future_glucose_trend_model():
    result = train_glucose_trend_model(
        create_training_records(),
        test_ratio=0.2,
        save_model=False,
    )

    assert result["status"] == "trained"

    assert (
        result["prediction_target"]
        == "next_glucose_trend"
    )

    assert result["patient_count"] == 2

    assert (
        result["training_sample_size"]
        > 0
    )

    assert result["test_sample_size"] > 0

    assert "metrics" in result

    assert (
        0.0
        <= result["metrics"]["accuracy"]
        <= 1.0
    )


def test_training_uses_future_model_features():
    result = train_glucose_trend_model(
        create_training_records(),
        save_model=False,
    )

    assert (
        result["feature_names"]
        == MODEL_FEATURES
    )

    # Current glucose is valid at time t.
    assert (
        "glucose_mg_dl"
        in result["feature_names"]
    )


def test_future_information_is_not_used_for_training():
    result = train_glucose_trend_model(
        create_training_records(),
        save_model=False,
    )

    forbidden = {
        "next_glucose",
        "future_glucose_change",
        "trend_target",
        "patient_id",
        "timestamp",
    }

    for column in forbidden:
        assert (
            column
            not in result["feature_names"]
        )


def test_training_contains_all_classes():
    result = train_glucose_trend_model(
        create_training_records(),
        save_model=False,
    )

    assert set(result["classes"]) == {
        "HIGHER",
        "LOWER",
        "STABLE",
    }


# =========================================================
# ARTIFACT PERSISTENCE
# =========================================================

def test_future_model_artifacts_are_saved(
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

    result = train_glucose_trend_model(
        create_training_records(),
        save_model=True,
    )

    assert model_path.exists()
    assert encoder_path.exists()

    assert "artifacts" in result

    assert Path(
        result[
            "artifacts"
        ]["model_path"]
    ).exists()

    assert Path(
        result[
            "artifacts"
        ]["label_encoder_path"]
    ).exists()
