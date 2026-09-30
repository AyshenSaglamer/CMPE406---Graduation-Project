from typing import Dict, List

import numpy as np
import pandas as pd


REQUIRED_COLUMNS = {
    "timestamp",
    "glucose_mg_dl",
    "carbs_g",
    "activity_minutes",
}


def _validate_records(
    records: List[Dict],
) -> pd.DataFrame:
    """
    Validate records before feature engineering.

    Expected input fields:
    - timestamp
    - glucose_mg_dl
    - carbs_g
    - activity_minutes

    The function is intentionally independent of the
    backend database schema. A data adapter can later
    convert backend records into this format.
    """

    if not records:
        raise ValueError(
            "Feature engineering records cannot be empty."
        )

    dataframe = pd.DataFrame(records)

    missing_columns = (
        REQUIRED_COLUMNS - set(dataframe.columns)
    )

    if missing_columns:
        raise ValueError(
            "Each record must contain timestamp, "
            "glucose_mg_dl, carbs_g, and "
            "activity_minutes."
        )

    # Convert timestamp values to datetime.
    dataframe["timestamp"] = pd.to_datetime(
        dataframe["timestamp"],
        errors="coerce",
    )

    if dataframe["timestamp"].isna().any():
        raise ValueError(
            "All timestamps must be valid."
        )

    numeric_columns = [
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
    ]

    # Convert and validate numeric columns.
    for column in numeric_columns:
        dataframe[column] = pd.to_numeric(
            dataframe[column],
            errors="coerce",
        )

        if dataframe[column].isna().any():
            raise ValueError(
                f"{column} must contain numeric values."
            )

        if np.isinf(
            dataframe[column].to_numpy(dtype=float)
        ).any():
            raise ValueError(
                f"{column} must contain finite values."
            )

    # Glucose must always be positive.
    if (
        dataframe["glucose_mg_dl"] <= 0
    ).any():
        raise ValueError(
            "Glucose values must be greater than zero."
        )

    # Zero carbohydrates are allowed.
    if (
        dataframe["carbs_g"] < 0
    ).any():
        raise ValueError(
            "Carbohydrate values cannot be negative."
        )

    # Zero activity minutes are allowed.
    if (
        dataframe["activity_minutes"] < 0
    ).any():
        raise ValueError(
            "Activity minutes cannot be negative."
        )

    # Sort chronologically before creating
    # time-dependent features.
    return (
        dataframe
        .sort_values("timestamp")
        .reset_index(drop=True)
    )


def create_time_features(
    dataframe: pd.DataFrame,
) -> pd.DataFrame:
    """
    Create time-based features from timestamps.

    day_of_week follows the Pandas convention:
    Monday = 0
    Tuesday = 1
    ...
    Sunday = 6
    """

    result = dataframe.copy()

    result["hour_of_day"] = (
        result["timestamp"].dt.hour
    )

    result["day_of_week"] = (
        result["timestamp"].dt.dayofweek
    )

    result["month"] = (
        result["timestamp"].dt.month
    )

    result["is_weekend"] = (
        result["day_of_week"]
        .isin([5, 6])
        .astype(int)
    )

    return result


def create_previous_glucose_feature(
    dataframe: pd.DataFrame,
) -> pd.DataFrame:
    """
    Add the previous glucose reading.

    The first chronological record does not have a
    previous glucose reading, so its value will be NaN.

    When patient-specific backend data is integrated,
    this operation should be grouped by patient so that
    readings from different patients are never mixed.
    """

    result = dataframe.copy()

    result["previous_glucose"] = (
        result["glucose_mg_dl"].shift(1)
    )

    return result


def create_glucose_change_feature(
    dataframe: pd.DataFrame,
) -> pd.DataFrame:
    """
    Calculate glucose change relative to the previous
    reading.

    glucose_change is intended for analytics and later
    target construction. It must not automatically be
    used as a predictive input when it would leak target
    information into a machine-learning model.
    """

    result = dataframe.copy()

    result["glucose_change"] = (
        result["glucose_mg_dl"]
        - result["previous_glucose"]
    )

    return result


def create_ml_features(
    records: List[Dict],
) -> pd.DataFrame:
    """
    Validate records and create engineered features.

    Output currently includes:
    - timestamp
    - glucose_mg_dl
    - carbs_g
    - activity_minutes
    - hour_of_day
    - day_of_week
    - month
    - is_weekend
    - previous_glucose
    - glucose_change

    This function only prepares data. It does not make
    predictions, diagnoses, or treatment recommendations.
    """

    dataframe = _validate_records(records)

    dataframe = create_time_features(
        dataframe
    )

    dataframe = create_previous_glucose_feature(
        dataframe
    )

    dataframe = create_glucose_change_feature(
        dataframe
    )

    return dataframe
