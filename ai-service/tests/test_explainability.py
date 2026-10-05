import numpy as np
import pytest

from ml.explainability import (
    explain_prediction,
    get_feature_importance,
)
from ml.future_target_builder import MODEL_FEATURES


class FakeXGBoostModel:
    def __init__(self):
        self.feature_importances_ = np.array(
            [
                0.20,
                0.25,
                0.15,
                0.10,
                0.12,
                0.08,
                0.06,
                0.04,
            ]
        )


def test_get_feature_importance_returns_all_features():
    model = FakeXGBoostModel()

    result = get_feature_importance(model)

    assert len(result) == len(MODEL_FEATURES)

    returned_features = {
        item["feature"]
        for item in result
    }

    assert returned_features == set(MODEL_FEATURES)


def test_feature_importance_is_sorted_highest_first():
    model = FakeXGBoostModel()

    result = get_feature_importance(model)

    importances = [
        item["importance"]
        for item in result
    ]

    assert importances == sorted(
        importances,
        reverse=True,
    )


def test_explain_prediction_returns_top_features():
    model = FakeXGBoostModel()

    result = explain_prediction(
        model,
        top_n=3,
    )

    assert (
        result["method"]
        == "xgboost_feature_importance"
    )

    assert len(result["top_features"]) == 3

    assert (
        result["top_features"][0]["feature"]
        == "previous_glucose"
    )


def test_explain_prediction_contains_disclaimer():
    model = FakeXGBoostModel()

    result = explain_prediction(model)

    assert "disclaimer" in result
    assert "causation" in result["disclaimer"]


def test_explain_prediction_rejects_invalid_top_n():
    model = FakeXGBoostModel()

    with pytest.raises(
        ValueError,
        match="top_n must be greater than zero",
    ):
        explain_prediction(
            model,
            top_n=0,
        )


def test_feature_importance_rejects_wrong_feature_count():
    model = FakeXGBoostModel()

    model.feature_importances_ = np.array(
        [0.5, 0.5]
    )

    with pytest.raises(
        ValueError,
        match="does not match",
    ):
        get_feature_importance(model)
