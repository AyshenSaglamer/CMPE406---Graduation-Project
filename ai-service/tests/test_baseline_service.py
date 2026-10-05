import pytest

from services.baseline_service import (
    build_personalized_baseline,
)


def make_records():
    return [
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-01T08:00:00",
            "glucose_mg_dl": 108,
            "carbs_g": 30,
            "activity_minutes": 10,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-02T09:00:00",
            "glucose_mg_dl": 112,
            "carbs_g": 25,
            "activity_minutes": 20,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-03T14:00:00",
            "glucose_mg_dl": 128,
            "carbs_g": 40,
            "activity_minutes": 15,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-04T15:00:00",
            "glucose_mg_dl": 132,
            "carbs_g": 35,
            "activity_minutes": 25,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-05T19:00:00",
            "glucose_mg_dl": 125,
            "carbs_g": 20,
            "activity_minutes": 30,
        },
        {
            "patient_id": "patient-1",
            "timestamp": "2026-10-06T20:00:00",
            "glucose_mg_dl": 130,
            "carbs_g": 45,
            "activity_minutes": 10,
        },
    ]


def test_build_baseline_patient():
    result = build_personalized_baseline(
        make_records()
    )

    assert result["patient_id"] == "patient-1"


def test_build_baseline_overall_mean():
    result = build_personalized_baseline(
        make_records()
    )

    assert (
        result["overall_baseline"]["mean"]
        == pytest.approx(122.5)
    )


def test_build_baseline_time_periods():
    result = build_personalized_baseline(
        make_records()
    )

    periods = result[
        "time_of_day_baselines"
    ]

    assert periods["MORNING"]["mean"] == 110.0
    assert periods["AFTERNOON"]["mean"] == 130.0
    assert periods["EVENING"]["mean"] == 127.5

    assert periods["NIGHT"]["available"] is False


def test_build_baseline_day_types():
    result = build_personalized_baseline(
        make_records()
    )

    day_types = result[
        "day_type_baselines"
    ]

    assert day_types["WEEKDAY"]["available"] is True
    assert day_types["WEEKEND"]["available"] is True


def test_build_baseline_metadata():
    result = build_personalized_baseline(
        make_records()
    )

    assert result["source"] == "patient_history"

    assert (
        result["purpose"]
        == "personalized_baseline_learning"
    )

    assert (
        result["scope"]
        == "personalized_historical_pattern"
    )


def test_build_baseline_empty_records():
    with pytest.raises(
        ValueError,
        match="required",
    ):
        build_personalized_baseline([])


def test_build_baseline_too_few_records():
    records = make_records()[:4]

    with pytest.raises(
        ValueError,
        match="At least",
    ):
        build_personalized_baseline(
            records
        )


def test_build_baseline_multiple_patients():
    records = make_records()

    records[0][
        "patient_id"
    ] = "patient-2"

    with pytest.raises(
        ValueError,
        match="exactly one patient",
    ):
        build_personalized_baseline(
            records
        )


def test_build_baseline_contains_safety_disclaimer():
    result = build_personalized_baseline(
        make_records()
    )

    disclaimer = result[
        "disclaimer"
    ].lower()

    assert "not medical target ranges" in disclaimer
    assert "diagnosis" in disclaimer
    assert "treatment" in disclaimer
    assert "medication" in disclaimer
