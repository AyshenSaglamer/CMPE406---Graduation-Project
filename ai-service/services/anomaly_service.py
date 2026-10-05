from typing import Dict, List

import pandas as pd

from analytics.anomaly_detection import (
    DEFAULT_Z_THRESHOLD,
    MIN_BASELINE_SIZE,
    detect_glucose_anomaly,
)
from analytics.personalized_baseline import (
    _get_time_period,
)
from data.backend_adapter import (
    normalize_backend_records,
)


def analyze_patient_glucose_anomaly(
    records: List[Dict],
    z_threshold: float = DEFAULT_Z_THRESHOLD,
) -> Dict:
    """
    Analyze the latest glucose reading relative to the
    patient's own historical glucose pattern.

    If enough historical observations exist for the same
    time-of-day period as the current reading, a contextual
    baseline is used.

    Otherwise, the service falls back to the patient's
    overall historical baseline.

    The latest observation is excluded from the baseline
    to prevent data leakage.
    """

    # ========================================================
    # BASIC INPUT VALIDATION
    # ========================================================

    if not records:
        raise ValueError(
            "Patient history cannot be empty."
        )

    required_total_records = (
        MIN_BASELINE_SIZE + 1
    )

    if len(records) < required_total_records:
        raise ValueError(
            f"At least {required_total_records} "
            "patient history records are required "
            "for anomaly detection."
        )

    # ========================================================
    # NORMALIZE BACKEND RECORDS
    # ========================================================

    normalized = normalize_backend_records(
        records
    )

    if normalized.empty:
        raise ValueError(
            "Patient history cannot be empty."
        )

    # ========================================================
    # ENSURE RECORDS BELONG TO ONE PATIENT
    # ========================================================

    patient_ids = (
        normalized["patient_id"]
        .dropna()
        .astype(str)
        .unique()
    )

    if len(patient_ids) != 1:
        raise ValueError(
            "Anomaly detection requires records "
            "from exactly one patient."
        )

    # ========================================================
    # SORT RECORDS CHRONOLOGICALLY
    # ========================================================

    normalized = (
        normalized
        .sort_values(
            by="timestamp"
        )
        .reset_index(
            drop=True
        )
    )

    if len(normalized) < required_total_records:
        raise ValueError(
            f"At least {required_total_records} "
            "patient history records are required "
            "for anomaly detection."
        )

    # ========================================================
    # SEPARATE CURRENT READING FROM HISTORY
    # ========================================================

    # The latest record is the value that we want to
    # evaluate.
    current_record = (
        normalized.iloc[-1]
    )

    # All earlier records form the available history.
    #
    # IMPORTANT:
    # The current reading is NOT included here.
    # This prevents data leakage.
    historical_records = (
        normalized.iloc[:-1]
        .copy()
    )

    current_value = float(
        current_record[
            "glucose_mg_dl"
        ]
    )

    current_timestamp = pd.Timestamp(
        current_record[
            "timestamp"
        ]
    )

    # ========================================================
    # IDENTIFY CURRENT TIME-OF-DAY CONTEXT
    # ========================================================

    current_hour = (
        current_timestamp.hour
    )

    current_time_period = (
        _get_time_period(
            current_hour
        )
    )

    # Example:
    #
    # 08:00 -> MORNING
    # 14:00 -> AFTERNOON
    # 19:00 -> EVENING
    # 01:00 -> NIGHT

    # ========================================================
    # LABEL HISTORICAL RECORDS BY TIME PERIOD
    # ========================================================

    historical_records[
        "time_period"
    ] = historical_records[
        "timestamp"
    ].apply(
        lambda timestamp: (
            _get_time_period(
                pd.Timestamp(
                    timestamp
                ).hour
            )
        )
    )

    # ========================================================
    # FIND MATCHING CONTEXTUAL HISTORY
    # ========================================================

    contextual_records = (
        historical_records[
            historical_records[
                "time_period"
            ]
            == current_time_period
        ]
        .copy()
    )

    contextual_record_count = int(
        len(
            contextual_records
        )
    )

    # ========================================================
    # SELECT PERSONALIZED BASELINE
    # ========================================================

    # If we have enough historical records from the same
    # time period, use those records.
    #
    # Example:
    #
    # Current reading:
    #   Monday 08:00
    #
    # Historical MORNING readings:
    #   7 records
    #
    # -> Use MORNING baseline.

    if (
        contextual_record_count
        >= MIN_BASELINE_SIZE
    ):
        baseline_records = (
            contextual_records
        )

        baseline_type = (
            "TIME_OF_DAY"
        )

        baseline_context = (
            current_time_period
        )

        fallback_used = False

    # --------------------------------------------------------
    # FALLBACK
    # --------------------------------------------------------
    #
    # If there are not enough historical records for the
    # same time period, use all previous records instead.
    #
    # Example:
    #
    # Current reading:
    #   08:00 -> MORNING
    #
    # Historical MORNING readings:
    #   only 2
    #
    # -> Not enough
    # -> Use OVERALL historical baseline.

    else:
        baseline_records = (
            historical_records
        )

        baseline_type = (
            "OVERALL"
        )

        baseline_context = (
            "ALL_HISTORICAL_RECORDS"
        )

        fallback_used = True

    # ========================================================
    # EXTRACT BASELINE GLUCOSE VALUES
    # ========================================================

    historical_values = (
        baseline_records[
            "glucose_mg_dl"
        ]
        .astype(float)
        .tolist()
    )

    baseline_record_count = int(
        len(
            baseline_records
        )
    )

    # ========================================================
    # RUN STATISTICAL ANOMALY DETECTION
    # ========================================================

    anomaly_result = (
        detect_glucose_anomaly(
            historical_values=(
                historical_values
            ),
            current_value=(
                current_value
            ),
            z_threshold=(
                z_threshold
            ),
        )
    )

    # ========================================================
    # BUILD RESPONSE
    # ========================================================

    return {
        # ----------------------------------------------------
        # PATIENT INFORMATION
        # ----------------------------------------------------

        "patient_id": str(
            current_record[
                "patient_id"
            ]
        ),

        # ----------------------------------------------------
        # CURRENT OBSERVATION
        # ----------------------------------------------------

        "current_timestamp": (
            current_timestamp.isoformat()
        ),

        "current_time_period": (
            current_time_period
        ),

        # ----------------------------------------------------
        # BACKWARD-COMPATIBLE FIELDS
        # ----------------------------------------------------
        #
        # These fields existed before context-aware
        # baseline selection was added.
        #
        # We keep them so older tests and integrations
        # continue to work.

        "baseline_record_count": (
            baseline_record_count
        ),

        "current_record_excluded_from_baseline": (
            True
        ),

        # ----------------------------------------------------
        # HISTORY INFORMATION
        # ----------------------------------------------------

        "history_record_count": int(
            len(
                normalized
            )
        ),

        "available_historical_record_count": int(
            len(
                historical_records
            )
        ),

        "contextual_historical_record_count": (
            contextual_record_count
        ),

        # ----------------------------------------------------
        # BASELINE SELECTION INFORMATION
        # ----------------------------------------------------

        "baseline_selection": {
            "type": (
                baseline_type
            ),

            "context": (
                baseline_context
            ),

            "record_count": (
                baseline_record_count
            ),

            "minimum_required": (
                MIN_BASELINE_SIZE
            ),

            "fallback_used": (
                fallback_used
            ),
        },

        # ----------------------------------------------------
        # STATISTICAL ANOMALY RESULT
        # ----------------------------------------------------

        "anomaly": (
            anomaly_result
        ),

        # ----------------------------------------------------
        # RESPONSE METADATA
        # ----------------------------------------------------

        "source": (
            "patient_history"
        ),

        # Keep the old purpose value for backward
        # compatibility.
        "purpose": (
            "personalized_glucose_anomaly_detection"
        ),

        # This new field describes the improved method.
        "method": (
            "context_aware_personalized_"
            "baseline_z_score"
        ),

        # ----------------------------------------------------
        # SAFETY
        # ----------------------------------------------------

        "disclaimer": (
            "The selected baseline represents the "
            "patient's historical statistical pattern. "
            "It is not a medical target range. "
            "Anomaly results indicate statistical "
            "unusualness only and must not be interpreted "
            "as diagnosis, clinical risk, treatment, or "
            "medication advice."
        ),
    }
