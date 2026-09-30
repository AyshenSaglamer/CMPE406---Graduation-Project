from typing import Dict, List

import numpy as np
import pandas as pd


def _validate_records(
    records: List[Dict],
) -> pd.DataFrame:
    """
    Validate records used for glucose relationship analysis.

    Expected fields:
    - glucose_mg_dl
    - carbs_g
    - activity_minutes
    """

    if not records:
        raise ValueError(
            "Analytics records cannot be empty."
        )

    dataframe = pd.DataFrame(records)

    required_columns = {
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
    }

    missing_columns = (
        required_columns - set(dataframe.columns)
    )

    if missing_columns:
        raise ValueError(
            "Each record must contain glucose_mg_dl, "
            "carbs_g, and activity_minutes."
        )

    numeric_columns = [
        "glucose_mg_dl",
        "carbs_g",
        "activity_minutes",
    ]

    for column in numeric_columns:
        dataframe[column] = pd.to_numeric(
            dataframe[column],
            errors="coerce",
        )

        if dataframe[column].isna().any():
            raise ValueError(
                f"{column} must contain numeric values."
            )

        if np.isinf(dataframe[column]).any():
            raise ValueError(
                f"{column} must contain finite values."
            )

    if (dataframe["glucose_mg_dl"] <= 0).any():
        raise ValueError(
            "Glucose values must be greater than zero."
        )

    if (dataframe["carbs_g"] < 0).any():
        raise ValueError(
            "Carbohydrate values cannot be negative."
        )

    if (dataframe["activity_minutes"] < 0).any():
        raise ValueError(
            "Activity minutes cannot be negative."
        )

    return dataframe


def _calculate_correlation(
    dataframe: pd.DataFrame,
    feature: str,
) -> float:
    """
    Calculate Pearson correlation between a feature
    and glucose readings.
    """

    if len(dataframe) < 2:
        raise ValueError(
            "At least two records are required "
            "for correlation analysis."
        )

    if dataframe[feature].nunique() < 2:
        raise ValueError(
            f"{feature} must contain at least "
            "two different values."
        )

    if dataframe["glucose_mg_dl"].nunique() < 2:
        raise ValueError(
            "glucose_mg_dl must contain at least "
            "two different values."
        )

    correlation = dataframe[
        feature
    ].corr(
        dataframe["glucose_mg_dl"]
    )

    if pd.isna(correlation):
        raise ValueError(
            "Correlation could not be calculated."
        )

    return round(
        float(correlation),
        4,
    )


def calculate_meal_glucose_correlation(
    records: List[Dict],
) -> Dict:
    """
    Calculate the statistical relationship between
    carbohydrate intake and glucose readings.

    This describes an association in the supplied data.
    It does not establish causation.
    """

    dataframe = _validate_records(records)

    correlation = _calculate_correlation(
        dataframe,
        "carbs_g",
    )

    return {
        "feature": "carbs_g",
        "target": "glucose_mg_dl",
        "method": "pearson",
        "correlation": correlation,
        "sample_size": int(len(dataframe)),
    }


def calculate_activity_glucose_correlation(
    records: List[Dict],
) -> Dict:
    """
    Calculate the statistical relationship between
    activity duration and glucose readings.

    This describes an association in the supplied data.
    It does not establish causation.
    """

    dataframe = _validate_records(records)

    correlation = _calculate_correlation(
        dataframe,
        "activity_minutes",
    )

    return {
        "feature": "activity_minutes",
        "target": "glucose_mg_dl",
        "method": "pearson",
        "correlation": correlation,
        "sample_size": int(len(dataframe)),
    }


def calculate_glucose_correlations(
    records: List[Dict],
) -> Dict:
    """
    Calculate all currently supported simple
    glucose relationship metrics.
    """

    return {
        "meal_glucose": (
            calculate_meal_glucose_correlation(
                records
            )
        ),
        "activity_glucose": (
            calculate_activity_glucose_correlation(
                records
            )
        ),
    }
