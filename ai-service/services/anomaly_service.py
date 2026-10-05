from typing import Dict, List

import pandas as pd

from analytics.anomaly_detection import (
    DEFAULT_Z_THRESHOLD,
    MIN_BASELINE_SIZE,
    detect_glucose_anomaly,
)
from data.backend_adapter import (
    normalize_backend_records,
)


def analyze_patient_glucose_anomaly(
    records: List[Dict],
    z_threshold: float = DEFAULT_Z_THRESHOLD,
) -> Dict:
    """
    Analyze the most recent glucose reading against
    the same patient's previous glucose history.

    The latest reading is treated as the current
    observation.

    All earlier readings are used to create the
    patient's personal statistical baseline.

    The current reading is intentionally excluded
    from the baseline to avoid data leakage.

    This function detects statistical unusualness
    only. It does not provide diagnosis, clinical
    risk classification, treatment, or medication
    advice.
    """

    if not records:
        raise ValueError(
            "Patient history cannot be empty."
        )

    normalized = normalize_backend_records(
        records
    )

    if normalized.empty:
        raise ValueError(
            "Patient history cannot be empty."
        )

    patient_ids = normalized[
        "patient_id"
    ].unique()

    if len(patient_ids) != 1:
        raise ValueError(
            "Anomaly detection requires records "
            "from exactly one patient."
        )

    normalized = normalized.sort_values(
        by="timestamp"
    ).reset_index(
        drop=True
    )

    required_total_records = (
        MIN_BASELINE_SIZE + 1
    )

    if len(normalized) < required_total_records:
        raise ValueError(
            f"At least {required_total_records} patient "
            "history records are required: "
            f"{MIN_BASELINE_SIZE} for the personal "
            "baseline and 1 current reading."
        )

    current_record = normalized.iloc[-1]

    historical_records = normalized.iloc[:-1]

    historical_values = (
        historical_records[
            "glucose_mg_dl"
        ]
        .astype(float)
        .tolist()
    )

    current_value = float(
        current_record[
            "glucose_mg_dl"
        ]
    )

    anomaly_result = detect_glucose_anomaly(
        historical_values=historical_values,
        current_value=current_value,
        z_threshold=z_threshold,
    )

    return {
        "patient_id": str(
            current_record[
                "patient_id"
            ]
        ),
        "current_timestamp": (
            pd.Timestamp(
                current_record[
                    "timestamp"
                ]
            ).isoformat()
        ),
        "history_record_count": int(
            len(normalized)
        ),
        "baseline_record_count": int(
            len(historical_records)
        ),
        "anomaly": anomaly_result,
        "source": "patient_history",
        "purpose": (
            "personalized_glucose_"
            "anomaly_detection"
        ),
    }
