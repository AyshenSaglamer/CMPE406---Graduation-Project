from pathlib import Path
from typing import Dict, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

from ml.future_target_builder import MODEL_FEATURES
from ml.training import (
    LABEL_ENCODER_PATH,
    MODEL_PATH,
)


def load_model_artifacts(
    model_path: Path = MODEL_PATH,
    encoder_path: Path = LABEL_ENCODER_PATH,
) -> Tuple[XGBClassifier, LabelEncoder]:
    """
    Load the trained XGBoost model and label encoder.
    """

    model_path = Path(model_path)
    encoder_path = Path(encoder_path)

    if not model_path.exists():
        raise FileNotFoundError(
            f"Model file not found: {model_path}"
        )

    if not encoder_path.exists():
        raise FileNotFoundError(
            f"Label encoder file not found: {encoder_path}"
        )

    model = joblib.load(model_path)
    encoder = joblib.load(encoder_path)

    return model, encoder


def _validate_prediction_features(
    features: Dict,
) -> pd.DataFrame:
    """
    Validate one future-trend prediction input.

    Only information available at time t is accepted.
    Future glucose information must never be included.
    """

    missing_features = [
        feature
        for feature in MODEL_FEATURES
        if feature not in features
    ]

    if missing_features:
        raise ValueError(
            "Missing prediction features: "
            + ", ".join(missing_features)
        )

    dataframe = pd.DataFrame(
        [
            {
                feature: features[feature]
                for feature in MODEL_FEATURES
            }
        ]
    )

    for feature in MODEL_FEATURES:
        dataframe[feature] = pd.to_numeric(
            dataframe[feature],
            errors="coerce",
        )

        if dataframe[feature].isna().any():
            raise ValueError(
                f"{feature} must be numeric."
            )

        values = dataframe[
            feature
        ].to_numpy(dtype=float)

        if not np.isfinite(values).all():
            raise ValueError(
                f"{feature} must be finite."
            )

    if dataframe["glucose_mg_dl"].iloc[0] <= 0:
        raise ValueError(
            "glucose_mg_dl must be greater than zero."
        )

    if dataframe["previous_glucose"].iloc[0] <= 0:
        raise ValueError(
            "previous_glucose must be greater than zero."
        )

    if dataframe["carbs_g"].iloc[0] < 0:
        raise ValueError(
            "carbs_g cannot be negative."
        )

    if dataframe["activity_minutes"].iloc[0] < 0:
        raise ValueError(
            "activity_minutes cannot be negative."
        )

    hour = dataframe["hour_of_day"].iloc[0]

    if not 0 <= hour <= 23:
        raise ValueError(
            "hour_of_day must be between 0 and 23."
        )

    day = dataframe["day_of_week"].iloc[0]

    if not 0 <= day <= 6:
        raise ValueError(
            "day_of_week must be between 0 and 6."
        )

    month = dataframe["month"].iloc[0]

    if not 1 <= month <= 12:
        raise ValueError(
            "month must be between 1 and 12."
        )

    weekend = dataframe["is_weekend"].iloc[0]

    if weekend not in (0, 1):
        raise ValueError(
            "is_weekend must be either 0 or 1."
        )

    return dataframe


def predict_glucose_trend(
    features: Dict,
    model: XGBClassifier,
    encoder: LabelEncoder,
) -> Dict:
    """
    Classify the direction of the patient's next
    glucose reading.

    This is an experimental pattern-classification
    feature. It does not provide diagnosis, treatment,
    or medication-dosing recommendations.
    """

    dataframe = _validate_prediction_features(
        features
    )

    prediction_encoded = model.predict(
        dataframe
    )

    probabilities = model.predict_proba(
        dataframe
    )

    predicted_class = encoder.inverse_transform(
        prediction_encoded.astype(int)
    )[0]

    class_probabilities = {}

    for index, class_name in enumerate(
        encoder.classes_
    ):
        class_probabilities[
            str(class_name)
        ] = round(
            float(probabilities[0][index]),
            4,
        )

    return {
        "prediction": str(predicted_class),
        "probabilities": class_probabilities,
        "features": {
            feature: float(
                dataframe.iloc[0][feature]
            )
            for feature in MODEL_FEATURES
        },
        "model_type": "XGBoost",
        "prediction_target": "next_glucose_trend",
        "purpose": (
            "experimental_future_glucose_"
            "trend_classification"
        ),
    }


def predict_with_saved_model(
    features: Dict,
    model_path: Path = MODEL_PATH,
    encoder_path: Path = LABEL_ENCODER_PATH,
) -> Dict:
    model, encoder = load_model_artifacts(
        model_path=model_path,
        encoder_path=encoder_path,
    )

    return predict_glucose_trend(
        features,
        model,
        encoder,
    )
