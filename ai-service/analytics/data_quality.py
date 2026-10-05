from typing import Dict

import numpy as np
import pandas as pd


REQUIRED_COLUMNS = {
    "patient_id",
    "timestamp",
    "glucose_mg_dl",
    "carbs_g",
    "activity_minutes",
}


def _validate_dataframe(
    dataframe: pd.DataFrame,
) -> None:
    """
    Validate the basic structure required for
    DiaMate patient-history quality analysis.
    """

    if dataframe is None:
        raise ValueError(
            "Patient history cannot be None."
        )

    if dataframe.empty:
        raise ValueError(
            "Patient history cannot be empty."
        )

    missing_columns = (
        REQUIRED_COLUMNS
        - set(dataframe.columns)
    )

    if missing_columns:
        missing = ", ".join(
            sorted(missing_columns)
        )

        raise ValueError(
            f"Missing required columns: {missing}"
        )


def _calculate_missing_values(
    dataframe: pd.DataFrame,
) -> Dict:
    """
    Count missing values for each required field.
    """

    missing_by_field = {}

    for column in sorted(
        REQUIRED_COLUMNS
    ):
        count = int(
            dataframe[column]
            .isna()
            .sum()
        )

        missing_by_field[column] = count

    total_missing = int(
        sum(
            missing_by_field.values()
        )
    )

    return {
        "total_missing_values": (
            total_missing
        ),
        "missing_by_field": (
            missing_by_field
        ),
        "has_missing_values": (
            total_missing > 0
        ),
    }


def _calculate_duplicate_records(
    dataframe: pd.DataFrame,
) -> Dict:
    """
    Detect exact duplicate patient-history rows.
    """

    duplicate_mask = (
        dataframe.duplicated(
            keep="first"
        )
    )

    duplicate_count = int(
        duplicate_mask.sum()
    )

    return {
        "duplicate_record_count": (
            duplicate_count
        ),
        "has_duplicate_records": (
            duplicate_count > 0
        ),
    }


def _calculate_time_gaps(
    dataframe: pd.DataFrame,
    large_gap_hours: float,
) -> Dict:
    """
    Analyze time gaps between sequential records.

    A large gap is an engineering/data-quality
    indicator, not a medical threshold.
    """

    timestamps = pd.to_datetime(
        dataframe["timestamp"],
        errors="coerce",
    )

    invalid_timestamp_count = int(
        timestamps.isna().sum()
    )

    valid_timestamps = (
        timestamps
        .dropna()
        .sort_values()
    )

    if len(valid_timestamps) < 2:
        return {
            "invalid_timestamp_count": (
                invalid_timestamp_count
            ),
            "largest_gap_hours": None,
            "large_gap_count": 0,
            "large_gap_threshold_hours": (
                large_gap_hours
            ),
        }

    gaps = (
        valid_timestamps
        .diff()
        .dropna()
        .dt.total_seconds()
        / 3600.0
    )

    largest_gap = float(
        gaps.max()
    )

    large_gap_count = int(
        (
            gaps > large_gap_hours
        ).sum()
    )

    return {
        "invalid_timestamp_count": (
            invalid_timestamp_count
        ),
        "largest_gap_hours": round(
            largest_gap,
            4,
        ),
        "large_gap_count": (
            large_gap_count
        ),
        "large_gap_threshold_hours": (
            large_gap_hours
        ),
    }


def analyze_data_quality(
    dataframe: pd.DataFrame,
    large_gap_hours: float = 24.0,
) -> Dict:
    """
    Analyze the quality of DiaMate patient-history data.

    The function checks:
    - missing values
    - duplicate records
    - invalid timestamps
    - unusually large logging gaps

    These checks describe data quality only.
    """

    _validate_dataframe(
        dataframe
    )

    if (
        not np.isfinite(
            large_gap_hours
        )
        or large_gap_hours <= 0
    ):
        raise ValueError(
            "large_gap_hours must be "
            "a positive finite number."
        )

    working = dataframe.copy()

    missing_result = (
        _calculate_missing_values(
            working
        )
    )

    duplicate_result = (
        _calculate_duplicate_records(
            working
        )
    )

    gap_result = (
        _calculate_time_gaps(
            working,
            large_gap_hours,
        )
    )

    issues = []

    if missing_result[
        "has_missing_values"
    ]:
        issues.append(
            "MISSING_VALUES"
        )

    if duplicate_result[
        "has_duplicate_records"
    ]:
        issues.append(
            "DUPLICATE_RECORDS"
        )

    if (
        gap_result[
            "invalid_timestamp_count"
        ]
        > 0
    ):
        issues.append(
            "INVALID_TIMESTAMPS"
        )

    if (
        gap_result[
            "large_gap_count"
        ]
        > 0
    ):
        issues.append(
            "LARGE_LOGGING_GAPS"
        )

    return {
        "record_count": int(
            len(working)
        ),
        "quality_status": (
            "GOOD"
            if not issues
            else "ISSUES_DETECTED"
        ),
        "issues": issues,
        "missing_values": (
            missing_result
        ),
        "duplicates": (
            duplicate_result
        ),
        "time_gaps": (
            gap_result
        ),
        "scope": (
            "patient_history_data_quality"
        ),
        "method": (
            "deterministic_quality_checks"
        ),
        "disclaimer": (
            "This report describes data quality and "
            "logging completeness only. It does not "
            "represent medical status, diagnosis, "
            "clinical risk, or treatment advice."
        ),
    }
