from typing import Dict, List

import numpy as np
import pandas as pd


REQUIRED_FIELDS = {
    "patient_id",
    "timestamp",
    "glucose_mg_dl",
    "carbs_g",
    "activity_minutes",
}


def normalize_backend_records(
    records: List[Dict],
) -> pd.DataFrame:
    """
    Convert backend records into the canonical format
    expected by the DiaMate AI/ML pipeline.

    The backend remains the source of truth.
    """

    if not records:
        raise ValueError(
            "Backend records cannot be empty."
        )

    dataframe = pd.DataFrame(records)

    missing_fields = (
        REQUIRED_FIELDS
        - set(dataframe.columns)
    )

    if missing_fields:
        raise ValueError(
            "Backend records are missing required "
            "fields: "
            + ", ".join(
                sorted(missing_fields)
            )
        )

    dataframe["patient_id"] = (
        dataframe["patient_id"]
        .astype(str)
        .str.strip()
    )

    if (
        dataframe["patient_id"] == ""
    ).any():
        raise ValueError(
            "patient_id cannot be empty."
        )

    dataframe["timestamp"] = (
        pd.to_datetime(
            dataframe["timestamp"],
            errors="coerce",
        )
    )

    if dataframe[
        "timestamp"
    ].isna().any():
        raise ValueError(
            "All timestamps must be valid."
        )

    numeric_columns = [
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
    ]

    for column in numeric_columns:
        dataframe[column] = (
            pd.to_numeric(
                dataframe[column],
                errors="coerce",
            )
        )

        if dataframe[
            column
        ].isna().any():
            raise ValueError(
                f"{column} must contain "
                "numeric values."
            )

        values = dataframe[
            column
        ].to_numpy(dtype=float)

        if not np.isfinite(
            values
        ).all():
            raise ValueError(
                f"{column} must contain "
                "finite values."
            )

    if (
        dataframe["glucose_mg_dl"]
        <= 0
    ).any():
        raise ValueError(
            "Glucose values must be "
            "greater than zero."
        )

    if (
        dataframe["carbs_g"] < 0
    ).any():
        raise ValueError(
            "Carbohydrate values cannot "
            "be negative."
        )

    if (
        dataframe["activity_minutes"]
        < 0
    ).any():
        raise ValueError(
            "Activity minutes cannot "
            "be negative."
        )

    dataframe = (
        dataframe
        .sort_values(
            [
                "patient_id",
                "timestamp",
            ]
        )
        .reset_index(drop=True)
    )

    return dataframe


def create_patient_features(
    records: List[Dict],
) -> pd.DataFrame:
    """
    Create time-series features independently
    for each patient.

    A patient's previous glucose reading must
    never come from another patient's records.
    """

    dataframe = normalize_backend_records(
        records
    )

    dataframe["hour_of_day"] = (
        dataframe["timestamp"].dt.hour
    )

    dataframe["day_of_week"] = (
        dataframe["timestamp"].dt.dayofweek
    )

    dataframe["month"] = (
        dataframe["timestamp"].dt.month
    )

    dataframe["is_weekend"] = (
        dataframe["day_of_week"]
        .isin([5, 6])
        .astype(int)
    )

    dataframe["previous_glucose"] = (
        dataframe
        .groupby("patient_id")[
            "glucose_mg_dl"
        ]
        .shift(1)
    )

    dataframe["glucose_change"] = (
        dataframe["glucose_mg_dl"]
        - dataframe["previous_glucose"]
    )

    return dataframe
