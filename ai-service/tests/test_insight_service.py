import math

import pytest

from services.insight_service import (
    describe_correlation,
    describe_glucose_average,
    describe_glucose_variability,
    describe_prediction,
    describe_time_in_range,
    generate_insights,
)


# =========================================================
# GLUCOSE STATISTICS
# =========================================================

def test_describe_glucose_average():
    insights = describe_glucose_average(
        {
            "mean": 132.5,
        }
    )

    assert len(insights) == 1
    assert "132.5 mg/dL" in insights[0]
    assert "average glucose" in insights[0]


def test_missing_average_returns_empty():
    assert describe_glucose_average({}) == []

    assert (
        describe_glucose_average(
            {"mean": None}
        )
        == []
    )


def test_describe_glucose_variability():
    insights = describe_glucose_variability(
        {
            "standard_deviation": 18.25,
        }
    )

    assert len(insights) == 1
    assert "18.2 mg/dL" in insights[0]

    assert (
        "standard deviation"
        in insights[0]
    )


def test_missing_variability_returns_empty():
    assert (
        describe_glucose_variability({})
        == []
    )


# =========================================================
# TIME IN RANGE
# =========================================================

def test_describe_time_in_range():
    insights = describe_time_in_range(
        {
            "time_in_range_percentage": 75,
            "below_range_percentage": 10,
            "above_range_percentage": 15,
        }
    )

    assert len(insights) == 2

    assert "75.0%" in insights[0]

    assert (
        "configured range"
        in insights[0]
    )

    assert "10.0%" in insights[1]
    assert "15.0%" in insights[1]


def test_incomplete_time_in_range_returns_empty():
    insights = describe_time_in_range(
        {
            "time_in_range_percentage": 75,
        }
    )

    assert insights == []


# =========================================================
# CORRELATIONS
# =========================================================

@pytest.mark.parametrize(
    (
        "correlation",
        "expected_strength",
    ),
    [
        (
            0.10,
            "little linear association",
        ),
        (
            0.30,
            "weak linear association",
        ),
        (
            0.50,
            "moderate linear association",
        ),
        (
            0.80,
            "strong linear association",
        ),
    ],
)
def test_positive_correlation_strength(
    correlation,
    expected_strength,
):
    insights = describe_correlation(
        correlation,
        "carbohydrate amount",
    )

    assert len(insights) == 1

    assert (
        expected_strength
        in insights[0]
    )

    assert "positive" in insights[0]

    assert (
        "does not establish causation"
        in insights[0]
    )


def test_negative_correlation():
    insights = describe_correlation(
        -0.45,
        "activity duration",
    )

    assert len(insights) == 1

    assert (
        "moderate linear association"
        in insights[0]
    )

    assert "negative" in insights[0]

    assert (
        "activity duration"
        in insights[0]
    )


def test_zero_correlation():
    insights = describe_correlation(
        0,
        "activity duration",
    )

    assert len(insights) == 1

    assert "neutral" in insights[0]

    assert (
        "little linear association"
        in insights[0]
    )


# =========================================================
# XGBOOST PREDICTION
# =========================================================

def test_describe_prediction():
    prediction = {
        "prediction": "STABLE",
        "probabilities": {
            "HIGHER": 0.05,
            "LOWER": 0.10,
            "STABLE": 0.85,
        },
    }

    insights = describe_prediction(
        prediction
    )

    assert len(insights) == 1

    assert "STABLE" in insights[0]
    assert "85.0%" in insights[0]

    assert (
        "experimental trend model"
        in insights[0]
    )


def test_prediction_without_probability():
    insights = describe_prediction(
        {
            "prediction": "HIGHER",
            "probabilities": {},
        }
    )

    assert len(insights) == 1
    assert "HIGHER" in insights[0]


def test_unknown_prediction_is_ignored():
    insights = describe_prediction(
        {
            "prediction": "UNKNOWN",
        }
    )

    assert insights == []


# =========================================================
# COMPLETE INSIGHT GENERATION
# =========================================================

def test_generate_complete_insights():
    result = generate_insights(
        statistics={
            "mean": 132.5,
            "standard_deviation": 18.2,
        },
        time_in_range={
            "time_in_range_percentage": 75,
            "below_range_percentage": 10,
            "above_range_percentage": 15,
        },
        meal_glucose_correlation=0.52,
        activity_glucose_correlation=-0.31,
        prediction={
            "prediction": "STABLE",
            "probabilities": {
                "HIGHER": 0.05,
                "LOWER": 0.10,
                "STABLE": 0.85,
            },
        },
    )

    assert (
        result["status"]
        == "SUCCESS"
    )

    # 2 glucose statistics
    # + 2 time-in-range insights
    # + 1 meal correlation
    # + 1 activity correlation
    # + 1 ML prediction
    # = 7 insights

    assert result["insight_count"] == 7

    assert len(result["insights"]) == 7

    assert (
        result["purpose"]
        == "descriptive_pattern_summary"
    )

    assert (
        "not medical"
        in result["disclaimer"]
    )


def test_generate_no_insights():
    result = generate_insights()

    assert (
        result["status"]
        == "NO_INSIGHTS"
    )

    assert result["insight_count"] == 0
    assert result["insights"] == []


# =========================================================
# INPUT VALIDATION
# =========================================================

def test_non_numeric_average_rejected():
    with pytest.raises(
        ValueError,
        match="mean must be numeric",
    ):
        describe_glucose_average(
            {
                "mean": "hello",
            }
        )


def test_infinite_average_rejected():
    with pytest.raises(
        ValueError,
        match="mean must be finite",
    ):
        describe_glucose_average(
            {
                "mean": math.inf,
            }
        )


def test_nan_correlation_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "carbohydrate amount_correlation "
            "must be finite"
        ),
    ):
        describe_correlation(
            math.nan,
            "carbohydrate amount",
        )


def test_non_numeric_probability_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "prediction_probability "
            "must be numeric"
        ),
    ):
        describe_prediction(
            {
                "prediction": "STABLE",
                "probabilities": {
                    "STABLE": "hello",
                },
            }
        )


# =========================================================
# SAFETY / PROJECT SCOPE
# =========================================================

def test_insights_do_not_contain_dosing_advice():
    result = generate_insights(
        statistics={
            "mean": 140,
            "standard_deviation": 20,
        },
        meal_glucose_correlation=0.50,
        prediction={
            "prediction": "HIGHER",
            "probabilities": {
                "HIGHER": 0.80,
                "LOWER": 0.10,
                "STABLE": 0.10,
            },
        },
    )

    combined_text = " ".join(
        result["insights"]
    ).lower()

    prohibited_phrases = [
        "increase insulin",
        "decrease insulin",
        "take insulin",
        "insulin dose",
        "change medication",
        "stop medication",
    ]

    for phrase in prohibited_phrases:
        assert (
            phrase not in combined_text
        )


def test_disclaimer_is_always_present():
    result = generate_insights()

    assert "disclaimer" in result

    assert (
        "not medical diagnosis"
        in result["disclaimer"]
    )
