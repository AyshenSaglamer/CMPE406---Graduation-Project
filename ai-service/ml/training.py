from pathlib import Path
from typing import Dict, List

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
)
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

from ml.future_target_builder import (
    create_future_trend_dataset,
    split_future_features_and_target,
)


DEFAULT_TEST_RATIO = 0.20

MODEL_DIRECTORY = (
    Path(__file__).resolve().parent / "models"
)

MODEL_PATH = (
    MODEL_DIRECTORY
    / "glucose_trend_xgboost.joblib"
)

LABEL_ENCODER_PATH = (
    MODEL_DIRECTORY
    / "trend_label_encoder.joblib"
)


def chronological_train_test_split(
    X: pd.DataFrame,
    y: pd.Series,
    test_ratio: float = DEFAULT_TEST_RATIO,
):
    """
    Split already chronologically ordered data
    without random shuffling.

    This helper is retained for simple ordered
    datasets and unit tests.
    """

    if len(X) != len(y):
        raise ValueError(
            "Features and target must contain "
            "the same number of rows."
        )

    if len(X) < 5:
        raise ValueError(
            "At least five ML records are required "
            "for train/test splitting."
        )

    if not 0 < test_ratio < 1:
        raise ValueError(
            "Test ratio must be between 0 and 1."
        )

    split_index = int(
        len(X) * (1 - test_ratio)
    )

    if (
        split_index <= 0
        or split_index >= len(X)
    ):
        raise ValueError(
            "Test ratio produces an invalid "
            "train/test split."
        )

    X_train = (
        X.iloc[:split_index]
        .copy()
        .reset_index(drop=True)
    )

    X_test = (
        X.iloc[split_index:]
        .copy()
        .reset_index(drop=True)
    )

    y_train = (
        y.iloc[:split_index]
        .copy()
        .reset_index(drop=True)
    )

    y_test = (
        y.iloc[split_index:]
        .copy()
        .reset_index(drop=True)
    )

    return (
        X_train,
        X_test,
        y_train,
        y_test,
    )


def patient_temporal_train_test_split(
    dataset: pd.DataFrame,
    test_ratio: float = DEFAULT_TEST_RATIO,
):
    """
    Split each patient's records independently.

    Earlier records from each patient are used for
    training and later records for testing.

    This prevents Patient A's ordering from affecting
    Patient B's temporal split.
    """

    if dataset.empty:
        raise ValueError(
            "ML dataset cannot be empty."
        )

    required_columns = {
        "patient_id",
        "timestamp",
        "trend_target",
    }

    missing_columns = (
        required_columns
        - set(dataset.columns)
    )

    if missing_columns:
        raise ValueError(
            "ML dataset is missing required "
            "temporal columns: "
            + ", ".join(
                sorted(missing_columns)
            )
        )

    if not 0 < test_ratio < 1:
        raise ValueError(
            "Test ratio must be between 0 and 1."
        )

    train_frames = []
    test_frames = []

    for _, patient_data in dataset.groupby(
        "patient_id"
    ):
        patient_data = (
            patient_data
            .sort_values("timestamp")
            .reset_index(drop=True)
        )

        if len(patient_data) < 2:
            raise ValueError(
                "Each patient must have at least "
                "two usable ML records for "
                "temporal splitting."
            )

        split_index = int(
            len(patient_data)
            * (1 - test_ratio)
        )

        # Keep at least one record on each side.
        split_index = max(
            1,
            min(
                split_index,
                len(patient_data) - 1,
            ),
        )

        train_frames.append(
            patient_data.iloc[
                :split_index
            ].copy()
        )

        test_frames.append(
            patient_data.iloc[
                split_index:
            ].copy()
        )

    train_dataset = (
        pd.concat(
            train_frames,
            ignore_index=True,
        )
        .sort_values(
            [
                "timestamp",
                "patient_id",
            ]
        )
        .reset_index(drop=True)
    )

    test_dataset = (
        pd.concat(
            test_frames,
            ignore_index=True,
        )
        .sort_values(
            [
                "timestamp",
                "patient_id",
            ]
        )
        .reset_index(drop=True)
    )

    return (
        train_dataset,
        test_dataset,
    )


