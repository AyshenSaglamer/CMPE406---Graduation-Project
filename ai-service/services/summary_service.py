from typing import Dict, List

from analytics.glucose_analytics import (
    calculate_glucose_statistics,
    calculate_time_in_range,
)
from data.backend_adapter import (
    normalize_backend_records,
)
from ml.history_prediction import (
    predict_from_patient_history,
)
from services.insight_service import (
    generate_insights,
)
from services.pattern_service import (
    analyze_patient_patterns,
)


def build_patient_summary(
    records: List[Dict],
    range_low: float = 70.0,
    range_high: float = 180.0,
) -> Dict:
    """
    Build a unified patient AI summary containing:

    - descriptive glucose analytics
    - configured time-in-range analysis
    - personalized descriptive patterns
    - experimental XGBoost trend prediction
    - human-readable insights

    This service supports diabetes self-management
    and does not provide diagnosis, treatment, or
    medication dosing advice.
    """

    # ========================================================
    # INPUT VALIDATION
    # ========================================================

    if not records:
        raise ValueError(
            "Patient history cannot be empty."
        )

    if (
        range_low <= 0
        or range_high <= 0
    ):
        raise ValueError(
            "Range bounds must be greater "
            "than zero."
        )

    if range_low >= range_high:
        raise ValueError(
            "range_low must be lower "
            "than range_high."
        )

    # ========================================================
    # NORMALIZE BACKEND DATA
    # ========================================================

    dataframe = normalize_backend_records(
        records
    )

    patient_count = (
        dataframe["patient_id"].nunique()
    )

    if patient_count != 1:
        raise ValueError(
            "Summary history must contain "
            "exactly one patient."
        )

    patient_id = str(
        dataframe.iloc[0]["patient_id"]
    )

    # ========================================================
    # GLUCOSE ANALYTICS
    # ========================================================

    glucose_values = (
        dataframe["glucose_mg_dl"]
        .astype(float)
        .tolist()
    )

    statistics = (
        calculate_glucose_statistics(
            glucose_values
        )
    )

    time_in_range = (
        calculate_time_in_range(
            glucose_values,
            lower_bound=range_low,
            upper_bound=range_high,
        )
    )

    # ========================================================
    # PERSONALIZED PATTERN DETECTION
    # ========================================================

    patterns = analyze_patient_patterns(
        records
    )

    # ========================================================
    # XGBOOST FUTURE TREND PREDICTION
    # ========================================================

    prediction = None
    prediction_status = "NOT_AVAILABLE"

    if len(dataframe) >= 2:
        try:
            prediction = (
                predict_from_patient_history(
                    records
                )
            )

            prediction_status = "AVAILABLE"

        except FileNotFoundError:
            prediction_status = (
                "MODEL_NOT_AVAILABLE"
            )

    # ========================================================
    # GENERAL INSIGHT ENGINE
    # ========================================================

    insights = generate_insights(
        statistics=statistics,
        time_in_range=time_in_range,
        prediction=prediction,
    )

    # ========================================================
    # COMBINE INSIGHTS
    # ========================================================

    combined_insights = list(
        insights.get(
            "insights",
            [],
        )
    )

    pattern_insights = patterns.get(
        "insights",
        [],
    )

    combined_insights.extend(
        pattern_insights
    )

    combined_insight_summary = {
        "status": (
            "SUCCESS"
            if combined_insights
            else "NO_INSIGHTS"
        ),
        "insight_count": len(
            combined_insights
        ),
        "insights": combined_insights,
        "purpose": (
            "personalized_patient_summary"
        ),
        "disclaimer": (
            "These insights summarize patterns "
            "and associations in logged data. "
            "They do not establish causation and "
            "are not medical diagnosis, treatment, "
            "or medication dosing advice."
        ),
    }

    # ========================================================
    # FINAL RESPONSE
    # ========================================================

    return {
        "status": "SUCCESS",

        "patient_id": patient_id,

        "record_count": len(
            dataframe
        ),

        "configured_range": {
            "low_mg_dl": float(
                range_low
            ),
            "high_mg_dl": float(
                range_high
            ),
        },

        "analytics": {
            "glucose_statistics": (
                statistics
            ),
            "time_in_range": (
                time_in_range
            ),
        },

        "personalized_patterns": (
            patterns
        ),

        "ml_prediction": {
            "status": prediction_status,
            "result": prediction,
        },

        "insight_summary": (
            combined_insight_summary
        ),

        "purpose": (
            "diabetes_self_management_support"
        ),

        "disclaimer": (
            "This summary describes patterns "
            "and associations in logged data and "
            "does not provide medical diagnosis, "
            "treatment, or medication dosing advice."
        ),
    }
