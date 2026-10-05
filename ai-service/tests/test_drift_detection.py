import numpy as np
import pandas as pd
import pytest

from ml.drift_detection import (
    detect_model_input_drift,
)


def reference_dataframe():
    """
    Reference data representing the model's
    historical input distribution.
    """

    return pd.DataFrame(
        {
            "glucose_mg_dl": [
                110,
                120,
                130,
                125,
                115,
            ],
            "previous_glucose": [
                108,
                118,
                128,
                123,
                113,
            ],
            "carbs_g": [
                30,
                40,
                35,
                45,
                25,
            ],
            "activity_minutes": [
                20,
                30,
                25,
                35,
                15,
            ],
            "hour_of_day": [
                8,
                10,
                12,
                14,
                16,
            ],
            "day_of_week": [
                0,
                1,
                2,
                3,
                4,
            ],
            "month": [
                9,
                9,
                9,
                9,
                9,
            ],
            "is_weekend": [
                0,
                0,
                0,
                0,
                0,
            ],
        }
    )


def similar_current_dataframe():
    """
    Current data that remains close to the
    reference distribution.
    """

    return pd.DataFrame(
        {
            "glucose_mg_dl": [
                118,
                121,
                122,
            ],
            "previous_glucose": [
                116,
                119,
                120,
            ],
            "carbs_g": [
                34,
                36,
                35,
            ],
            "activity_minutes": [
                24,
                26,
                25,
            ],
            "hour_of_day": [
                11,
                12,
                13,
            ],
            "day_of_week": [
                1,
                2,
                3,
            ],
            "month": [
                9,
                9,
                9,
            ],
            "is_weekend": [
                0,
                0,
                0,
            ],
        }
    )


def drifted_current_dataframe():
    """
    Current data containing a clear glucose shift.
    """

    data = similar_current_dataframe()

    data["glucose_mg_dl"] = [
        170,
        180,
        190,
    ]

    return data


def test_similar_data_has_no_drift():
    result = detect_model_input_drift(
        reference_dataframe(),
        similar_current_dataframe(),
    )

    assert (
        result["drift_detected"]
        is False
    )

    assert (
        result["status"]
        == "NO_DRIFT_DETECTED"
    )

    assert (
        result["drifted_features"]
        == []
    )

    assert (
        result["drifted_feature_count"]
        == 0
    )


def test_clear_glucose_shift_detects_drift():
    result = detect_model_input_drift(
        reference_dataframe(),
        drifted_current_dataframe(),
    )

    assert (
        result["drift_detected"]
        is True
    )

    assert (
        result["status"]
        == "DRIFT_DETECTED"
    )

    assert (
        "glucose_mg_dl"
        in result["drifted_features"]
    )

    assert (
        result["features"][
            "glucose_mg_dl"
        ][
            "drift_detected"
        ]
        is True
    )


def test_feature_statistics_are_returned():
    result = detect_model_input_drift(
        reference_dataframe(),
        drifted_current_dataframe(),
    )

    glucose = result[
        "features"
    ][
        "glucose_mg_dl"
    ]

    assert (
        "reference_mean"
        in glucose
    )

    assert (
        "current_mean"
        in glucose
    )

    assert (
        "reference_std"
        in glucose
    )

    assert (
        "absolute_mean_difference"
        in glucose
    )

    assert (
        "standardized_mean_shift"
        in glucose
    )


def test_record_counts_are_returned():
    result = detect_model_input_drift(
        reference_dataframe(),
        similar_current_dataframe(),
    )

    assert (
        result["reference_record_count"]
        == 5
    )

    assert (
        result["current_record_count"]
        == 3
    )


def test_custom_threshold_is_used():
    result = detect_model_input_drift(
        reference_dataframe(),
        similar_current_dataframe(),
        mean_shift_threshold=2.0,
    )

    assert (
        result["mean_shift_threshold"]
        == 2.0
    )


def test_missing_reference_feature_is_rejected():
    reference = reference_dataframe()

    reference = reference.drop(
        columns=[
            "carbs_g"
        ]
    )

    with pytest.raises(
        ValueError,
        match="missing features",
    ):
        detect_model_input_drift(
            reference,
            similar_current_dataframe(),
        )


