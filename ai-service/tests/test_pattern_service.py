import pytest

from services.pattern_service import (
    analyze_activity_glucose_pattern,
    analyze_meal_glucose_pattern,
    analyze_patient_patterns,
    compare_recent_glucose,
    describe_activity_glucose_pattern,
    describe_meal_glucose_pattern,
    describe_recent_glucose_pattern,
)


def make_records(
    glucose_values,
    carbs_values=None,
    activity_values=None,
):
    if carbs_values is None:
        carbs_values = [
            10 + index * 10
            for index in range(
                len(glucose_values)
            )
        ]

    if activity_values is None:
        activity_values = [
            index * 10
            for index in range(
                len(glucose_values)
            )
        ]

    records = []

    for index, glucose in enumerate(
        glucose_values
    ):
        records.append(
            {
                "patient_id": "patient_123",
                "timestamp": (
                    f"2026-10-"
                    f"{index + 1:02d}T10:00:00"
                ),
                "glucose_mg_dl": glucose,
                "carbs_g": carbs_values[index],
                "activity_minutes": (
                    activity_values[index]
                ),
            }
        )

    return records


def test_detects_higher_recent_average():
    records = make_records(
        [100, 110, 140, 150]
    )

    result = compare_recent_glucose(
        records
    )

    assert result["status"] == "SUCCESS"
    assert result["pattern"] == "HIGHER"

    assert (
        result["previous_average_mg_dl"]
        == 105.0
    )

    assert (
        result["recent_average_mg_dl"]
        == 145.0
    )


def test_detects_lower_recent_average():
    records = make_records(
        [150, 140, 110, 100]
    )

    result = compare_recent_glucose(
        records
    )

    assert result["pattern"] == "LOWER"


def test_detects_stable_average():
    records = make_records(
        [120, 125, 126, 128]
    )

    result = compare_recent_glucose(
        records
    )

    assert result["pattern"] == "STABLE"


def test_recent_pattern_not_enough_data():
    records = make_records(
        [110, 120, 130]
    )

    result = compare_recent_glucose(
        records
    )

    assert (
        result["status"]
        == "NOT_ENOUGH_DATA"
    )


def test_negative_threshold_rejected():
    records = make_records(
        [100, 110, 120, 130]
    )

    with pytest.raises(
        ValueError,
        match="Stable threshold",
    ):
        compare_recent_glucose(
            records,
            stable_threshold=-1,
        )


def test_multiple_patients_rejected():
    records = make_records(
        [100, 110, 120, 130]
    )

    records[-1][
        "patient_id"
    ] = "patient_456"

    with pytest.raises(
        ValueError,
        match="exactly one patient",
    ):
        compare_recent_glucose(
            records
        )


def test_higher_description():
    result = {
        "status": "SUCCESS",
        "pattern": "HIGHER",
        "previous_average_mg_dl": 110.0,
        "recent_average_mg_dl": 140.0,
    }

    insights = (
        describe_recent_glucose_pattern(
            result
        )
    )

    assert len(insights) == 1
    assert "higher" in insights[0].lower()


def test_positive_meal_glucose_pattern():
    records = make_records(
        glucose_values=[
            100,
            110,
            120,
            130,
            140,
        ],
        carbs_values=[
            10,
            20,
            30,
            40,
            50,
        ],
    )

    result = (
        analyze_meal_glucose_pattern(
            records
        )
    )

    assert result["status"] == "SUCCESS"
    assert result["direction"] == "POSITIVE"
    assert result["correlation"] > 0


def test_negative_meal_glucose_pattern():
    records = make_records(
        glucose_values=[
            140,
            130,
            120,
            110,
            100,
        ],
        carbs_values=[
            10,
            20,
            30,
            40,
            50,
        ],
    )

    result = (
        analyze_meal_glucose_pattern(
            records
        )
    )

    assert result["direction"] == "NEGATIVE"
    assert result["correlation"] < 0


def test_negative_activity_glucose_pattern():
    records = make_records(
        glucose_values=[
            150,
            140,
            130,
            120,
            110,
        ],
        activity_values=[
            0,
            10,
            20,
            30,
            40,
        ],
    )

    result = (
        analyze_activity_glucose_pattern(
            records
        )
    )

    assert result["status"] == "SUCCESS"
    assert result["direction"] == "NEGATIVE"


def test_activity_no_variation():
    records = make_records(
        glucose_values=[
            100,
            110,
            120,
            130,
        ],
        activity_values=[
            20,
            20,
            20,
            20,
        ],
    )

    result = (
        analyze_activity_glucose_pattern(
            records
        )
    )

    assert (
        result["status"]
        == "NO_VARIATION"
    )

    assert result["correlation"] is None


def test_correlation_not_enough_data():
    records = make_records(
        [100, 120]
    )

    result = (
        analyze_meal_glucose_pattern(
            records
        )
    )

    assert (
        result["status"]
        == "NOT_ENOUGH_DATA"
    )


def test_meal_description_mentions_causation():
    result = {
        "status": "SUCCESS",
        "correlation": 0.82,
        "direction": "POSITIVE",
        "strength": "STRONG",
    }

    insights = (
        describe_meal_glucose_pattern(
            result
        )
    )

    assert len(insights) == 1

    assert (
        "does not establish causation"
        in insights[0]
    )


def test_activity_description_mentions_causation():
    result = {
        "status": "SUCCESS",
        "correlation": -0.75,
        "direction": "NEGATIVE",
        "strength": "STRONG",
    }

    insights = (
        describe_activity_glucose_pattern(
            result
        )
    )

    assert len(insights) == 1

    assert (
        "does not establish causation"
        in insights[0]
    )


def test_complete_patient_pattern_analysis():
    records = make_records(
        glucose_values=[
            100,
            110,
            120,
            130,
            140,
            150,
        ],
        carbs_values=[
            10,
            20,
            30,
            40,
            50,
            60,
        ],
        activity_values=[
            60,
            50,
            40,
            30,
            20,
            10,
        ],
    )

    result = analyze_patient_patterns(
        records
    )

    assert result["status"] == "SUCCESS"

    assert "recent_glucose" in (
        result["patterns"]
    )

    assert "meal_glucose" in (
        result["patterns"]
    )

    assert "activity_glucose" in (
        result["patterns"]
    )

    assert result["insight_count"] == 3

    assert len(result["insights"]) == 3

    assert (
        "not establish causation"
        in result["disclaimer"]
    )


def test_pattern_output_has_no_dosing_advice():
    records = make_records(
        [
            100,
            110,
            120,
            130,
            140,
            150,
        ]
    )

    result = analyze_patient_patterns(
        records
    )

    combined_text = " ".join(
        result["insights"]
    ).lower()

    assert "take insulin" not in combined_text
    assert "increase insulin" not in combined_text
    assert "decrease insulin" not in combined_text
    assert "dose" not in combined_text
