from typing import Dict, List, Optional

import numpy as np


# =========================================================
# INTERNAL VALIDATION
# =========================================================

def _validate_optional_number(
    value,
    field_name: str,
) -> Optional[float]:
    """
    Validate an optional numeric value.

    None is allowed because some analytics may not
    be available for every patient history.

    Non-numeric, NaN, and infinite values are
    rejected.
    """

    if value is None:
        return None

    try:
        numeric_value = float(value)

    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{field_name} must be numeric."
        ) from exc

    if not np.isfinite(numeric_value):
        raise ValueError(
            f"{field_name} must be finite."
        )

    return numeric_value


# =========================================================
# GLUCOSE STATISTICS
# =========================================================

def describe_glucose_average(
    statistics: Dict,
) -> List[str]:
    """
    Describe the calculated glucose average.

    The value is reported descriptively without
    classifying it as medically good or bad.
    """

    if not statistics:
        return []

    mean = _validate_optional_number(
        statistics.get("mean"),
        "mean",
    )

    if mean is None:
        return []

    return [
        (
            "The average glucose value in the "
            "selected logged period was "
            f"{mean:.1f} mg/dL."
        )
    ]


def describe_glucose_variability(
    statistics: Dict,
) -> List[str]:
    """
    Describe glucose variability using the
    calculated standard deviation.

    No medical threshold is selected here.
    """

    if not statistics:
        return []

    standard_deviation = (
        _validate_optional_number(
            statistics.get("standard_deviation"),
            "standard_deviation",
        )
    )

    if standard_deviation is None:
        return []

    return [
        (
            "The standard deviation of the "
            "logged glucose values was "
            f"{standard_deviation:.1f} mg/dL."
        )
    ]


# =========================================================
# TIME IN RANGE
# =========================================================

def describe_time_in_range(
    time_in_range: Dict,
) -> List[str]:
    """
    Describe already-calculated time-in-range
    percentages.

    IMPORTANT:
    calculate_time_in_range() returns:

        time_in_range_percentage
        below_range_percentage
        above_range_percentage

    The glucose range itself is expected to come
    from application/profile configuration.
    """

    if not time_in_range:
        return []

    in_range = _validate_optional_number(
        time_in_range.get(
            "time_in_range_percentage"
        ),
        "time_in_range_percentage",
    )

    below = _validate_optional_number(
        time_in_range.get(
            "below_range_percentage"
        ),
        "below_range_percentage",
    )

    above = _validate_optional_number(
        time_in_range.get(
            "above_range_percentage"
        ),
        "above_range_percentage",
    )

    if (
        in_range is None
        or below is None
        or above is None
    ):
        return []

    return [
        (
            f"{in_range:.1f}% of the logged "
            "glucose values were within the "
            "configured range."
        ),
        (
            f"{below:.1f}% were below the "
            "configured range and "
            f"{above:.1f}% were above it."
        ),
    ]


# =========================================================
# CORRELATION DESCRIPTION
# =========================================================

def describe_correlation(
    correlation: float,
    subject: str,
) -> List[str]:
    """
    Convert a correlation coefficient into a
    cautious descriptive statement.

    Correlation is reported only as an
    association and never as evidence of
    causation.
    """

    value = _validate_optional_number(
        correlation,
        f"{subject}_correlation",
    )

    if value is None:
        return []

    absolute_value = abs(value)

    if absolute_value < 0.20:
        strength = (
            "little linear association"
        )

    elif absolute_value < 0.40:
        strength = (
            "a weak linear association"
        )

    elif absolute_value < 0.70:
        strength = (
            "a moderate linear association"
        )

    else:
        strength = (
            "a strong linear association"
        )

    if value > 0:
        direction = "positive"

    elif value < 0:
        direction = "negative"

    else:
        direction = "neutral"

    return [
        (
            "The logged data shows "
            f"{strength} between {subject} "
            "and glucose "
            f"(correlation {value:.2f}, "
            f"{direction}). "
            "This describes an association "
            "in the available records and "
            "does not establish causation."
        )
    ]


# =========================================================
# ML PREDICTION DESCRIPTION
# =========================================================

def describe_prediction(
    prediction: Dict,
) -> List[str]:
    """
    Describe the experimental XGBoost trend
    classification.

    The prediction is not converted into
    treatment, insulin, or medication advice.
    """

    if not prediction:
        return []

    trend = prediction.get(
        "prediction"
    )

    if trend not in {
        "LOWER",
        "STABLE",
        "HIGHER",
    }:
        return []

    probabilities = prediction.get(
        "probabilities",
        {},
    )

    confidence = probabilities.get(
        trend
    )

    if confidence is None:
        return [
            (
                "The experimental trend model "
                "classified the next logged "
                "glucose direction as "
                f"{trend}."
            )
        ]

    confidence = _validate_optional_number(
        confidence,
        "prediction_probability",
    )

    return [
        (
            "The experimental trend model "
            "classified the next logged glucose "
            f"direction as {trend} with a model "
            "probability of "
            f"{confidence * 100:.1f}%."
        )
    ]


# =========================================================
# COMPLETE INSIGHT GENERATION
# =========================================================

def generate_insights(
    *,
    statistics: Optional[Dict] = None,
    time_in_range: Optional[Dict] = None,
    meal_glucose_correlation=None,
    activity_glucose_correlation=None,
    prediction: Optional[Dict] = None,
) -> Dict:
    """
    Generate explainable summaries from existing
    DiaMate analytics and ML outputs.

    This service summarizes patterns in logged
    data.

    It does NOT:
    - diagnose diabetes or another condition
    - recommend treatment
    - recommend medication changes
    - recommend insulin doses
    """

    insights = []

    # -----------------------------------------------------
    # Glucose statistics
    # -----------------------------------------------------

    if statistics:
        insights.extend(
            describe_glucose_average(
                statistics
            )
        )

        insights.extend(
            describe_glucose_variability(
                statistics
            )
        )

    # -----------------------------------------------------
    # Time in range
    # -----------------------------------------------------

    if time_in_range:
        insights.extend(
            describe_time_in_range(
                time_in_range
            )
        )

    # -----------------------------------------------------
    # Meal / glucose association
    # -----------------------------------------------------

    if (
        meal_glucose_correlation
        is not None
    ):
        insights.extend(
            describe_correlation(
                meal_glucose_correlation,
                "carbohydrate amount",
            )
        )

    # -----------------------------------------------------
    # Activity / glucose association
    # -----------------------------------------------------

    if (
        activity_glucose_correlation
        is not None
    ):
        insights.extend(
            describe_correlation(
                activity_glucose_correlation,
                "activity duration",
            )
        )

    # -----------------------------------------------------
    # Experimental XGBoost prediction
    # -----------------------------------------------------

    if prediction:
        insights.extend(
            describe_prediction(
                prediction
            )
        )

    # -----------------------------------------------------
    # Final response
    # -----------------------------------------------------

    return {
        "status": (
            "SUCCESS"
            if insights
            else "NO_INSIGHTS"
        ),
        "insight_count": len(insights),
        "insights": insights,
        "purpose": (
            "descriptive_pattern_summary"
        ),
        "disclaimer": (
            "These insights summarize patterns "
            "in logged data and are not medical "
            "diagnosis, treatment, or medication "
            "dosing advice."
        ),
    }