def test_missing_current_feature_is_rejected():
    current = (
        similar_current_dataframe()
        .drop(
            columns=[
                "activity_minutes"
            ]
        )
    )

    with pytest.raises(
        ValueError,
        match="missing features",
    ):
        detect_model_input_drift(
            reference_dataframe(),
            current,
        )


def test_too_few_reference_records_are_rejected():
    reference = (
        reference_dataframe()
        .iloc[:4]
    )

    with pytest.raises(
        ValueError,
        match="at least 5 records",
    ):
        detect_model_input_drift(
            reference,
            similar_current_dataframe(),
        )


def test_too_few_current_records_are_rejected():
    current = (
        similar_current_dataframe()
        .iloc[:2]
    )

    with pytest.raises(
        ValueError,
        match="at least 3 records",
    ):
        detect_model_input_drift(
            reference_dataframe(),
            current,
        )


def test_nan_value_is_rejected():
    reference = reference_dataframe()

    reference.loc[
        0,
        "glucose_mg_dl",
    ] = np.nan

    with pytest.raises(
        ValueError,
        match="numeric values",
    ):
        detect_model_input_drift(
            reference,
            similar_current_dataframe(),
        )

def test_infinite_value_is_rejected():
    current = (
        similar_current_dataframe()
    )

    # Convert the column to float first so that
    # Pandas can represent infinity.
    current["glucose_mg_dl"] = (
        current["glucose_mg_dl"]
        .astype(float)
    )

    current.loc[
        0,
        "glucose_mg_dl",
    ] = np.inf

    with pytest.raises(
        ValueError,
        match="finite values",
    ):
        detect_model_input_drift(
            reference_dataframe(),
            current,
        )

@pytest.mark.parametrize(
    "threshold",
    [
        0,
        -1,
        float("inf"),
        float("-inf"),
        float("nan"),
    ],
)
def test_invalid_threshold_is_rejected(
    threshold,
):
    with pytest.raises(
        ValueError,
        match="positive finite number",
    ):
        detect_model_input_drift(
            reference_dataframe(),
            similar_current_dataframe(),
            mean_shift_threshold=threshold,
        )


def test_non_numeric_threshold_is_rejected():
    with pytest.raises(
        ValueError,
        match="must be numeric",
    ):
        detect_model_input_drift(
            reference_dataframe(),
            similar_current_dataframe(),
            mean_shift_threshold="hello",
        )


def test_zero_variance_same_value_has_no_drift():
    reference = reference_dataframe()
    current = similar_current_dataframe()

    reference["month"] = 9
    current["month"] = 9

    result = detect_model_input_drift(
        reference,
        current,
    )

    month_result = (
        result["features"]["month"]
    )

    assert (
        month_result[
            "reference_std"
        ]
        == 0.0
    )

    assert (
        month_result[
            "standardized_mean_shift"
        ]
        == 0.0
    )

    assert (
        month_result[
            "drift_detected"
        ]
        is False
    )


def test_zero_variance_changed_value_detects_drift():
    reference = reference_dataframe()
    current = similar_current_dataframe()

    reference["month"] = 9
    current["month"] = 10

    result = detect_model_input_drift(
        reference,
        current,
    )

    month_result = (
        result["features"]["month"]
    )

    assert (
        month_result[
            "reference_std"
        ]
        == 0.0
    )

    assert (
        month_result[
            "standardized_mean_shift"
        ]
        is None
    )

    assert (
        month_result[
            "drift_detected"
        ]
        is True
    )


def test_metadata_is_returned():
    result = detect_model_input_drift(
        reference_dataframe(),
        similar_current_dataframe(),
    )

    assert (
        result["method"]
        == "standardized_mean_shift"
    )

    assert (
        result["scope"]
        == "model_input_data_drift"
    )


def test_safety_disclaimer_is_returned():
    result = detect_model_input_drift(
        reference_dataframe(),
        similar_current_dataframe(),
    )

    disclaimer = (
        result["disclaimer"]
        .lower()
    )

    assert "diagnosis" in disclaimer

    assert (
        "clinical deterioration"
        in disclaimer
    )

    assert "treatment" in disclaimer

    assert (
        "prediction is incorrect"
        in disclaimer
    )
