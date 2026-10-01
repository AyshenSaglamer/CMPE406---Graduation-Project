from typing import Dict, List

import numpy as np
import pandas as pd

from data.backend_adapter import create_patient_features


TREND_LOWER = "LOWER"
TREND_STABLE = "STABLE"
TREND_HIGHER = "HIGHER"

DEFAULT_STABLE_THRESHOLD = 10.0


MODEL_FEATURES = [
    "glucose_mg_dl",
    "previous_glucose",
    "carbs_g",
    "activity_minutes",
    "hour_of_day",
    "day_of_week",
    "month",
    "is_weekend",
]


def classify_future_change(
    glucose_change: float,
    stable_threshold: float = DEFAULT_STABLE_THRESHOLD,
) -> str:
    """
    Convert a future glucose change into a trend class.

    The threshold is an engineering configuration for
    experimental pattern classification, not a clinical
    treatment threshold.
    """

    if stable_threshold < 0:
        raise ValueError(
            "Stable threshold cannot be negative."
        )

    try:
        change = float(glucose_change)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            "Glucose change must be numeric."
        ) from exc

    if not np.isfinite(change):
        raise ValueError(
            "Glucose change must be finite."
        )

    if change < -stable_threshold:
        return TREND_LOWER

    if change > stable_threshold:
        return TREND_HIGHER

    return TREND_STABLE


def create_future_trend_dataset(
    records: List[Dict],
    stable_threshold: float = DEFAULT_STABLE_THRESHOLD,
) -> pd.DataFrame:
    """
    Build a patient-specific future-trend dataset.

    Features at time t are used to construct a target
    representing the glucose direction at time t+1.
    """

    dataframe = create_patient_features(
        records
    )

    # IMPORTANT:
    # shift(-1) happens separately inside each patient.
    dataframe["next_glucose"] = (
        dataframe
        .groupby("patient_id")["glucose_mg_dl"]
        .shift(-1)
    )

    dataframe["future_glucose_change"] = (
        dataframe["next_glucose"]
        - dataframe["glucose_mg_dl"]
    )

    # A row requires:
    # - a previous reading for previous_glucose
    # - a future reading for the target
    dataframe = dataframe.dropna(
        subset=[
            "previous_glucose",
            "next_glucose",
            "future_glucose_change",
        ]
    ).reset_index(drop=True)

    if dataframe.empty:
        raise ValueError(
            "Not enough sequential patient records "
            "to create future trend targets."
        )

    dataframe["trend_target"] = (
        dataframe["future_glucose_change"]
        .apply(
            lambda change: classify_future_change(
                change,
                stable_threshold,
            )
        )
    )

    return dataframe


def split_future_features_and_target(
    dataset: pd.DataFrame,
):
    """
    Return leakage-safe X and y.

    Future glucose information is deliberately excluded
    from the feature matrix.
    """

    if dataset.empty:
        raise ValueError(
            "Future trend dataset cannot be empty."
        )

    if "trend_target" not in dataset.columns:
        raise ValueError(
            "Dataset must contain trend_target."
        )

    missing_features = [
        feature
        for feature in MODEL_FEATURES
        if feature not in dataset.columns
    ]

    if missing_features:
        raise ValueError(
            "Dataset is missing required features: "
            + ", ".join(missing_features)
        )

    X = dataset[
        MODEL_FEATURES
    ].copy()

    y = dataset[
        "trend_target"
    ].copy()

    return X, y
