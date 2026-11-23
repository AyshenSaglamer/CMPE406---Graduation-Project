from typing import Dict, List, Union

import numpy as np


Number = Union[int, float]


def _validate_glucose_values(
    glucose_values: List[Number],
) -> np.ndarray:
    """
    Validate glucose readings and return them as a NumPy array.
    """

    if not glucose_values:
        raise ValueError("Glucose values cannot be empty.")

    values = np.array(glucose_values, dtype=float)

    if np.isnan(values).any():
        raise ValueError(
            "Glucose values cannot contain missing values."
        )

    if np.isinf(values).any():
        raise ValueError(
            "Glucose values must be finite."
        )

    if np.any(values <= 0):
        raise ValueError(
            "Glucose values must be greater than zero."
        )

    return values


def calculate_glucose_statistics(
    glucose_values: List[Number],
) -> Dict[str, Number]:
    """
    Calculate basic descriptive statistics for glucose readings.
    """

    values = _validate_glucose_values(glucose_values)

    return {
        "count": int(len(values)),
        "mean": round(float(np.mean(values)), 2),
        "minimum": round(float(np.min(values)), 2),
        "maximum": round(float(np.max(values)), 2),
        "standard_deviation": round(
            float(np.std(values)),
            2,
        ),
    }


def calculate_time_in_range(
    glucose_values: List[Number],
    lower_bound: Number = 70,
    upper_bound: Number = 180,
) -> Dict[str, Number]:
    """
    Calculate the percentage of readings below, within,
    and above the configured glucose range.

    The bounds are configurable and should come from the
    application's patient/profile settings when integrated.
    """

    values = _validate_glucose_values(glucose_values)

    if lower_bound <= 0 or upper_bound <= 0:
        raise ValueError(
            "Range bounds must be greater than zero."
        )

    if lower_bound >= upper_bound:
        raise ValueError(
            "Lower bound must be less than upper bound."
        )

    total = len(values)

    below_count = int(
        np.sum(values < lower_bound)
    )

    in_range_count = int(
        np.sum(
            (values >= lower_bound)
            & (values <= upper_bound)
        )
    )

    above_count = int(
        np.sum(values > upper_bound)
    )

    return {
        "total_readings": total,
        "below_range_count": below_count,
        "in_range_count": in_range_count,
        "above_range_count": above_count,
        "below_range_percentage": round(
            below_count / total * 100,
            2,
        ),
        "time_in_range_percentage": round(
            in_range_count / total * 100,
            2,
        ),
        "above_range_percentage": round(
            above_count / total * 100,
            2,
        ),
        "lower_bound": float(lower_bound),
        "upper_bound": float(upper_bound),
    }
