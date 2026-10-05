import pandas as pd
import pytest

from analytics.personalized_baseline import (
    MIN_BASELINE_RECORDS,
    _get_time_period,
    learn_personalized_baseline,
)


def make_patient_history():
    return pd.DataFrame(
        [
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-01T08:00:00",
                "glucose_mg_dl": 108,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-02T09:00:00",
                "glucose_mg_dl": 112,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-03T14:00:00",
                "glucose_mg_dl": 128,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-04T15:00:00",
                "glucose_mg_dl": 132,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-05T19:00:00",
                "glucose_mg_dl": 125,
            },
            {
                "patient_id": "patient-1",
                "timestamp": "2026-10-06T20:00:00",
                "glucose_mg_dl": 130,
            },
        ]
    )


def test_minimum_baseline_constant():
    assert MIN_BASELINE_RECORDS == 5


def test_time_period_morning():
    assert _get_time_period(8) == "MORNING"


def test_time_period_afternoon():
    assert _get_time_period(14) == "AFTERNOON"


def test_time_period_evening():
    assert _get_time_period(19) == "EVENING"


def test_time_period_night():
    assert _get_time_period(2) == "NIGHT"


def test_personalized_baseline_patient_id():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    assert result["patient_id"] == "patient-1"


def test_personalized_baseline_record_count():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    assert result["record_count"] == 6


def test_overall_baseline_statistics():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    baseline = result["overall_baseline"]

    assert baseline["count"] == 6
    assert baseline["minimum"] == 108.0
    assert baseline["maximum"] == 132.0
    assert baseline["mean"] == pytest.approx(
        122.5
    )


def test_morning_baseline():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    morning = result[
        "time_of_day_baselines"
    ]["MORNING"]

    assert morning["available"] is True
    assert morning["count"] == 2
    assert morning["mean"] == 110.0


def test_afternoon_baseline():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    afternoon = result[
        "time_of_day_baselines"
    ]["AFTERNOON"]

    assert afternoon["available"] is True
    assert afternoon["count"] == 2
    assert afternoon["mean"] == 130.0


def test_evening_baseline():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    evening = result[
        "time_of_day_baselines"
    ]["EVENING"]

    assert evening["available"] is True
    assert evening["count"] == 2
    assert evening["mean"] == 127.5


def test_night_baseline_unavailable():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    night = result[
        "time_of_day_baselines"
    ]["NIGHT"]

    assert night["available"] is False
    assert night["count"] == 0


def test_weekday_and_weekend_baselines_exist():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    day_types = result[
        "day_type_baselines"
    ]

    assert (
        day_types["WEEKDAY"]["available"]
        is True
    )

    assert (
        day_types["WEEKEND"]["available"]
        is True
    )


def test_scope_and_method():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    assert (
        result["scope"]
        == "personalized_historical_pattern"
    )

    assert (
        result["method"]
        == "descriptive_baseline_learning"
    )


def test_contains_safety_disclaimer():
    result = learn_personalized_baseline(
        make_patient_history()
    )

    disclaimer = result[
        "disclaimer"
    ].lower()

    assert "not medical target ranges" in disclaimer
    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer


def test_empty_history_rejected():
    dataframe = pd.DataFrame()

    with pytest.raises(
        ValueError
    ):
        learn_personalized_baseline(
            dataframe
        )


def test_too_few_records_rejected():
    dataframe = (
        make_patient_history()
        .iloc[:4]
        .copy()
    )

    with pytest.raises(
        ValueError,
        match="At least",
    ):
        learn_personalized_baseline(
            dataframe
        )


def test_multiple_patients_rejected():
    dataframe = make_patient_history()

    dataframe.loc[
        0,
        "patient_id",
    ] = "patient-2"

    with pytest.raises(
        ValueError,
        match="exactly one patient",
    ):
        learn_personalized_baseline(
            dataframe
        )


def test_negative_glucose_rejected():
    dataframe = make_patient_history()

    dataframe.loc[
        0,
        "glucose_mg_dl",
    ] = -10

    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        learn_personalized_baseline(
            dataframe
        )


def test_zero_glucose_rejected():
    dataframe = make_patient_history()

    dataframe.loc[
        0,
        "glucose_mg_dl",
    ] = 0

    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        learn_personalized_baseline(
            dataframe
        )


def test_missing_required_column_rejected():
    dataframe = (
        make_patient_history()
        .drop(
            columns=[
                "glucose_mg_dl"
            ]
        )
    )

    with pytest.raises(
        ValueError,
        match="missing required columns",
    ):
        learn_personalized_baseline(
            dataframe
        )
