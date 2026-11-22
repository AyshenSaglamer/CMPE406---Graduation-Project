from unittest.mock import patch

import pytest

from ml.history_prediction import (
    build_prediction_features_from_history,
    predict_from_patient_history,
)


def create_history():
    return [
        {
            "patient_id": "patient_123",
            "timestamp": "2026-10-01T10:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 25,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient_123",
            "timestamp": "2026-10-01T14:00:00",
            "glucose_mg_dl": 145,
            "carbs_g": 40,
            "activity_minutes": 20,
        },
    ]


def test_build_features_from_history():
    features = (
        build_prediction_features_from_history(
            create_history()
        )
    )

    assert features == {
        "glucose_mg_dl": 145.0,
        "previous_glucose": 120.0,
        "carbs_g": 40.0,
        "activity_minutes": 20.0,
        "hour_of_day": 14,
        "day_of_week": 3,
        "month": 10,
        "is_weekend": 0,
    }


def test_unsorted_history_is_sorted():
    records = create_history()

    records.reverse()

    features = (
        build_prediction_features_from_history(
            records
        )
    )

    assert (
        features["glucose_mg_dl"]
        == 145.0
    )

    assert (
        features["previous_glucose"]
        == 120.0
    )


def test_latest_record_is_used():
    records = create_history()

    records.append(
        {
            "patient_id": "patient_123",
            "timestamp": "2026-10-01T18:00:00",
            "glucose_mg_dl": 155,
            "carbs_g": 30,
            "activity_minutes": 15,
        }
    )

    features = (
        build_prediction_features_from_history(
            records
        )
    )

    assert (
        features["glucose_mg_dl"]
        == 155.0
    )

    assert (
        features["previous_glucose"]
        == 145.0
    )

    assert features["hour_of_day"] == 18


def test_empty_history_rejected():
    with pytest.raises(
        ValueError,
        match="Patient history cannot be empty",
    ):
        build_prediction_features_from_history(
            []
        )


def test_single_record_rejected():
    records = [
        create_history()[0]
    ]

    with pytest.raises(
        ValueError,
        match=(
            "At least two patient records "
            "are required"
        ),
    ):
        build_prediction_features_from_history(
            records
        )


def test_multiple_patients_rejected():
    records = create_history()

    records.append(
        {
            "patient_id": "patient_999",
            "timestamp": "2026-10-01T18:00:00",
            "glucose_mg_dl": 160,
            "carbs_g": 30,
            "activity_minutes": 10,
        }
    )

    with pytest.raises(
        ValueError,
        match=(
            "Prediction history must contain "
            "exactly one patient"
        ),
    ):
        build_prediction_features_from_history(
            records
        )


def test_weekend_is_derived_from_timestamp():
    records = [
        {
            "patient_id": "patient_123",
            "timestamp": "2026-10-03T10:00:00",
            "glucose_mg_dl": 120,
            "carbs_g": 20,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient_123",
            "timestamp": "2026-10-03T14:00:00",
            "glucose_mg_dl": 130,
            "carbs_g": 30,
            "activity_minutes": 20,
        },
    ]

    features = (
        build_prediction_features_from_history(
            records
        )
    )

    assert features["is_weekend"] == 1


@patch(
    "ml.history_prediction."
    "predict_with_saved_model"
)
def test_prediction_receives_derived_features(
    mock_predict,
):
    mock_predict.return_value = {
        "prediction": "STABLE",
        "probabilities": {
            "HIGHER": 0.10,
            "LOWER": 0.10,
            "STABLE": 0.80,
        },
        "model_type": "XGBoost",
        "prediction_target": (
            "next_glucose_trend"
        ),
    }

    result = (
        predict_from_patient_history(
            create_history()
        )
    )

    mock_predict.assert_called_once()

    features = (
        mock_predict.call_args.args[0]
    )

    assert (
        features["glucose_mg_dl"]
        == 145.0
    )

    assert (
        features["previous_glucose"]
        == 120.0
    )

    assert result["source"] == (
        "patient_history"
    )

    assert (
        result["history_record_count"]
        == 2
    )


@patch(
    "ml.history_prediction."
    "predict_with_saved_model"
)
def test_future_values_are_not_sent_to_model(
    mock_predict,
):
    mock_predict.return_value = {
        "prediction": "STABLE",
    }

    predict_from_patient_history(
        create_history()
    )

    features = (
        mock_predict.call_args.args[0]
    )

    assert "next_glucose" not in features

    assert (
        "future_glucose_change"
        not in features
    )

    assert "trend_target" not in features
