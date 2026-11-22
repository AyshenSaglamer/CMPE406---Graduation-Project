from typing import Dict, List, Literal, Union

import pandas as pd


Number = Union[int, float]
Period = Literal["daily", "weekly", "monthly"]


def _validate_records(
    records: List[Dict],
) -> pd.DataFrame:
    """
    Validate timestamped glucose records and convert them
    into a clean Pandas DataFrame.

    Expected record format:
    {
        "timestamp": "2026-09-01 08:00:00",
        "glucose_mg_dl": 120
    }
    """

    if not records:
        raise ValueError(
            "Glucose records cannot be empty."
        )

    dataframe = pd.DataFrame(records)

    required_columns = {
        "timestamp",
        "glucose_mg_dl",
    }

    missing_columns = (
        required_columns - set(dataframe.columns)
    )

    if missing_columns:
        raise ValueError(
            "Each record must contain timestamp "
            "and glucose_mg_dl."
        )

    dataframe["timestamp"] = pd.to_datetime(
        dataframe["timestamp"],
        errors="coerce",
    )

    if dataframe["timestamp"].isna().any():
        raise ValueError(
            "All timestamps must be valid."
        )

    dataframe["glucose_mg_dl"] = pd.to_numeric(
        dataframe["glucose_mg_dl"],
        errors="coerce",
    )

    if dataframe["glucose_mg_dl"].isna().any():
        raise ValueError(
            "All glucose values must be numeric."
        )

    if (
        dataframe["glucose_mg_dl"] <= 0
    ).any():
        raise ValueError(
            "Glucose values must be greater than zero."
        )

    return dataframe.sort_values(
        "timestamp"
    ).reset_index(drop=True)


def calculate_daily_trends(
    records: List[Dict],
) -> List[Dict]:
    """
    Calculate daily glucose summary statistics.
    """

    dataframe = _validate_records(records)

    dataframe["period"] = (
        dataframe["timestamp"]
        .dt.strftime("%Y-%m-%d")
    )

    return _aggregate_trends(dataframe)


def calculate_weekly_trends(
    records: List[Dict],
) -> List[Dict]:
    """
    Calculate weekly glucose summary statistics.

    Each period represents the Monday starting that week.
    """

    dataframe = _validate_records(records)

    dataframe["period"] = (
        dataframe["timestamp"]
        .dt.to_period("W-SUN")
        .apply(lambda period: period.start_time)
        .dt.strftime("%Y-%m-%d")
    )

    return _aggregate_trends(dataframe)


def calculate_monthly_trends(
    records: List[Dict],
) -> List[Dict]:
    """
    Calculate monthly glucose summary statistics.
    """

    dataframe = _validate_records(records)

    dataframe["period"] = (
        dataframe["timestamp"]
        .dt.strftime("%Y-%m")
    )

    return _aggregate_trends(dataframe)


def calculate_glucose_trends(
    records: List[Dict],
    period: Period,
) -> List[Dict]:
    """
    Calculate glucose trends using the requested period.
    """

    if period == "daily":
        return calculate_daily_trends(records)

    if period == "weekly":
        return calculate_weekly_trends(records)

    if period == "monthly":
        return calculate_monthly_trends(records)

    raise ValueError(
        "Period must be daily, weekly, or monthly."
    )


def _aggregate_trends(
    dataframe: pd.DataFrame,
) -> List[Dict]:
    """
    Aggregate glucose readings by period.
    """

    summary = (
        dataframe
        .groupby("period")["glucose_mg_dl"]
        .agg(
            count="count",
            mean="mean",
            minimum="min",
            maximum="max",
        )
        .reset_index()
    )

    results = []

    for _, row in summary.iterrows():
        results.append(
            {
                "period": str(row["period"]),
                "count": int(row["count"]),
                "mean": round(
                    float(row["mean"]),
                    2,
                ),
                "minimum": round(
                    float(row["minimum"]),
                    2,
                ),
                "maximum": round(
                    float(row["maximum"]),
                    2,
                ),
            }
        )

    return results
