from typing import Dict, List

import numpy as np

from data.backend_adapter import (
    normalize_backend_records,
)


DEFAULT_STABLE_THRESHOLD = 10.0

MIN_CORRELATION_RECORDS = 3


# ============================================================
# RECENT VS PREVIOUS GLUCOSE
# ============================================================


def compare_recent_glucose(
    records: List[Dict],
    stable_threshold: float = DEFAULT_STABLE_THRESHOLD,
) -> Dict:
    """
    Compare the average glucose value in the recent
    half of the patient's logged history with the
    previous half.

    This is descriptive pattern detection only.
    """

    if stable_threshold < 0:
        raise ValueError(
            "Stable threshold cannot be negative."
        )

    dataframe = normalize_backend_records(
        records
    )

    patient_count = (
        dataframe["patient_id"].nunique()
    )

    if patient_count != 1:
        raise ValueError(
            "Pattern history must contain "
            "exactly one patient."
        )

    if len(dataframe) < 4:
        return {
            "status": "NOT_ENOUGH_DATA",
            "pattern": None,
            "message": (
                "At least four logged records are "
                "required for recent glucose "
                "comparison."
            ),
        }

    dataframe = dataframe.sort_values(
        "timestamp"
    ).reset_index(drop=True)

    split_index = len(dataframe) // 2

    previous_period = dataframe.iloc[
        :split_index
    ]

    recent_period = dataframe.iloc[
        split_index:
    ]

    previous_average = float(
        previous_period[
            "glucose_mg_dl"
        ].mean()
    )

    recent_average = float(
        recent_period[
            "glucose_mg_dl"
        ].mean()
    )

    difference = (
        recent_average
        - previous_average
    )

    if difference > stable_threshold:
        pattern = "HIGHER"

    elif difference < -stable_threshold:
        pattern = "LOWER"

    else:
        pattern = "STABLE"

    return {
        "status": "SUCCESS",
        "pattern": pattern,
        "previous_average_mg_dl": round(
            previous_average,
            2,
        ),
        "recent_average_mg_dl": round(
            recent_average,
            2,
        ),
        "difference_mg_dl": round(
            difference,
            2,
        ),
        "stable_threshold_mg_dl": float(
            stable_threshold
        ),
        "previous_record_count": len(
            previous_period
        ),
        "recent_record_count": len(
            recent_period
        ),
        "purpose": (
            "descriptive_recent_glucose_pattern"
        ),
    }


def describe_recent_glucose_pattern(
    pattern_result: Dict,
) -> List[str]:
    """
    Convert the recent-vs-previous comparison into
    a human-readable non-diagnostic insight.
    """

    if (
        not pattern_result
        or pattern_result.get("status")
        != "SUCCESS"
    ):
        return []

    pattern = pattern_result.get(
        "pattern"
    )

    previous_average = (
        pattern_result.get(
            "previous_average_mg_dl"
        )
    )

    recent_average = (
        pattern_result.get(
            "recent_average_mg_dl"
        )
    )

    if pattern == "HIGHER":
        message = (
            "The average glucose value in the "
            "more recent logged period was higher "
            "than in the previous logged period."
        )

    elif pattern == "LOWER":
        message = (
            "The average glucose value in the "
            "more recent logged period was lower "
            "than in the previous logged period."
        )

    elif pattern == "STABLE":
        message = (
            "The average glucose value was "
            "relatively stable between the "
            "previous and recent logged periods."
        )

    else:
        return []

    if (
        previous_average is not None
        and recent_average is not None
    ):
        message += (
            f" The averages were "
            f"{previous_average:.1f} mg/dL "
            f"and {recent_average:.1f} mg/dL, "
            "respectively."
        )

    return [message]


# ============================================================
# CORRELATION HELPERS
# ============================================================


def _correlation_strength(
    correlation: float,
) -> str:
    """
    Convert absolute correlation magnitude into
    a descriptive label.

    These labels are engineering descriptions,
    not clinical classifications.
    """

    absolute_value = abs(correlation)

    if absolute_value < 0.20:
        return "LITTLE"

    if absolute_value < 0.40:
        return "WEAK"

    if absolute_value < 0.70:
        return "MODERATE"

    return "STRONG"


def _calculate_pattern_correlation(
    *,
    records: List[Dict],
    variable_name: str,
    pattern_name: str,
) -> Dict:
    """
    Calculate the Pearson correlation between one
    logged variable and glucose.

    Correlation describes association only.
    """

    dataframe = normalize_backend_records(
        records
    )

    patient_count = (
        dataframe["patient_id"].nunique()
    )

    if patient_count != 1:
        raise ValueError(
            "Pattern history must contain "
            "exactly one patient."
        )

    if len(dataframe) < MIN_CORRELATION_RECORDS:
        return {
            "status": "NOT_ENOUGH_DATA",
            "pattern": pattern_name,
            "correlation": None,
            "message": (
                "At least three logged records "
                "are required for correlation "
                "pattern analysis."
            ),
        }

    variable_values = dataframe[
        variable_name
    ].to_numpy(dtype=float)

    glucose_values = dataframe[
        "glucose_mg_dl"
    ].to_numpy(dtype=float)

    # Pearson correlation is not meaningful if one
    # of the variables never changes.
    if (
        np.std(variable_values) == 0
        or np.std(glucose_values) == 0
    ):
        return {
            "status": "NO_VARIATION",
            "pattern": pattern_name,
            "correlation": None,
            "message": (
                "Correlation could not be calculated "
                "because one of the logged variables "
                "did not vary."
            ),
        }

    correlation = float(
        np.corrcoef(
            variable_values,
            glucose_values,
        )[0, 1]
    )

    if correlation > 0:
        direction = "POSITIVE"

    elif correlation < 0:
        direction = "NEGATIVE"

    else:
        direction = "NEUTRAL"

    return {
        "status": "SUCCESS",
        "pattern": pattern_name,
        "correlation": round(
            correlation,
            4,
        ),
        "direction": direction,
        "strength": _correlation_strength(
            correlation
        ),
        "record_count": len(dataframe),
        "purpose": (
            "descriptive_association_pattern"
        ),
    }