def _encode_targets(
    y_train,
    y_test,
):
    encoder = LabelEncoder()

    encoder.fit(
        [
            "HIGHER",
            "LOWER",
            "STABLE",
        ]
    )

    y_train_encoded = encoder.transform(
        y_train
    )

    y_test_encoded = encoder.transform(
        y_test
    )

    return (
        y_train_encoded,
        y_test_encoded,
        encoder,
    )


def create_xgboost_classifier():
    return XGBClassifier(
        objective="multi:softprob",
        num_class=3,
        n_estimators=100,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        eval_metric="mlogloss",
    )


def evaluate_model(
    model,
    X_test,
    y_test_encoded,
    encoder,
):
    predictions = model.predict(
        X_test
    )

    accuracy = accuracy_score(
        y_test_encoded,
        predictions,
    )

    labels = np.arange(
        len(encoder.classes_)
    )

    report = classification_report(
        y_test_encoded,
        predictions,
        labels=labels,
        target_names=encoder.classes_,
        output_dict=True,
        zero_division=0,
    )

    return {
        "accuracy": round(
            float(accuracy),
            4,
        ),
        "classification_report": report,
        "test_sample_size": int(
            len(X_test)
        ),
    }


def save_model_artifacts(
    model,
    encoder,
):
    MODEL_DIRECTORY.mkdir(
        parents=True,
        exist_ok=True,
    )

    joblib.dump(
        model,
        MODEL_PATH,
    )

    joblib.dump(
        encoder,
        LABEL_ENCODER_PATH,
    )

    return {
        "model_path": str(
            MODEL_PATH
        ),
        "label_encoder_path": str(
            LABEL_ENCODER_PATH
        ),
    }


def train_glucose_trend_model(
    records: List[Dict],
    test_ratio: float = DEFAULT_TEST_RATIO,
    save_model: bool = False,
):
    """
    Train the experimental DiaMate future glucose
    trend classifier.

    Features from time t are used to classify the
    direction of the patient's next glucose reading.

    This model is for experimental pattern analysis,
    not diagnosis, medication dosing, or treatment
    recommendations.
    """

    dataset = create_future_trend_dataset(
        records
    )

    (
        train_dataset,
        test_dataset,
    ) = patient_temporal_train_test_split(
        dataset,
        test_ratio=test_ratio,
    )

    X_train, y_train = (
        split_future_features_and_target(
            train_dataset
        )
    )

    X_test, y_test = (
        split_future_features_and_target(
            test_dataset
        )
    )

    required_classes = {
        "LOWER",
        "STABLE",
        "HIGHER",
    }

    training_classes = set(
        y_train.unique()
    )

    missing_classes = (
        required_classes
        - training_classes
    )

    if missing_classes:
        raise ValueError(
            "Training data must contain all "
            "trend classes: LOWER, STABLE, "
            "and HIGHER."
        )

    (
        y_train_encoded,
        y_test_encoded,
        encoder,
    ) = _encode_targets(
        y_train,
        y_test,
    )

    model = create_xgboost_classifier()

    model.fit(
        X_train,
        y_train_encoded,
    )

    metrics = evaluate_model(
        model,
        X_test,
        y_test_encoded,
        encoder,
    )

    result = {
        "status": "trained",
        "prediction_target": (
            "next_glucose_trend"
        ),
        "training_sample_size": int(
            len(X_train)
        ),
        "test_sample_size": int(
            len(X_test)
        ),
        "patient_count": int(
            dataset["patient_id"].nunique()
        ),
        "feature_names": list(
            X_train.columns
        ),
        "classes": list(
            encoder.classes_
        ),
        "metrics": metrics,
    }

    if save_model:
        result["artifacts"] = (
            save_model_artifacts(
                model,
                encoder,
            )
        )

    return result
