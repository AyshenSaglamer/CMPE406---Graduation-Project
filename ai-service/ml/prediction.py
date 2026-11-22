from pathlib import Path
from typing import Dict, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

from ml.explainability import (
    explain_local_prediction,
    explain_prediction,
)
from ml.future_target_builder import MODEL_FEATURES
from ml.training import (
    LABEL_ENCODER_PATH,
    MODEL_PATH,
)
from ml.uncertainty import (
    calculate_prediction_uncertainty,
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

    The response includes:

    1. Predicted glucose-trend class.
    2. Class probabilities.
    3. Descriptive model confidence and uncertainty.
    4. Global XGBoost feature importance.
    5. Local SHAP explanation for this prediction.

    Confidence and uncertainty describe model behaviour
    only. They are not clinical probabilities.

    This is an experimental pattern-classification
    feature. It does not provide diagnosis, treatment,
    clinical-risk estimation, or medication-dosing
    recommendations.
    """

    # ========================================================
    # VALIDATE INPUT FEATURES
    # ========================================================

    dataframe = _validate_prediction_features(
        features
    )

    # ========================================================
    # MODEL PREDICTION
    # ========================================================

    prediction_encoded = model.predict(
        dataframe
    )

    probabilities = model.predict_proba(
        dataframe
    )

    predicted_class_index = int(
        prediction_encoded[0]
    )

    predicted_class = encoder.inverse_transform(
        prediction_encoded.astype(int)
    )[0]

    # ========================================================
    # CLASS PROBABILITIES
    # ========================================================

    probability_values = [
        float(value)
        for value in probabilities[0]
    ]

    class_names = [
        str(class_name)
        for class_name in encoder.classes_
    ]

    class_probabilities = {
        class_name: round(
            probability,
            6,
        )
        for class_name, probability in zip(
            class_names,
            probability_values,
        )
    }

    # ========================================================
    # CONFIDENCE & UNCERTAINTY
    # ========================================================

    uncertainty_analysis = (
        calculate_prediction_uncertainty(
            probabilities=probability_values,
            class_names=class_names,
        )
    )

    # Defensive consistency check:
    # model.predict() and the maximum probability should
    # identify the same class.
    if (
        uncertainty_analysis["predicted_class"]
        != str(predicted_class)
    ):
        raise ValueError(
            "Model prediction is inconsistent with "
            "the class-probability distribution."
        )

    # ========================================================
    # GLOBAL EXPLAINABLE AI
    # ========================================================

    global_explanation = explain_prediction(
        model,
        top_n=4,
    )

    # ========================================================
    # LOCAL EXPLAINABLE AI / SHAP
    # ========================================================

    local_explanation = explain_local_prediction(
        model=model,
        dataframe=dataframe,
        predicted_class_index=predicted_class_index,
        top_n=4,
    )

    # ========================================================
    # FINAL RESPONSE
    # ========================================================

    return {
        "prediction": str(
            predicted_class
        ),

        # Kept for backward compatibility with the
        # existing DiaMate prediction response.
        "probabilities": (
            class_probabilities
        ),

        "confidence": (
            uncertainty_analysis[
                "confidence"
            ]
        ),

        "uncertainty": (
            uncertainty_analysis[
                "uncertainty"
            ]
        ),

        "class_probabilities": (
            uncertainty_analysis[
                "class_probabilities"
            ]
        ),

        "uncertainty_analysis": {
            "method": (
                uncertainty_analysis[
                    "method"
                ]
            ),
            "scope": (
                uncertainty_analysis[
                    "scope"
                ]
            ),
            "disclaimer": (
                uncertainty_analysis[
                    "disclaimer"
                ]
            ),
        },

        "features": {
            feature: float(
                dataframe.iloc[0][feature]
            )
            for feature in MODEL_FEATURES
        },

        "explanation": {
            "global": (
                global_explanation
            ),
            "local": (
                local_explanation
            ),
        },

        "model_type": "XGBoost",

        "prediction_target": (
            "next_glucose_trend"
        ),

        "purpose": (
            "experimental_future_glucose_"
            "trend_classification"
        ),

        "safety": {
            "clinical_probability": False,
            "diagnosis": False,
            "treatment_advice": False,
            "medication_guidance": False,
            "message": (
                "Prediction confidence and uncertainty "
                "describe the experimental model's output "
                "distribution only. They must not be "
                "interpreted as clinical probability, "
                "diagnosis, medical risk, treatment advice, "
                "or medication guidance."
            ),
        },
    }


def predict_with_saved_model(
    features: Dict,
    model_path: Path = MODEL_PATH,
    encoder_path: Path = LABEL_ENCODER_PATH,
) -> Dict:
    """
    Load the saved model and use it to classify
    the future glucose trend.
    """

    model, encoder = load_model_artifacts(
        model_path=model_path,
        encoder_path=encoder_path,
    )

    return predict_glucose_trend(
        features,
        model,
        encoder,
    )
