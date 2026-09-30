from typing import Dict, List

import numpy as np
import pandas as pd

from analytics.feature_engineering import create_ml_features


TREND_LOWER = "LOWER"
TREND_STABLE = "STABLE"
TREND_HIGHER = "HIGHER"

DEFAULT_STABLE_THRESHOLD = 10.0


def classify_glucose_change(
    glucose_change: float,
    stable_threshold: float = DEFAULT_STABLE_THRESHOLD,
) -> str:
    """
    Convert a glucose change into a simple trend class.

    LOWER:
        Change is below the negative threshold.

    STABLE:
        Change is within the configured threshold.

    HIGHER:
        Change is above the positive threshold.

    The threshold is an engineering configuration for
    trend classification. It is not a diagnostic or
    treatment threshold.
    """

    if stable_threshold < 0:
        raise ValueError(
            "Stable threshold cannot be negative."
        )

    if glucose_change is None:
        raise ValueError(
            "Glucose change cannot be missing."
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


def create_trend_target(
    dataframe: pd.DataFrame,
    stable_threshold: float = DEFAULT_STABLE_THRESHOLD,
) -> pd.DataFrame:
    """
    Create a trend target from glucose_change.

    Rows without a previous glucose value cannot have
    a change-based target and are removed.
    """

    if dataframe.empty:
        raise ValueError(
            "Feature dataframe cannot be empty."
        )

    if "glucose_change" not in dataframe.columns:
        raise ValueError(
            "Feature dataframe must contain glucose_change."
        )

    result = dataframe.copy()

    result = result.dropna(
        subset=["glucose_change"]
    ).reset_index(drop=True)

    if result.empty:
        raise ValueError(
            "At least two glucose readings are required "
            "to create a trend target."
        )

    result["trend_target"] = (
        result["glucose_change"].apply(
            lambda change: classify_glucose_change(
                change,
                stable_threshold,
            )
        )
    )

    return result


def create_ml_dataset(
    records: List[Dict],
    stable_threshold: float = DEFAULT_STABLE_THRESHOLD,
) -> pd.DataFrame:
    """
    Create a prepared dataset containing engineered
    features and a trend target.

    Important:
    glucose_change is used to construct the target.
    It must not later be included in the XGBoost
    predictive feature matrix.
    """

    features = create_ml_features(records)

    dataset = create_trend_target(
        features,
        stable_threshold,
    )

    return dataset


def split_features_and_target(
    dataset: pd.DataFrame,
):
    """
    Separate predictive features (X) from the target (y).

    glucose_change and current glucose_mg_dl are excluded
    from X because they directly reveal the change used
    to construct the current trend target.

    timestamp is also excluded because the model uses
    engineered time features instead.
    """

    if dataset.empty:
        raise ValueError(
            "ML dataset cannot be empty."
        )

    if "trend_target" not in dataset.columns:
        raise ValueError(
            "ML dataset must contain trend_target."
        )

    feature_columns = [
        "previous_glucose",
        "carbs_g",
        "activity_minutes",
        "hour_of_day",
        "day_of_week",
        "month",
        "is_weekend",
    ]

    missing_columns = [
        column
        for column in feature_columns
        if column not in dataset.columns
    ]

    if missing_columns:
        raise ValueError(
            "ML dataset is missing required features: "
            + ", ".join(missing_columns)
        )

    X = dataset[
        feature_columns
    ].copy()

    y = dataset[
        "trend_target"
    ].copy()

    return X, y
