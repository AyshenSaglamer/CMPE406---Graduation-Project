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


def build_patient_summary(
    records: List[Dict],
    range_low: float = 70.0,
    range_high: float = 180.0,
) -> Dict:
    """
    Build a combined descriptive analytics and
    experimental ML summary from one patient's
    historical records.

    Glucose range boundaries are supplied to this
    service and should ultimately come from the
    patient's configured profile settings.

    This service does not select medical targets
    and does not provide diagnosis, treatment,
    or medication dosing advice.
    """

    if not records:
        raise ValueError(
            "Patient history cannot be empty."
        )

    if range_low <= 0 or range_high <= 0:
        raise ValueError(
            "Range bounds must be greater than zero."
        )

    if range_low >= range_high:
        raise ValueError(
            "range_low must be lower than range_high."
        )

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

    glucose_values = (
        dataframe["glucose_mg_dl"]
        .astype(float)
        .tolist()
    )

    # -----------------------------------------------------
    # Descriptive glucose statistics
    # -----------------------------------------------------

    statistics = calculate_glucose_statistics(
        glucose_values
    )

    # -----------------------------------------------------
    # Time in range
    # -----------------------------------------------------

    time_in_range = calculate_time_in_range(
        glucose_values,
        lower_bound=range_low,
        upper_bound=range_high,
    )

    # -----------------------------------------------------
    # Experimental ML prediction
    # -----------------------------------------------------

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

    # -----------------------------------------------------
    # Explainable insight generation
    # -----------------------------------------------------

    insights = generate_insights(
        statistics=statistics,
        time_in_range=time_in_range,
        prediction=prediction,
    )

    # -----------------------------------------------------
    # Combined response
    # -----------------------------------------------------

    return {
        "status": "SUCCESS",
        "patient_id": str(
            dataframe.iloc[0]["patient_id"]
        ),
        "record_count": len(dataframe),
        "configured_range": {
            "low_mg_dl": float(range_low),
            "high_mg_dl": float(range_high),
        },
        "analytics": {
            "glucose_statistics": statistics,
            "time_in_range": time_in_range,
        },
        "ml_prediction": {
            "status": prediction_status,
            "result": prediction,
        },
        "insight_summary": insights,
        "purpose": (
            "diabetes_self_management_support"
        ),
        "disclaimer": (
            "This summary describes patterns "
            "in logged data and does not provide "
            "medical diagnosis, treatment, or "
            "medication dosing advice."
        ),
    }
