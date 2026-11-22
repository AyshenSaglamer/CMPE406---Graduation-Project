from typing import Dict, List

import pandas as pd

from data.backend_adapter import (
    normalize_backend_records,
)
from ml.drift_detection import (
    detect_model_input_drift,
)
from ml.future_target_builder import (
    MODEL_FEATURES,
)


def _prepare_drift_features(
    records: List[Dict],
    *,
    dataset_name: str,
) -> pd.DataFrame:
    """
    Convert DiaMate patient-history records into the
    model-input features required for drift detection.
    """

    if not records:
        raise ValueError(
            f"{dataset_name} patient history "
            "cannot be empty."
        )

    dataframe = normalize_backend_records(
        records
    )

    if dataframe.empty:
        raise ValueError(
            f"{dataset_name} patient history "
            "cannot be empty after normalization."
        )

    patient_ids = (
        dataframe["patient_id"]
        .dropna()
        .astype(str)
        .unique()
    )

    if len(patient_ids) != 1:
        raise ValueError(
            f"{dataset_name} patient history "
            "must contain exactly one patient."
        )

    dataframe = dataframe.sort_values(
        "timestamp"
    ).reset_index(drop=True)

    # --------------------------------------------------------
    # TIME FEATURES
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # PREVIOUS GLUCOSE
    # --------------------------------------------------------

    if "previous_glucose" not in dataframe.columns:
        dataframe["previous_glucose"] = (
            dataframe[
                "glucose_mg_dl"
            ].shift(1)
        )

    # The first record has no previous observation.
    dataframe = dataframe.dropna(
        subset=[
            "previous_glucose"
        ]
    ).reset_index(drop=True)

    if dataframe.empty:
        raise ValueError(
            f"{dataset_name} patient history does not "
            "contain enough sequential records to build "
            "model features."
        )

    return dataframe[
        MODEL_FEATURES
    ].copy()


def analyze_model_drift(
    reference_records: List[Dict],
    current_records: List[Dict],
    mean_shift_threshold: float = 1.0,
) -> Dict:
    """
    Compare historical reference patient data with newer
    patient data to detect descriptive model-input drift.

    Drift describes changes in the model-input
    distribution only. It does not represent clinical
    deterioration or medical risk.
    """

    if not reference_records:
        raise ValueError(
            "Reference patient history cannot be empty."
        )

    if not current_records:
        raise ValueError(
            "Current patient history cannot be empty."
        )

    # ========================================================
    # IDENTIFY PATIENTS BEFORE FEATURE PREPARATION
    # ========================================================

    reference_patient_ids = {
        str(record.get("patient_id"))
        for record in reference_records
        if record.get("patient_id") is not None
    }

    current_patient_ids = {
        str(record.get("patient_id"))
        for record in current_records
        if record.get("patient_id") is not None
    }

    if len(reference_patient_ids) != 1:
        raise ValueError(
            "Reference patient history must contain "
            "exactly one patient."
        )

    if len(current_patient_ids) != 1:
        raise ValueError(
            "Current patient history must contain "
            "exactly one patient."
        )

    reference_patient_id = next(
        iter(reference_patient_ids)
    )

    current_patient_id = next(
        iter(current_patient_ids)
    )

    if (
        reference_patient_id
        != current_patient_id
    ):
        raise ValueError(
            "Reference and current patient histories "
            "must belong to the same patient."
        )

    # ========================================================
    # FEATURE PREPARATION
    # ========================================================

    reference_features = (
        _prepare_drift_features(
            reference_records,
            dataset_name="Reference",
        )
    )

    current_features = (
        _prepare_drift_features(
            current_records,
            dataset_name="Current",
        )
    )

    # ========================================================
    # DRIFT ANALYSIS
    # ========================================================

    result = detect_model_input_drift(
        reference_data=reference_features,
        current_data=current_features,
        mean_shift_threshold=(
            mean_shift_threshold
        ),
    )

    # ========================================================
    # SERVICE METADATA
    # ========================================================

    return {
        "patient_id": (
            reference_patient_id
        ),
        **result,
        "source": (
            "patient_history"
        ),
        "purpose": (
            "model_input_drift_monitoring"
        ),
    }
