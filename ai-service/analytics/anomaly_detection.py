from typing import Dict, List

import numpy as np


MIN_BASELINE_SIZE = 5

DEFAULT_Z_THRESHOLD = 2.0


def _validate_glucose_values(
    values: List[float],
) -> np.ndarray:
    """
    Validate glucose values used for personalized
    anomaly detection.
    """

    if not values:
        raise ValueError(
            "Glucose values cannot be empty."
        )

    try:
        array = np.asarray(
            values,
            dtype=float,
        )
    except (TypeError, ValueError):
        raise ValueError(
            "Glucose values must be numeric."
        )

    if not np.isfinite(array).all():
        raise ValueError(
            "Glucose values must be finite."
        )

    if (array <= 0).any():
        raise ValueError(
            "Glucose values must be greater than zero."
        )

    return array


def calculate_personal_baseline(
    historical_values: List[float],
) -> Dict:
    """
    Calculate a personalized statistical baseline
    from a patient's previous glucose readings.

    The baseline describes the patient's historical
    logged pattern. It is not a clinical reference
    range.
    """

    values = _validate_glucose_values(
        historical_values
    )

    if len(values) < MIN_BASELINE_SIZE:
        raise ValueError(
            f"At least {MIN_BASELINE_SIZE} historical "
            "glucose readings are required."
        )

    mean = float(
        np.mean(values)
    )

    standard_deviation = float(
        np.std(
            values,
            ddof=0,
        )
    )

    return {
        "count": int(len(values)),
        "mean": round(
            mean,
            4,
        ),
        "standard_deviation": round(
            standard_deviation,
            4,
        ),
        "minimum": round(
            float(np.min(values)),
            4,
        ),
        "maximum": round(
            float(np.max(values)),
            4,
        ),
    }


def detect_glucose_anomaly(
    historical_values: List[float],
    current_value: float,
    z_threshold: float = DEFAULT_Z_THRESHOLD,
) -> Dict:
    """
    Compare one current glucose reading with the
    patient's own historical glucose baseline.

    A reading is marked as statistically unusual
    when its absolute z-score reaches or exceeds
    the configured engineering threshold.

    This does not represent diagnosis, clinical
    risk classification, or medical advice.
    """

    baseline_values = _validate_glucose_values(
        historical_values
    )

    if len(baseline_values) < MIN_BASELINE_SIZE:
        raise ValueError(
            f"At least {MIN_BASELINE_SIZE} historical "
            "glucose readings are required."
        )

    current_array = _validate_glucose_values(
        [current_value]
    )

    current = float(
        current_array[0]
    )

    try:
        threshold = float(
            z_threshold
        )
    except (TypeError, ValueError):
        raise ValueError(
            "z_threshold must be numeric."
        )

    if not np.isfinite(threshold):
        raise ValueError(
            "z_threshold must be finite."
        )

    if threshold <= 0:
        raise ValueError(
            "z_threshold must be greater than zero."
        )

    baseline = calculate_personal_baseline(
        historical_values
    )

    mean = baseline["mean"]

    standard_deviation = baseline[
        "standard_deviation"
    ]

    # If every historical value is identical,
    # standard deviation is zero and a normal
    # z-score cannot be calculated.
    if standard_deviation == 0:
        is_anomaly = current != mean

        return {
            "current_value": current,
            "is_anomaly": bool(
                is_anomaly
            ),
            "z_score": None,
            "absolute_z_score": None,
            "threshold": threshold,
            "baseline": baseline,
            "reason": (
                "Historical glucose values have zero "
                "variation, so a z-score cannot be "
                "calculated. The current value was "
                "compared directly with the personal "
                "baseline."
            ),
            "scope": "personalized_statistical_pattern",
            "disclaimer": (
                "This result only describes whether the "
                "reading is unusual compared with the "
                "patient's own logged history. It does "
                "not represent diagnosis, clinical risk "
                "classification, treatment, or medication "
                "advice."
            ),
        }

    z_score = (
        current - mean
    ) / standard_deviation

    absolute_z_score = abs(
        z_score
    )

    is_anomaly = (
        absolute_z_score
        >= threshold
    )

    return {
        "current_value": current,
        "is_anomaly": bool(
            is_anomaly
        ),
        "z_score": round(
            float(z_score),
            4,
        ),
        "absolute_z_score": round(
            float(absolute_z_score),
            4,
        ),
        "threshold": threshold,
        "baseline": baseline,
        "reason": (
            "The current reading was compared with "
            "the patient's own historical glucose "
            "distribution using a z-score."
        ),
        "scope": "personalized_statistical_pattern",
        "disclaimer": (
            "This result only describes whether the "
            "reading is unusual compared with the "
            "patient's own logged history. It does "
            "not represent diagnosis, clinical risk "
            "classification, treatment, or medication "
            "advice."
        ),
    }

