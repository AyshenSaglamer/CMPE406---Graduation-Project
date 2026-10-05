import numpy as np
from sklearn.preprocessing import LabelEncoder

import ml.prediction as prediction_module
from ml.prediction import predict_glucose_trend


class FakeModel:
    """
    Small deterministic fake model used only for testing.

    It behaves like a 3-class classifier without loading
    the real XGBoost model from disk.
    """

    feature_importances_ = np.array(
        [
            0.30,
            0.20,
            0.15,
            0.10,
            0.10,
            0.05,
            0.05,
            0.05,
        ]
    )

    def predict(self, dataframe):
        # LabelEncoder order:
        # HIGHER = 0
        # LOWER = 1
        # STABLE = 2
        #
        # We return HIGHER.
        return np.array([0])

    def predict_proba(self, dataframe):
        return np.array(
            [
                [
                    0.80,  # HIGHER
                    0.05,  # LOWER
                    0.15,  # STABLE
                ]
            ]
        )


def valid_features():
    return {
        "glucose_mg_dl": 140.0,
        "previous_glucose": 125.0,
        "carbs_g": 35.0,
        "activity_minutes": 20.0,
        "hour_of_day": 14,
        "day_of_week": 2,
        "month": 10,
        "is_weekend": 0,
    }


def build_encoder():
    encoder = LabelEncoder()

    encoder.fit(
        [
            "LOWER",
            "STABLE",
            "HIGHER",
        ]
    )

    return encoder


def fake_global_explanation(
    model,
    top_n=4,
):
    return {
        "method": "xgboost_feature_importance",
        "top_features": [],
    }


def fake_local_explanation(
    model,
    dataframe,
    predicted_class_index,
    top_n=4,
):
    return {
        "method": "shap",
        "top_features": [],
    }


def run_prediction(monkeypatch):
    """
    Run prediction while replacing the XAI functions.

    Confidence/uncertainty is tested normally.
    SHAP itself is not the subject of these tests.
    """

    monkeypatch.setattr(
        prediction_module,
        "explain_prediction",
        fake_global_explanation,
    )

    monkeypatch.setattr(
        prediction_module,
        "explain_local_prediction",
        fake_local_explanation,
    )

    return predict_glucose_trend(
        features=valid_features(),
        model=FakeModel(),
        encoder=build_encoder(),
    )


def test_prediction_is_preserved(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    assert (
        result["prediction"]
        == "HIGHER"
    )


def test_confidence_is_added(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    assert (
        result["confidence"]["score"]
        == 0.80
    )

    assert (
        result["confidence"]["level"]
        == "HIGH"
    )


def test_uncertainty_is_added(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    assert (
        result["uncertainty"]["score"]
        == 0.20
    )


def test_class_probabilities_are_added(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    assert (
        result["class_probabilities"]
        == {
            "HIGHER": 0.80,
            "LOWER": 0.05,
            "STABLE": 0.15,
        }
    )


def test_old_probabilities_are_preserved(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    assert (
        result["probabilities"]
        == {
            "HIGHER": 0.80,
            "LOWER": 0.05,
            "STABLE": 0.15,
        }
    )


def test_uncertainty_metadata(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    analysis = (
        result[
            "uncertainty_analysis"
        ]
    )

    assert (
        analysis["method"]
        == "maximum_class_probability"
    )

    assert (
        analysis["scope"]
        == "model_prediction_uncertainty"
    )


def test_uncertainty_disclaimer(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    disclaimer = (
        result[
            "uncertainty_analysis"
        ][
            "disclaimer"
        ].lower()
    )

    assert (
        "clinical probability"
        in disclaimer
    )

    assert (
        "diagnosis"
        in disclaimer
    )


def test_safety_metadata(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    safety = result["safety"]

    assert (
        safety[
            "clinical_probability"
        ]
        is False
    )

    assert (
        safety["diagnosis"]
        is False
    )

    assert (
        safety["treatment_advice"]
        is False
    )

    assert (
        safety["medication_guidance"]
        is False
    )


def test_existing_xai_is_preserved(
    monkeypatch,
):
    result = run_prediction(
        monkeypatch
    )

    assert (
        "global"
        in result["explanation"]
    )

    assert (
        "local"
        in result["explanation"]
    )
