from typing import Dict, List

from analytics.personalized_baseline import (
    learn_personalized_baseline,
)
from data.backend_adapter import (
    normalize_backend_records,
)


def build_personalized_baseline(
    records: List[Dict],
) -> Dict:
    """
    Build a personalized historical glucose baseline
    from DiaMate patient records.

    The records are first normalized using the existing
    backend adapter and are then passed to the
    personalized baseline analytics module.

    The resulting baselines describe the patient's
    historical glucose patterns only. They are not
    medical target ranges.
    """

    if not records:
        raise ValueError(
            "Patient records are required."
        )

    # --------------------------------------------------------
    # Normalize backend records
    # --------------------------------------------------------

    normalized = normalize_backend_records(
        records
    )

    if normalized.empty:
        raise ValueError(
            "Normalized patient history cannot be empty."
        )

    # --------------------------------------------------------
    # Ensure exactly one patient
    # --------------------------------------------------------

    patient_ids = (
        normalized["patient_id"]
        .dropna()
        .astype(str)
        .unique()
    )

    if len(patient_ids) != 1:
        raise ValueError(
            "Personalized baseline learning requires "
            "records from exactly one patient."
        )

    # --------------------------------------------------------
    # Sort records chronologically
    # --------------------------------------------------------

    normalized = normalized.sort_values(
        by="timestamp"
    ).reset_index(
        drop=True
    )

    # --------------------------------------------------------
    # Learn personalized baseline
    # --------------------------------------------------------

    baseline = learn_personalized_baseline(
        normalized
    )

    # --------------------------------------------------------
    # Add service metadata
    # --------------------------------------------------------

    return {
        **baseline,
        "source": "patient_history",
        "purpose": (
            "personalized_baseline_learning"
        ),
    }
