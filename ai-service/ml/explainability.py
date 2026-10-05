from typing import Dict, List

import numpy as np
import pandas as pd
import shap
from xgboost import XGBClassifier

from ml.future_target_builder import MODEL_FEATURES


def get_feature_importance(
    model: XGBClassifier,
) -> List[Dict]:
    """
    Return the global feature importance values
    learned by the XGBoost model.

    These values describe which features the model
    generally relied on more during training.

    They do not represent medical causation.
    """

    if not hasattr(model, "feature_importances_"):
        raise ValueError(
            "The model does not provide feature importance."
        )

    importances = model.feature_importances_

    if len(importances) != len(MODEL_FEATURES):
        raise ValueError(
            "Model feature importance does not match "
            "the expected DiaMate feature set."
        )

    explanation = []

    for feature, importance in zip(
        MODEL_FEATURES,
        importances,
    ):
        explanation.append(
            {
                "feature": feature,
                "importance": round(
                    float(importance),
                    4,
                ),
            }
        )

    explanation.sort(
        key=lambda item: item["importance"],
        reverse=True,
    )

    return explanation


def explain_prediction(
    model: XGBClassifier,
    top_n: int = 4,
) -> Dict:
    """
    Create a model-level explanation based on
    XGBoost global feature importance.

    This describes the model in general rather than
    explaining one individual prediction.
    """

    if top_n <= 0:
        raise ValueError(
            "top_n must be greater than zero."
        )

    feature_importance = get_feature_importance(
        model
    )

    top_features = feature_importance[:top_n]

    return {
        "method": "xgboost_feature_importance",
        "scope": "global",
        "top_features": top_features,
        "disclaimer": (
            "Feature importance describes which inputs "
            "the experimental model generally relied on "
            "more. It does not establish medical causation."
        ),
    }


def explain_local_prediction(
    model: XGBClassifier,
    dataframe: pd.DataFrame,
    predicted_class_index: int,
    top_n: int = 4,
) -> Dict:
    """
    Explain one individual XGBoost prediction using SHAP.

    SHAP values estimate how each input feature
    contributed to the model output for this specific
    prediction.

    The explanation is experimental and must not be
    interpreted as medical causation or medical advice.
    """

    if top_n <= 0:
        raise ValueError(
            "top_n must be greater than zero."
        )

    if dataframe.empty:
        raise ValueError(
            "Prediction dataframe cannot be empty."
        )

    missing_features = [
        feature
        for feature in MODEL_FEATURES
        if feature not in dataframe.columns
    ]

    if missing_features:
        raise ValueError(
            "Missing SHAP features: "
            + ", ".join(missing_features)
        )

    prediction_data = dataframe[
        MODEL_FEATURES
    ].copy()

    explainer = shap.TreeExplainer(
        model
    )

    shap_values = explainer.shap_values(
        prediction_data
    )

    shap_array = np.asarray(
        shap_values
    )

    # SHAP/XGBoost versions may represent multiclass
    # output in slightly different array layouts.
    #
    # Supported expected layouts include:
    #
    # (samples, features, classes)
    # or
    # (classes, samples, features)
    #
    # We select the SHAP values belonging to the
    # predicted class.

    if shap_array.ndim == 3:
        if (
            shap_array.shape[0]
            == len(prediction_data)
            and shap_array.shape[1]
            == len(MODEL_FEATURES)
        ):
            local_values = shap_array[
                0,
                :,
                predicted_class_index,
            ]

        elif (
            shap_array.shape[1]
            == len(prediction_data)
            and shap_array.shape[2]
            == len(MODEL_FEATURES)
        ):
            local_values = shap_array[
                predicted_class_index,
                0,
                :,
            ]

        else:
            raise ValueError(
                "Unexpected SHAP output shape "
                f"for multiclass prediction: "
                f"{shap_array.shape}"
            )

    elif shap_array.ndim == 2:
        local_values = shap_array[0]

    else:
        raise ValueError(
            "Unexpected SHAP output shape: "
            f"{shap_array.shape}"
        )

    if len(local_values) != len(MODEL_FEATURES):
        raise ValueError(
            "SHAP values do not match the expected "
            "DiaMate feature set."
        )

    contributions = []

    for feature, shap_value in zip(
        MODEL_FEATURES,
        local_values,
    ):
        contributions.append(
            {
                "feature": feature,
                "value": float(
                    prediction_data.iloc[0][feature]
                ),
                "shap_value": round(
                    float(shap_value),
                    4,
                ),
                "absolute_contribution": round(
                    abs(float(shap_value)),
                    4,
                ),
            }
        )

    contributions.sort(
        key=lambda item: item[
            "absolute_contribution"
        ],
        reverse=True,
    )

    return {
        "method": "SHAP",
        "scope": "local",
        "top_contributors": contributions[:top_n],
        "disclaimer": (
            "SHAP values estimate feature contributions "
            "to this specific experimental model output. "
            "They do not establish medical causation and "
            "must not be interpreted as diagnosis, "
            "treatment, or medication advice."
        ),
    }
