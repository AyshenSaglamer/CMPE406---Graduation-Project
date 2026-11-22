import pytest

from ml.uncertainty import (
    calculate_prediction_uncertainty,
)


CLASS_NAMES = [
    "LOWER",
    "STABLE",
    "HIGHER",
]


def test_returns_predicted_class():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.10,
            0.20,
            0.70,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["predicted_class"]
        == "HIGHER"
    )


def test_returns_confidence_score():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.10,
            0.20,
            0.70,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["confidence"]["score"]
        == pytest.approx(0.70)
    )


def test_returns_uncertainty_score():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.10,
            0.20,
            0.70,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["uncertainty"]["score"]
        == pytest.approx(0.30)
    )


def test_returns_class_probabilities():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.10,
            0.20,
            0.70,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["class_probabilities"]
        == {
            "LOWER": 0.10,
            "STABLE": 0.20,
            "HIGHER": 0.70,
        }
    )


def test_high_confidence_level():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.05,
            0.10,
            0.85,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["confidence"]["level"]
        == "HIGH"
    )


def test_moderate_confidence_level():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.20,
            0.20,
            0.60,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["confidence"]["level"]
        == "MODERATE"
    )


def test_low_confidence_level():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.34,
            0.33,
            0.33,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["confidence"]["level"]
        == "LOW"
    )


def test_probabilities_must_sum_to_one():
    with pytest.raises(
        ValueError,
        match="sum to 1",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                0.20,
                0.20,
                0.20,
            ],
            class_names=CLASS_NAMES,
        )


def test_negative_probability_is_rejected():
    with pytest.raises(
        ValueError,
        match="between 0 and 1",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                -0.10,
                0.40,
                0.70,
            ],
            class_names=CLASS_NAMES,
        )


def test_probability_above_one_is_rejected():
    with pytest.raises(
        ValueError,
        match="between 0 and 1",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                1.10,
                0.00,
                -0.10,
            ],
            class_names=CLASS_NAMES,
        )


def test_non_numeric_probability_is_rejected():
    with pytest.raises(
        ValueError,
        match="numeric",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                0.20,
                "hello",
                0.80,
            ],
            class_names=CLASS_NAMES,
        )


def test_infinite_probability_is_rejected():
    with pytest.raises(
        ValueError,
        match="finite",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                0.20,
                float("inf"),
                0.80,
            ],
            class_names=CLASS_NAMES,
        )


def test_nan_probability_is_rejected():
    with pytest.raises(
        ValueError,
        match="finite",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                0.20,
                float("nan"),
                0.80,
            ],
            class_names=CLASS_NAMES,
        )


def test_class_count_must_match_probability_count():
    with pytest.raises(
        ValueError,
        match="number of class names",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                0.20,
                0.30,
                0.50,
            ],
            class_names=[
                "LOWER",
                "HIGHER",
            ],
        )


def test_requires_at_least_two_probabilities():
    with pytest.raises(
        ValueError,
        match="At least two",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                1.0,
            ],
            class_names=[
                "STABLE",
            ],
        )


def test_invalid_confidence_thresholds_are_rejected():
    with pytest.raises(
        ValueError,
        match="Confidence thresholds",
    ):
        calculate_prediction_uncertainty(
            probabilities=[
                0.20,
                0.30,
                0.50,
            ],
            class_names=CLASS_NAMES,
            low_threshold=0.80,
            high_threshold=0.50,
        )


def test_metadata_is_returned():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.10,
            0.20,
            0.70,
        ],
        class_names=CLASS_NAMES,
    )

    assert (
        result["method"]
        == "maximum_class_probability"
    )

    assert (
        result["scope"]
        == "model_prediction_uncertainty"
    )


def test_safety_disclaimer():
    result = calculate_prediction_uncertainty(
        probabilities=[
            0.10,
            0.20,
            0.70,
        ],
        class_names=CLASS_NAMES,
    )

    disclaimer = (
        result["disclaimer"]
        .lower()
    )

    assert "clinical probability" in disclaimer
    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer
    assert "medication" in disclaimer