# ============================================================
# MEAL / CARBOHYDRATE PATTERN
# ============================================================


def analyze_meal_glucose_pattern(
    records: List[Dict],
) -> Dict:
    """
    Analyze the association between logged
    carbohydrate amounts and glucose values.
    """

    return _calculate_pattern_correlation(
        records=records,
        variable_name="carbs_g",
        pattern_name="MEAL_GLUCOSE",
    )


def describe_meal_glucose_pattern(
    result: Dict,
) -> List[str]:
    """
    Convert meal-glucose correlation into a safe
    human-readable description.
    """

    if (
        not result
        or result.get("status")
        != "SUCCESS"
    ):
        return []

    correlation = result.get(
        "correlation"
    )

    direction = result.get(
        "direction"
    )

    strength = result.get(
        "strength"
    )

    if (
        correlation is None
        or direction is None
        or strength is None
    ):
        return []

    if direction == "POSITIVE":
        relationship = (
            "higher carbohydrate amounts were "
            "associated with higher glucose values"
        )

    elif direction == "NEGATIVE":
        relationship = (
            "higher carbohydrate amounts were "
            "associated with lower glucose values"
        )

    else:
        relationship = (
            "no directional linear association "
            "was observed between carbohydrate "
            "amount and glucose"
        )

    message = (
        f"In the available logged data, "
        f"{relationship}. "
        f"The linear association was "
        f"{strength.lower()} "
        f"(correlation {correlation:.2f}). "
        "This describes an association and does "
        "not establish causation."
    )

    return [message]


# ============================================================
# ACTIVITY PATTERN
# ============================================================


def analyze_activity_glucose_pattern(
    records: List[Dict],
) -> Dict:
    """
    Analyze the association between logged
    activity duration and glucose values.
    """

    return _calculate_pattern_correlation(
        records=records,
        variable_name="activity_minutes",
        pattern_name="ACTIVITY_GLUCOSE",
    )


def describe_activity_glucose_pattern(
    result: Dict,
) -> List[str]:
    """
    Convert activity-glucose correlation into a
    safe human-readable description.
    """

    if (
        not result
        or result.get("status")
        != "SUCCESS"
    ):
        return []

    correlation = result.get(
        "correlation"
    )

    direction = result.get(
        "direction"
    )

    strength = result.get(
        "strength"
    )

    if (
        correlation is None
        or direction is None
        or strength is None
    ):
        return []

    if direction == "POSITIVE":
        relationship = (
            "longer logged activity duration was "
            "associated with higher glucose values"
        )

    elif direction == "NEGATIVE":
        relationship = (
            "longer logged activity duration was "
            "associated with lower glucose values"
        )

    else:
        relationship = (
            "no directional linear association "
            "was observed between activity duration "
            "and glucose"
        )

    message = (
        f"In the available logged data, "
        f"{relationship}. "
        f"The linear association was "
        f"{strength.lower()} "
        f"(correlation {correlation:.2f}). "
        "This describes an association and does "
        "not establish causation."
    )

    return [message]


# ============================================================
# COMPLETE PERSONALIZED PATTERN ANALYSIS
# ============================================================


def analyze_patient_patterns(
    records: List[Dict],
) -> Dict:
    """
    Run all currently supported descriptive
    patient pattern analyses.
    """

    recent_glucose = (
        compare_recent_glucose(
            records
        )
    )

    meal_glucose = (
        analyze_meal_glucose_pattern(
            records
        )
    )

    activity_glucose = (
        analyze_activity_glucose_pattern(
            records
        )
    )

    insights = []

    insights.extend(
        describe_recent_glucose_pattern(
            recent_glucose
        )
    )

    insights.extend(
        describe_meal_glucose_pattern(
            meal_glucose
        )
    )

    insights.extend(
        describe_activity_glucose_pattern(
            activity_glucose
        )
    )

    return {
        "status": "SUCCESS",
        "patterns": {
            "recent_glucose": (
                recent_glucose
            ),
            "meal_glucose": (
                meal_glucose
            ),
            "activity_glucose": (
                activity_glucose
            ),
        },
        "insight_count": len(
            insights
        ),
        "insights": insights,
        "purpose": (
            "personalized_descriptive_patterns"
        ),
        "disclaimer": (
            "These patterns describe associations "
            "and changes in logged data. They do "
            "not establish causation and are not "
            "medical diagnosis, treatment, or "
            "medication dosing advice."
        ),
    }
