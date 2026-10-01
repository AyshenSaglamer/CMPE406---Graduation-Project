import numpy as np
import pytest
from sklearn.preprocessing import LabelEncoder

from ml.prediction import (
    MODEL_FEATURES,
    _validate_prediction_features,
    load_model_artifacts,
    predict_glucose_trend,
)


# =========================================================
# FAKE MODEL
# =========================================================

class FakeXGBoostModel:
    """
    Lightweight test double for prediction tests.

    No real XGBoost model needs to be trained during
    these unit tests.
    """

    def predict(self, dataframe):
        # LabelEncoder classes:
        # HIGHER = 0
        # LOWER = 1
        # STABLE = 2
        return np.array([0])

    def predict_proba(self, dataframe):
        return np.array(
            [
                [
                    0.70,
                    0.10,
                    0.20,
                ]
            ]
        )


# =========================================================
# FIXTURES
# =========================================================

@pytest.fixture
def encoder():
    label_encoder = LabelEncoder()

    label_encoder.fit(
        [
            "HIGHER",
            "LOWER",
            "STABLE",
        ]
    )

    return label_encoder


@pytest.fixture
def valid_features():
    return {
        "glucose_mg_dl": 135,
        "previous_glucose": 120,
        "carbs_g": 40,
        "activity_minutes": 30,
        "hour_of_day": 14,
        "day_of_week": 2,
        "month": 9,
        "is_weekend": 0,
    }


# =========================================================
# FEATURE CONTRACT
# =========================================================

def test_model_features_are_expected():
    assert MODEL_FEATURES == [
        "glucose_mg_dl",
        "previous_glucose",
        "carbs_g",
        "activity_minutes",
        "hour_of_day",
        "day_of_week",
        "month",
        "is_weekend",
    ]


def test_valid_features_are_accepted(
    valid_features,
):
    dataframe = (
        _validate_prediction_features(
            valid_features
        )
    )

    assert len(dataframe) == 1

    assert list(dataframe.columns) == (
        MODEL_FEATURES
    )


# =========================================================
# PREDICTION
# =========================================================

def test_predict_glucose_trend(
    valid_features,
    encoder,
):
    model = FakeXGBoostModel()

    result = predict_glucose_trend(
        valid_features,
        model,
        encoder,
    )

    assert result["prediction"] == "HIGHER"

    assert (
        result["model_type"]
        == "XGBoost"
    )

    assert (
        result["prediction_target"]
        == "next_glucose_trend"
    )

    assert result["purpose"] == (
        "experimental_future_glucose_"
        "trend_classification"
    )


def test_prediction_probabilities(
    valid_features,
    encoder,
):
    model = FakeXGBoostModel()

    result = predict_glucose_trend(
        valid_features,
        model,
        encoder,
    )

    probabilities = result[
        "probabilities"
    ]

    assert probabilities["HIGHER"] == 0.70
    assert probabilities["LOWER"] == 0.10
    assert probabilities["STABLE"] == 0.20


def test_probability_sum(
    valid_features,
    encoder,
):
    model = FakeXGBoostModel()

    result = predict_glucose_trend(
        valid_features,
        model,
        encoder,
    )

    total = sum(
        result["probabilities"].values()
    )

    assert total == pytest.approx(
        1.0,
        abs=0.0001,
    )


def test_prediction_returns_current_glucose(
    valid_features,
    encoder,
):
    model = FakeXGBoostModel()

    result = predict_glucose_trend(
        valid_features,
        model,
        encoder,
    )

    assert (
        result["features"][
            "glucose_mg_dl"
        ]
        == 135.0
    )

    assert (
        result["features"][
            "previous_glucose"
        ]
        == 120.0
    )


# =========================================================
# MISSING FEATURES
# =========================================================

@pytest.mark.parametrize(
    "missing_feature",
    MODEL_FEATURES,
)
def test_missing_feature_rejected(
    valid_features,
    missing_feature,
):
    features = valid_features.copy()

    features.pop(
        missing_feature
    )

    with pytest.raises(
        ValueError,
        match="Missing prediction features",
    ):
        _validate_prediction_features(
            features
        )


# =========================================================
# NUMERIC VALIDATION
# =========================================================

def test_non_numeric_glucose_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["glucose_mg_dl"] = "hello"

    with pytest.raises(
        ValueError,
        match="glucose_mg_dl must be numeric",
    ):
        _validate_prediction_features(
            features
        )


def test_non_numeric_carbs_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["carbs_g"] = "hello"

    with pytest.raises(
        ValueError,
        match="carbs_g must be numeric",
    ):
        _validate_prediction_features(
            features
        )


