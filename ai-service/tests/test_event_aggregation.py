import pytest

from data.event_aggregation import (
    aggregate_events_for_ml,
    normalize_patient_events,
)


def test_events_are_sorted_by_time():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T11:00:00"
            ),
            "carbs_g": 30,
        },
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T08:00:00"
            ),
            "glucose_mg_dl": 100,
        },
    ]

    result = normalize_patient_events(
        events
    )

    assert (
        result[0]["event_type"]
        == "GLUCOSE"
    )

    assert (
        result[1]["event_type"]
        == "MEAL"
    )


def test_aggregates_events_between_glucose_readings():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T08:00:00"
            ),
            "glucose_mg_dl": 100,
        },
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T09:00:00"
            ),
            "carbs_g": 20,
        },
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T10:00:00"
            ),
            "carbs_g": 30,
        },
        {
            "patient_id": "patient_123",
            "event_type": "ACTIVITY",
            "timestamp": (
                "2026-10-02T11:00:00"
            ),
            "activity_minutes": 15,
        },
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T12:00:00"
            ),
            "glucose_mg_dl": 140,
        },
    ]

    result = aggregate_events_for_ml(
        events
    )

    assert len(result) == 1

    record = result[0]

    assert (
        record["previous_glucose"]
        == 100.0
    )

    assert (
        record["glucose_mg_dl"]
        == 140.0
    )

    assert record["carbs_g"] == 50.0

    assert (
        record["activity_minutes"]
        == 15.0
    )


def test_future_events_do_not_leak_backward():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T08:00:00"
            ),
            "glucose_mg_dl": 100,
        },
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T09:00:00"
            ),
            "carbs_g": 20,
        },
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T10:00:00"
            ),
            "glucose_mg_dl": 130,
        },
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T11:00:00"
            ),
            "carbs_g": 100,
        },
    ]

    result = aggregate_events_for_ml(
        events
    )

    assert len(result) == 1

    assert result[0]["carbs_g"] == 20.0


def test_interval_resets_after_glucose():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T08:00:00"
            ),
            "glucose_mg_dl": 100,
        },
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T09:00:00"
            ),
            "carbs_g": 20,
        },
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T10:00:00"
            ),
            "glucose_mg_dl": 120,
        },
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T11:00:00"
            ),
            "carbs_g": 50,
        },
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T12:00:00"
            ),
            "glucose_mg_dl": 140,
        },
    ]

    result = aggregate_events_for_ml(
        events
    )

    assert len(result) == 2

    assert result[0]["carbs_g"] == 20.0
    assert result[1]["carbs_g"] == 50.0


def test_single_glucose_has_no_ml_record():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T08:00:00"
            ),
            "glucose_mg_dl": 100,
        }
    ]

    result = aggregate_events_for_ml(
        events
    )

    assert result == []


def test_multiple_patients_rejected():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T08:00:00"
            ),
            "glucose_mg_dl": 100,
        },
        {
            "patient_id": "patient_456",
            "event_type": "GLUCOSE",
            "timestamp": (
                "2026-10-02T09:00:00"
            ),
            "glucose_mg_dl": 110,
        },
    ]

    with pytest.raises(
        ValueError,
        match="exactly one patient",
    ):
        normalize_patient_events(
            events
        )


def test_unsupported_event_rejected():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "UNKNOWN",
            "timestamp": (
                "2026-10-02T08:00:00"
            ),
        }
    ]

    with pytest.raises(
        ValueError,
        match="Unsupported event type",
    ):
        normalize_patient_events(
            events
        )


def test_negative_carbs_rejected():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "MEAL",
            "timestamp": (
                "2026-10-02T09:00:00"
            ),
            "carbs_g": -20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="cannot be negative",
    ):
        normalize_patient_events(
            events
        )


def test_invalid_timestamp_rejected():
    events = [
        {
            "patient_id": "patient_123",
            "event_type": "GLUCOSE",
            "timestamp": "not-a-date",
            "glucose_mg_dl": 100,
        }
    ]

    with pytest.raises(
        ValueError,
        match="ISO-8601",
    ):
        normalize_patient_events(
            events
        )
