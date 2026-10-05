from typing import Dict, List

from analytics.data_quality import (
    analyze_data_quality,
)
from data.backend_adapter import (
    normalize_backend_records,
)


def build_data_quality_report(
    records: List[Dict],
    large_gap_hours: float = 24.0,
) -> Dict:
    """
    Build a data-quality report from DiaMate
    patient-history records.

    The service validates and normalizes incoming
    records before passing them to the deterministic
    data-quality analytics layer.
    """

    # ========================================================
    # BASIC INPUT VALIDATION
    # ========================================================

    if not records:
        raise ValueError(
            "Patient history cannot be empty."
        )

    # ========================================================
    # NORMALIZE BACKEND RECORDS
    # ========================================================

    normalized = normalize_backend_records(
        records
    )

    if normalized.empty:
        raise ValueError(
            "Normalized patient history cannot be empty."
        )

    # ========================================================
    # ENSURE ONE PATIENT ONLY
    # ========================================================

    patient_ids = (
        normalized["patient_id"]
        .dropna()
        .astype(str)
        .unique()
    )

    if len(patient_ids) != 1:
        raise ValueError(
            "Data quality analysis requires records "
            "from exactly one patient."
        )

    patient_id = str(
        patient_ids[0]
    )

    # ========================================================
    # RUN DATA-QUALITY ANALYTICS
    # ========================================================

    quality_report = analyze_data_quality(
        dataframe=normalized,
        large_gap_hours=large_gap_hours,
    )

    # ========================================================
    # BUILD SERVICE RESPONSE
    # ========================================================

    return {
        "patient_id": patient_id,
        **quality_report,
        "source": "patient_history",
        "purpose": "data_quality_analysis",
    }
