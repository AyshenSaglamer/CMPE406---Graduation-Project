from typing import Dict, List

import math
import numpy as np
import pandas as pd

from ml.future_target_builder import MODEL_FEATURES


DEFAULT_MEAN_SHIFT_THRESHOLD = 1.0
MIN_REFERENCE_RECORDS = 5
MIN_CURRENT_RECORDS = 3


def _validate_dataframe(
    dataframe: pd.DataFrame,
    *,
    name: str,
    minimum_records: int,
) -> pd.DataFrame:
    """
    Validate a dataset used for model-drift analysis.
    """

    if dataframe is None:
        raise ValueError(
            f"{name} data cannot be None."
        )

    if dataframe.empty:
        raise ValueError(
            f"{name} data cannot be empty."
        )

    if len(dataframe) < minimum_records:
        raise ValueError(
            f"{name} data requires at least "
            f"{minimum_records} records."
        )

    missing_features = [
        feature
        for feature in MODEL_FEATURES
        if feature not in dataframe.columns
    ]

    if missing_features:
        raise ValueError(
            f"{name} data is missing features: "
            + ", ".join(missing_features)
        )

    cleaned = dataframe.copy()

    for feature in MODEL_FEATURES:
        cleaned[feature] = pd.to_numeric(
            cleaned[feature],
            errors="coerce",
        )

        if cleaned[feature].isna().any():
            raise ValueError(
                f"{name} feature {feature} "
                "must contain numeric values."
            )

        values = cleaned[
            feature
        ].to_numpy(dtype=float)

        if not np.isfinite(values).all():
            raise ValueError(
                f"{name} feature {feature} "
                "must contain finite values."
            )

    return cleaned


def _calculate_feature_drift(
    reference_values: np.ndarray,
    current_values: np.ndarray,
    threshold: float,
) -> Dict:
    """
    Compare one feature between reference and current data.

    Mean shift is standardized using the reference
    standard deviation.
    """

    reference_mean = float(
        np.mean(reference_values)
    )

    current_mean = float(
        np.mean(current_values)
    )

    reference_std = float(
        np.std(
            reference_values,
            ddof=0,
        )
    )

    absolute_mean_difference = abs(
        current_mean - reference_mean
    )

    if reference_std == 0.0:
        if absolute_mean_difference == 0.0:
            standardized_shift = 0.0
        else:
            standardized_shift = None

        drift_detected = (
            absolute_mean_difference > 0.0
        )

    else:
        standardized_shift = (
            absolute_mean_difference
            / reference_std
        )

        drift_detected = (
            standardized_shift
            >= threshold
        )

    return {
        "reference_mean": round(
            reference_mean,
            6,
        ),
        "current_mean": round(
            current_mean,
            6,
        ),
        "reference_std": round(
            reference_std,
            6,
        ),
        "absolute_mean_difference": round(
            absolute_mean_difference,
            6,
        ),
        "standardized_mean_shift": (
            None
            if standardized_shift is None
            else round(
                standardized_shift,
                6,
            )
        ),
        "drift_detected": bool(
            drift_detected
        ),
    }


def detect_model_input_drift(
    reference_data: pd.DataFrame,
    current_data: pd.DataFrame,
    mean_shift_threshold: float = (
        DEFAULT_MEAN_SHIFT_THRESHOLD
    ),
) -> Dict:
    """
    Compare reference model-input data with newer data.

    This function detects descriptive input-data drift.
    It does not determine whether the model is medically
    correct or clinically safe.
    """

    try:
        threshold = float(
            mean_shift_threshold
        )
    except (TypeError, ValueError):
        raise ValueError(
            "mean_shift_threshold must be numeric."
        )

    if (
        not math.isfinite(threshold)
        or threshold <= 0.0
    ):
        raise ValueError(
            "mean_shift_threshold must be a "
            "positive finite number."
        )

    reference = _validate_dataframe(
        reference_data,
        name="Reference",
        minimum_records=MIN_REFERENCE_RECORDS,
    )

    current = _validate_dataframe(
        current_data,
        name="Current",
        minimum_records=MIN_CURRENT_RECORDS,
    )

    feature_results = {}
    drifted_features: List[str] = []

    for feature in MODEL_FEATURES:
        result = _calculate_feature_drift(
            reference[
                feature
            ].to_numpy(dtype=float),
            current[
                feature
            ].to_numpy(dtype=float),
            threshold,
        )

        feature_results[
            feature
        ] = result

        if result["drift_detected"]:
            drifted_features.append(
                feature
            )

    drift_detected = (
        len(drifted_features) > 0
    )

    return {
        "drift_detected": drift_detected,
        "status": (
            "DRIFT_DETECTED"
            if drift_detected
            else "NO_DRIFT_DETECTED"
        ),
        "drifted_features": (
            drifted_features
        ),
        "drifted_feature_count": len(
            drifted_features
        ),
        "feature_count": len(
            MODEL_FEATURES
        ),
        "reference_record_count": len(
            reference
        ),
        "current_record_count": len(
            current
        ),
        "mean_shift_threshold": (
            threshold
        ),
        "features": feature_results,
        "method": (
            "standardized_mean_shift"
        ),
        "scope": (
            "model_input_data_drift"
        ),
        "disclaimer": (
            "Model-input drift describes changes in "
            "the statistical distribution of data "
            "presented to the machine-learning system. "
            "It does not represent diagnosis, clinical "
            "deterioration, medical risk, treatment "
            "advice, or evidence that an individual "
            "prediction is incorrect."
        ),
    }
