import numpy as np
import pytest

from analytics.anomaly_detection import (
    DEFAULT_Z_THRESHOLD,
    MIN_BASELINE_SIZE,
    calculate_personal_baseline,
    detect_glucose_anomaly,
)


# =========================================================
# PERSONAL BASELINE
# =========================================================


def test_calculate_personal_baseline():
    history = [
        118,
        123,
        121,
        126,
        119,
        124,
        122,
        120,
    ]

    result = calculate_personal_baseline(
        history
    )

    assert result["count"] == 8

    assert result["mean"] == pytest.approx(
        121.625,
        abs=0.0001,
    )

    assert (
        result["standard_deviation"]
        > 0
    )

    assert result["minimum"] == 118.0
    assert result["maximum"] == 126.0


def test_minimum_baseline_size_constant():
    assert MIN_BASELINE_SIZE == 5


def test_default_threshold_constant():
    assert DEFAULT_Z_THRESHOLD == 2.0


# =========================================================
# ANOMALY DETECTION
# =========================================================


def test_unusual_reading_detected():
    history = [
        118,
        123,
        121,
        126,
        119,
        124,
        122,
        120,
    ]

    result = detect_glucose_anomaly(
        historical_values=history,
        current_value=170,
    )

    assert result["is_anomaly"] is True

    assert (
        result["absolute_z_score"]
        >= result["threshold"]
    )

    assert (
        result["scope"]
        == "personalized_statistical_pattern"
    )


def test_typical_reading_not_detected_as_anomaly():
    history = [
        118,
        123,
        121,
        126,
        119,
        124,
        122,
        120,
    ]

    result = detect_glucose_anomaly(
        historical_values=history,
        current_value=123,
    )

    assert result["is_anomaly"] is False

    assert (
        result["absolute_z_score"]
        < result["threshold"]
    )


def test_anomaly_result_contains_baseline():
    history = [
        118,
        123,
        121,
        126,
        119,
        124,
        122,
        120,
    ]

    result = detect_glucose_anomaly(
        historical_values=history,
        current_value=170,
    )

    assert "baseline" in result

    assert (
        result["baseline"]["count"]
        == len(history)
    )


def test_result_contains_safety_disclaimer():
    history = [
        118,
        123,
        121,
        126,
        119,
    ]

    result = detect_glucose_anomaly(
        historical_values=history,
        current_value=170,
    )

    disclaimer = result[
        "disclaimer"
    ].lower()

    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer


# =========================================================
# ZERO VARIATION
# =========================================================


def test_zero_variation_same_value_not_anomaly():
    history = [
        120,
        120,
        120,
        120,
        120,
    ]

    result = detect_glucose_anomaly(
        historical_values=history,
        current_value=120,
    )

    assert result["is_anomaly"] is False
    assert result["z_score"] is None

    assert (
        result["absolute_z_score"]
        is None
    )


def test_zero_variation_different_value_is_anomaly():
    history = [
        120,
        120,
        120,
        120,
        120,
    ]

    result = detect_glucose_anomaly(
        historical_values=history,
        current_value=130,
    )

    assert result["is_anomaly"] is True
    assert result["z_score"] is None


# =========================================================
# BASELINE VALIDATION
# =========================================================


def test_empty_history_rejected():
    with pytest.raises(
        ValueError,
        match="cannot be empty",
    ):
        calculate_personal_baseline(
            []
        )


def test_insufficient_history_rejected():
    with pytest.raises(
        ValueError,
        match="At least 5 historical",
    ):
        detect_glucose_anomaly(
            historical_values=[
                120,
                121,
                122,
                123,
            ],
            current_value=130,
        )


def test_non_numeric_history_rejected():
    with pytest.raises(
        ValueError,
        match="must be numeric",
    ):
        calculate_personal_baseline(
            [
                120,
                121,
                "hello",
                123,
                124,
            ]
        )


def test_negative_history_value_rejected():
    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        calculate_personal_baseline(
            [
                120,
                121,
                -1,
                123,
                124,
            ]
        )


def test_infinite_history_value_rejected():
    with pytest.raises(
        ValueError,
        match="must be finite",
    ):
        calculate_personal_baseline(
            [
                120,
                121,
                np.inf,
                123,
                124,
            ]
        )


# =========================================================
# CURRENT VALUE VALIDATION
# =========================================================


def test_zero_current_value_rejected():
    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        detect_glucose_anomaly(
            historical_values=[
                118,
                120,
                122,
                124,
                126,
            ],
            current_value=0,
        )


def test_non_numeric_current_value_rejected():
    with pytest.raises(
        ValueError,
        match="must be numeric",
    ):
        detect_glucose_anomaly(
            historical_values=[
                118,
                120,
                122,
                124,
                126,
            ],
            current_value="hello",
        )


# =========================================================
# THRESHOLD VALIDATION
# =========================================================


def test_custom_threshold():
    history = [
        118,
        123,
        121,
        126,
        119,
        124,
        122,
        120,
    ]

    result = detect_glucose_anomaly(
        historical_values=history,
        current_value=130,
        z_threshold=3.0,
    )

    assert result["threshold"] == 3.0


def test_zero_threshold_rejected():
    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        detect_glucose_anomaly(
            historical_values=[
                118,
                120,
                122,
                124,
                126,
            ],
            current_value=130,
            z_threshold=0,
        )


def test_non_numeric_threshold_rejected():
    with pytest.raises(
        ValueError,
        match="must be numeric",
    ):
        detect_glucose_anomaly(
            historical_values=[
                118,
                120,
                122,
                124,
                126,
            ],
            current_value=130,
            z_threshold="hello",
        )


def test_infinite_threshold_rejected():
    with pytest.raises(
        ValueError,
        match="must be finite",
    ):
        detect_glucose_anomaly(
            historical_values=[
                118,
                120,
                122,
                124,
                126,
            ],
            current_value=130,
            z_threshold=np.inf,
        )