def test_infinite_feature_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["activity_minutes"] = np.inf

    with pytest.raises(
        ValueError,
        match=(
            "activity_minutes must be finite"
        ),
    ):
        _validate_prediction_features(
            features
        )


# =========================================================
# GLUCOSE VALIDATION
# =========================================================

def test_zero_current_glucose_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["glucose_mg_dl"] = 0

    with pytest.raises(
        ValueError,
        match=(
            "glucose_mg_dl must be "
            "greater than zero"
        ),
    ):
        _validate_prediction_features(
            features
        )


def test_negative_current_glucose_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["glucose_mg_dl"] = -1

    with pytest.raises(
        ValueError,
        match=(
            "glucose_mg_dl must be "
            "greater than zero"
        ),
    ):
        _validate_prediction_features(
            features
        )


def test_zero_previous_glucose_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["previous_glucose"] = 0

    with pytest.raises(
        ValueError,
        match=(
            "previous_glucose must be "
            "greater than zero"
        ),
    ):
        _validate_prediction_features(
            features
        )


# =========================================================
# OTHER DOMAIN VALIDATION
# =========================================================

def test_negative_carbs_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["carbs_g"] = -1

    with pytest.raises(
        ValueError,
        match="carbs_g cannot be negative",
    ):
        _validate_prediction_features(
            features
        )


def test_negative_activity_rejected(
    valid_features,
):
    features = valid_features.copy()

    features["activity_minutes"] = -1

    with pytest.raises(
        ValueError,
        match=(
            "activity_minutes cannot "
            "be negative"
        ),
    ):
        _validate_prediction_features(
            features
        )


@pytest.mark.parametrize(
    "hour",
    [-1, 24],
)
def test_invalid_hour_rejected(
    valid_features,
    hour,
):
    features = valid_features.copy()

    features["hour_of_day"] = hour

    with pytest.raises(
        ValueError,
        match=(
            "hour_of_day must be between "
            "0 and 23"
        ),
    ):
        _validate_prediction_features(
            features
        )


@pytest.mark.parametrize(
    "day",
    [-1, 7],
)
def test_invalid_day_rejected(
    valid_features,
    day,
):
    features = valid_features.copy()

    features["day_of_week"] = day

    with pytest.raises(
        ValueError,
        match=(
            "day_of_week must be between "
            "0 and 6"
        ),
    ):
        _validate_prediction_features(
            features
        )


@pytest.mark.parametrize(
    "month",
    [0, 13],
)
def test_invalid_month_rejected(
    valid_features,
    month,
):
    features = valid_features.copy()

    features["month"] = month

    with pytest.raises(
        ValueError,
        match=(
            "month must be between "
            "1 and 12"
        ),
    ):
        _validate_prediction_features(
            features
        )


@pytest.mark.parametrize(
    "weekend",
    [-1, 2],
)
def test_invalid_weekend_rejected(
    valid_features,
    weekend,
):
    features = valid_features.copy()

    features["is_weekend"] = weekend

    with pytest.raises(
        ValueError,
        match=(
            "is_weekend must be either "
            "0 or 1"
        ),
    ):
        _validate_prediction_features(
            features
        )


# =========================================================
# FUTURE-DATA LEAKAGE PROTECTION
# =========================================================

def test_future_information_is_not_model_feature():
    forbidden_features = {
        "next_glucose",
        "future_glucose_change",
        "trend_target",
        "patient_id",
        "timestamp",
    }

    for feature in forbidden_features:
        assert feature not in MODEL_FEATURES


# =========================================================
# ARTIFACT LOADING
# =========================================================

def test_missing_model_file_rejected(
    tmp_path,
):
    missing_model = (
        tmp_path
        / "missing_model.joblib"
    )

    missing_encoder = (
        tmp_path
        / "missing_encoder.joblib"
    )

    with pytest.raises(
        FileNotFoundError,
        match="Model file not found",
    ):
        load_model_artifacts(
            model_path=missing_model,
            encoder_path=missing_encoder,
        )


def test_missing_encoder_file_rejected(
    tmp_path,
):
    model_path = (
        tmp_path
        / "model.joblib"
    )

    model_path.touch()

    missing_encoder = (
        tmp_path
        / "missing_encoder.joblib"
    )

    with pytest.raises(
        FileNotFoundError,
        match="Label encoder file not found",
    ):
        load_model_artifacts(
            model_path=model_path,
            encoder_path=missing_encoder,
        )
