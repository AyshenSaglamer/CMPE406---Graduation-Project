from pathlib import Path
from typing import Dict, List, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
)
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

from ml.target_builder import (
    create_ml_dataset,
    split_features_and_target,
)


DEFAULT_TEST_RATIO = 0.20

MODEL_DIRECTORY = (
    Path(__file__).resolve().parent / "models"
)

MODEL_PATH = (
    MODEL_DIRECTORY / "glucose_trend_xgboost.joblib"
)

LABEL_ENCODER_PATH = (
    MODEL_DIRECTORY / "trend_label_encoder.joblib"
)


def chronological_train_test_split(
    X: pd.DataFrame,
    y: pd.Series,
    test_ratio: float = DEFAULT_TEST_RATIO,
) -> Tuple[
    pd.DataFrame,
    pd.DataFrame,
    pd.Series,
    pd.Series,
]:
    """
    Split records chronologically.

    Earlier observations are used for training and
    later observations are used for testing.

    Random splitting is intentionally avoided because
    DiaMate works with time-ordered health records.
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

    if split_index <= 0 or split_index >= len(X):
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


def _encode_targets(
    y_train: pd.Series,
    y_test: pd.Series,
) -> Tuple[
    np.ndarray,
    np.ndarray,
    LabelEncoder,
]:
    """
    Encode textual trend classes as numeric labels
    required by XGBoost.
    """

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


def create_xgboost_classifier(
) -> XGBClassifier:
    """
    Create the DiaMate glucose-trend XGBoost model.

    This model is an experimental pattern-classification
    component and is not used for diagnosis or medication
    dosing.
    """

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
    model: XGBClassifier,
    X_test: pd.DataFrame,
    y_test_encoded: np.ndarray,
    encoder: LabelEncoder,
) -> Dict:
    """
    Evaluate a trained model on the chronological
    holdout set.
    """

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
    model: XGBClassifier,
    encoder: LabelEncoder,
) -> Dict[str, str]:
    """
    Save the trained model and target label encoder.
    """

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
        "model_path": str(MODEL_PATH),
        "label_encoder_path": str(
            LABEL_ENCODER_PATH
        ),
    }


def train_glucose_trend_model(
    records: List[Dict],
    test_ratio: float = DEFAULT_TEST_RATIO,
    save_model: bool = False,
) -> Dict:
    """
    Run the complete experimental training pipeline.

    Steps:
    1. Feature engineering.
    2. Trend-target construction.
    3. Leakage-safe feature/target separation.
    4. Chronological train/test split.
    5. Label encoding.
    6. XGBoost training.
    7. Holdout evaluation.
    8. Optional model persistence.
    """

    dataset = create_ml_dataset(
        records
    )

    X, y = split_features_and_target(
        dataset
    )

    (
        X_train,
        X_test,
        y_train,
        y_test,
    ) = chronological_train_test_split(
        X,
        y,
        test_ratio=test_ratio,
    )

    # All three classes should be represented in the
    # training data before fitting this multiclass model.
    required_classes = {
        "LOWER",
        "STABLE",
        "HIGHER",
    }

    training_classes = set(
        y_train.unique()
    )

    missing_classes = (
        required_classes - training_classes
    )

    if missing_classes:
        raise ValueError(
            "Training data must contain all trend "
            "classes: LOWER, STABLE, and HIGHER."
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
        "training_sample_size": int(
            len(X_train)
        ),
        "test_sample_size": int(
            len(X_test)
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
