from data.event_aggregation import (
    aggregate_events_for_ml,
)
from data.spring_backend_adapter import (
    convert_backend_logs_to_events,
)


def test_backend_logs_can_be_aggregated_for_ml():
    """
    Verify the integration between the
    Spring Boot backend DTO format and the
    DiaMate AI event aggregation pipeline.
    """

    glucose_logs = [
        {
            "id": 1,
            "patientId": 12,
            "glucoseValue": 120,
            "measurementTime": (
                "2026-10-06T08:00:00+00:00"
            ),
        },
        {
            "id": 2,
            "patientId": 12,
            "glucoseValue": 135,
            "measurementTime": (
                "2026-10-06T10:00:00+00:00"
            ),
        },
    ]

    meal_logs = [
        {
            "id": 3,
            "patientId": 12,
            "eatenAt": (
                "2026-10-06T08:30:00+00:00"
            ),
            "carbsG": 40.0,
        }
    ]

    activity_logs = [
        {
            "id": 4,
            "patientId": 12,
            "startedAt": (
                "2026-10-06T09:00:00+00:00"
            ),
            "durationMinutes": 20.0,
        }
    ]

    events = convert_backend_logs_to_events(
        glucose_logs=glucose_logs,
        meal_logs=meal_logs,
        activity_logs=activity_logs,
    )

    records = aggregate_events_for_ml(events)

    assert len(records) == 1

    record = records[0]

    assert record["patient_id"] == "12"

    assert record["previous_glucose"] == 120.0

    assert record["glucose_mg_dl"] == 135.0

    assert record["carbs_g"] == 40.0

    assert record["activity_minutes"] == 20.0

    assert record["timestamp"] == (
        "2026-10-06T10:00:00+00:00"
    )
