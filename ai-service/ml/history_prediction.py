from typing import Dict, List

import pandas as pd

from data.backend_adapter import create_patient_features
from ml.prediction import predict_with_saved_model


def build_prediction_features_from_history(
    records: List[Dict],
) -> Dict:
    """
    Build XGBoost prediction features automatically
    from one patient's backend-format history.

    The latest record is treated as time t.

    No future glucose information is used.
    """

    if not records:
        raise ValueError(
            "Patient history cannot be empty."
        )

    dataframe = create_patient_features(
        records
    )

    patient_count = (
        dataframe["patient_id"].nunique()
    )

    if patient_count != 1:
        raise ValueError(
            "Prediction history must contain "
            "exactly one patient."
        )

    if len(dataframe) < 2:
        raise ValueError(
            "At least two patient records are "
            "required for prediction."
        )

    latest_record = dataframe.iloc[-1]

    previous_glucose = latest_record[
        "previous_glucose"
    ]

    if pd.isna(previous_glucose):
        raise ValueError(
            "Previous glucose value is required "
            "for prediction."
        )

    return {
        "glucose_mg_dl": float(
            latest_record["glucose_mg_dl"]
        ),
        "previous_glucose": float(
            previous_glucose
        ),
        "carbs_g": float(
            latest_record["carbs_g"]
        ),
        "activity_minutes": float(
            latest_record["activity_minutes"]
        ),
        "hour_of_day": int(
            latest_record["hour_of_day"]
        ),
        "day_of_week": int(
            latest_record["day_of_week"]
        ),
        "month": int(
            latest_record["month"]
        ),
        "is_weekend": int(
            latest_record["is_weekend"]
        ),
    }


def predict_from_patient_history(
    records: List[Dict],
) -> Dict:
    """
    Generate an experimental next-glucose-trend
    classification from backend-format patient history.

    This function does not provide diagnosis,
    medication dosing, or treatment recommendations.
    """

    features = (
        build_prediction_features_from_history(
            records
        )
    )

    prediction = predict_with_saved_model(
        features
    )

    return {
        **prediction,
        "source": "patient_history",
        "history_record_count": len(
            records
        ),
    }
