from data.event_aggregation import aggregate_events_for_ml
from data.spring_backend_adapter import (
    activity_log_to_event,
    convert_backend_logs_to_events,
    glucose_log_to_event,
    meal_log_to_event,
)


def test_glucose_log_to_event():
    log = {
        "id": 1,
        "patientId": 12,
        "glucoseValue": 135,
        "measurementTime": "2026-10-06T08:00:00Z",
    }

    result = glucose_log_to_event(log)

    assert result == {
        "patient_id": "12",
        "event_type": "GLUCOSE",
        "timestamp": "2026-10-06T08:00:00Z",
        "glucose_mg_dl": 135,
    }


def test_meal_log_to_event():
    log = {
        "id": 2,
        "patientId": 12,
        "eatenAt": "2026-10-06T08:30:00Z",
        "carbsG": 40.0,
    }

    result = meal_log_to_event(log)

    assert result == {
        "patient_id": "12",
        "event_type": "MEAL",
        "timestamp": "2026-10-06T08:30:00Z",
        "carbs_g": 40.0,
    }


def test_activity_log_to_event():
    log = {
        "id": 3,
        "patientId": 12,
        "startedAt": "2026-10-06T09:00:00Z",
        "durationMinutes": 20.0,
    }

    result = activity_log_to_event(log)

    assert result == {
        "patient_id": "12",
        "event_type": "ACTIVITY",
        "timestamp": "2026-10-06T09:00:00Z",
        "activity_minutes": 20.0,
    }


def test_meal_log_allows_null_carbs():
    log = {
        "id": 4,
        "patientId": 12,
        "eatenAt": "2026-10-06T08:30:00Z",
        "carbsG": None,
    }

    result = meal_log_to_event(log)

    assert result["carbs_g"] is None


def test_activity_log_allows_null_duration():
    log = {
        "id": 5,
        "patientId": 12,
        "startedAt": "2026-10-06T09:00:00Z",
        "durationMinutes": None,
    }

    result = activity_log_to_event(log)

    assert result["activity_minutes"] is None


def test_convert_backend_logs_to_events():
    glucose_logs = [
        {
            "patientId": 12,
            "glucoseValue": 120,
            "measurementTime": "2026-10-06T08:00:00Z",
        },
        {
            "patientId": 12,
            "glucoseValue": 135,
            "measurementTime": "2026-10-06T10:00:00Z",
        },
    ]

    meal_logs = [
        {
            "patientId": 12,
            "eatenAt": "2026-10-06T08:30:00Z",
            "carbsG": 40.0,
        }
    ]

    activity_logs = [
        {
            "patientId": 12,
            "startedAt": "2026-10-06T09:00:00Z",
            "durationMinutes": 20.0,
        }
    ]

    result = convert_backend_logs_to_events(
        glucose_logs,
        meal_logs,
        activity_logs,
    )

    assert len(result) == 4
    assert result[0]["event_type"] == "GLUCOSE"
    assert result[1]["event_type"] == "GLUCOSE"
    assert result[2]["event_type"] == "MEAL"
    assert result[3]["event_type"] == "ACTIVITY"


def test_null_optional_values_do_not_break_aggregation():
    glucose_logs = [
        {
            "patientId": 12,
            "glucoseValue": 120,
            "measurementTime": "2026-10-06T08:00:00Z",
        },
        {
            "patientId": 12,
            "glucoseValue": 135,
            "measurementTime": "2026-10-06T10:00:00Z",
        },
    ]

    meal_logs = [
        {
            "patientId": 12,
            "eatenAt": "2026-10-06T08:30:00Z",
            "carbsG": None,
        }
    ]

    activity_logs = [
        {
            "patientId": 12,
            "startedAt": "2026-10-06T09:00:00Z",
            "durationMinutes": None,
        }
    ]

    events = convert_backend_logs_to_events(
        glucose_logs,
        meal_logs,
        activity_logs,
    )

    records = aggregate_events_for_ml(events)

    assert len(records) == 1
    assert records[0]["glucose_mg_dl"] == 135.0
    assert records[0]["previous_glucose"] == 120.0
    assert records[0]["carbs_g"] == 0.0
    assert records[0]["activity_minutes"] == 0.0
