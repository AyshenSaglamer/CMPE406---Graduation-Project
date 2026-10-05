from typing import Dict, List

import numpy as np
import pandas as pd


MIN_BASELINE_RECORDS = 5


def _validate_dataframe(
    dataframe: pd.DataFrame,
) -> None:
    """
    Validate the normalized patient history used
    for personalized baseline learning.
    """

    if dataframe is None:
        raise ValueError(
            "Patient history is required."
        )

    if dataframe.empty:
        raise ValueError(
            "Patient history cannot be empty."
        )

    required_columns = {
        "patient_id",
        "timestamp",
        "glucose_mg_dl",
    }

    missing_columns = (
        required_columns
        - set(dataframe.columns)
    )

    if missing_columns:
        missing_text = ", ".join(
            sorted(missing_columns)
        )

        raise ValueError(
            "Patient history is missing required "
            f"columns: {missing_text}."
        )

    patient_ids = (
        dataframe["patient_id"]
        .dropna()
        .astype(str)
        .unique()
    )

    if len(patient_ids) != 1:
        raise ValueError(
            "Personalized baseline learning requires "
            "records from exactly one patient."
        )

    if len(dataframe) < MIN_BASELINE_RECORDS:
        raise ValueError(
            "At least "
            f"{MIN_BASELINE_RECORDS} records are "
            "required to learn a personalized baseline."
        )


def _get_time_period(
    hour: int,
) -> str:
    """
    Convert an hour of day into a simple
    time-of-day category.

    These categories are engineering groupings,
    not clinical categories.
    """

    if 5 <= hour < 12:
        return "MORNING"

    if 12 <= hour < 17:
        return "AFTERNOON"

    if 17 <= hour < 22:
        return "EVENING"

    return "NIGHT"


def _calculate_statistics(
    values: List[float],
) -> Dict:
    """
    Calculate descriptive statistics for one
    personalized baseline group.
    """

    array = np.asarray(
        values,
        dtype=float,
    )

    if len(array) == 0:
        raise ValueError(
            "Baseline values cannot be empty."
        )

    if not np.all(
        np.isfinite(array)
    ):
        raise ValueError(
            "Baseline values must be finite."
        )

    if np.any(array <= 0):
        raise ValueError(
            "Glucose values must be greater than zero."
        )

    return {
        "count": int(len(array)),
        "mean": round(
            float(np.mean(array)),
            4,
        ),
        "standard_deviation": round(
            float(np.std(array, ddof=0)),
            4,
        ),
        "minimum": round(
            float(np.min(array)),
            4,
        ),
        "maximum": round(
            float(np.max(array)),
            4,
        ),
        "median": round(
            float(np.median(array)),
            4,
        ),
    }


def learn_personalized_baseline(
    dataframe: pd.DataFrame,
) -> Dict:
    """
    Learn descriptive glucose baselines from one
    patient's historical records.

    The function creates:

    - an overall personal baseline
    - time-of-day baselines
    - weekday/weekend baselines

    These baselines describe historical patterns.
    They are not medical target ranges.
    """

    _validate_dataframe(
        dataframe
    )

    working = dataframe.copy()

    working["timestamp"] = pd.to_datetime(
        working["timestamp"],
        errors="raise",
    )

    working["glucose_mg_dl"] = pd.to_numeric(
        working["glucose_mg_dl"],
        errors="raise",
    )

    if (
        not np.isfinite(
            working["glucose_mg_dl"]
        ).all()
    ):
        raise ValueError(
            "Glucose values must be finite."
        )

    if (
        working["glucose_mg_dl"] <= 0
    ).any():
        raise ValueError(
            "Glucose values must be greater than zero."
        )

    working = working.sort_values(
        by="timestamp"
    ).reset_index(
        drop=True
    )

    working["hour"] = (
        working["timestamp"].dt.hour
    )

    working["time_period"] = (
        working["hour"].apply(
            _get_time_period
        )
    )

    working["day_of_week"] = (
        working["timestamp"].dt.dayofweek
    )

    working["day_type"] = np.where(
        working["day_of_week"] >= 5,
        "WEEKEND",
        "WEEKDAY",
    )

    patient_id = str(
        working.iloc[0]["patient_id"]
    )

    # --------------------------------------------------------
    # Overall baseline
    # --------------------------------------------------------

    overall_values = (
        working["glucose_mg_dl"]
        .astype(float)
        .tolist()
    )

    overall_baseline = (
        _calculate_statistics(
            overall_values
        )
    )

    # --------------------------------------------------------
    # Time-of-day baselines
    # --------------------------------------------------------

    time_of_day_baselines = {}

    for time_period in [
        "MORNING",
        "AFTERNOON",
        "EVENING",
        "NIGHT",
    ]:
        group = working[
            working["time_period"]
            == time_period
        ]

        if group.empty:
            time_of_day_baselines[
                time_period
            ] = {
                "available": False,
                "count": 0,
            }

            continue

        values = (
            group["glucose_mg_dl"]
            .astype(float)
            .tolist()
        )

        statistics = (
            _calculate_statistics(
                values
            )
        )

        time_of_day_baselines[
            time_period
        ] = {
            "available": True,
            **statistics,
        }

    # --------------------------------------------------------
    # Weekday / weekend baselines
    # --------------------------------------------------------

    day_type_baselines = {}

    for day_type in [
        "WEEKDAY",
        "WEEKEND",
    ]:
        group = working[
            working["day_type"]
            == day_type
        ]

        if group.empty:
            day_type_baselines[
                day_type
            ] = {
                "available": False,
                "count": 0,
            }

            continue

        values = (
            group["glucose_mg_dl"]
            .astype(float)
            .tolist()
        )

        statistics = (
            _calculate_statistics(
                values
            )
        )

        day_type_baselines[
            day_type
        ] = {
            "available": True,
            **statistics,
        }

    # --------------------------------------------------------
    # Response
    # --------------------------------------------------------

    return {
        "patient_id": patient_id,
        "record_count": int(
            len(working)
        ),
        "overall_baseline": (
            overall_baseline
        ),
        "time_of_day_baselines": (
            time_of_day_baselines
        ),
        "day_type_baselines": (
            day_type_baselines
        ),
        "scope": (
            "personalized_historical_pattern"
        ),
        "method": (
            "descriptive_baseline_learning"
        ),
        "disclaimer": (
            "These personalized baselines describe "
            "historical glucose patterns only. They are "
            "not medical target ranges and must not be "
            "used for diagnosis, treatment, or medication "
            "decisions."
        ),
    }
