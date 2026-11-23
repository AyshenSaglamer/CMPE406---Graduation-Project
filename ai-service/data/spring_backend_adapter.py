from datetime import datetime
from typing import Dict, List


def _timestamp_to_string(value) -> str:
    """
    Convert a Spring Boot timestamp into an
    ISO-8601 string used by the DiaMate AI pipeline.
    """

    if isinstance(value, datetime):
        return value.isoformat()

    if isinstance(value, str):
        cleaned = value.strip()

        if not cleaned:
            raise ValueError(
                "Backend timestamp cannot be empty."
            )

        return cleaned

    raise ValueError(
        "Backend timestamp must be a string or datetime."
    )


def glucose_log_to_event(
    log: Dict,
) -> Dict:
    """
    Convert a Spring Boot GlucoseLogResponse
    into the internal DiaMate AI event format.
    """

    return {
        "patient_id": str(
            log["patientId"]
        ),
        "event_type": "GLUCOSE",
        "timestamp": _timestamp_to_string(
            log["measurementTime"]
        ),
        "glucose_mg_dl": log[
            "glucoseValue"
        ],
    }


def meal_log_to_event(
    log: Dict,
) -> Dict:
    """
    Convert a Spring Boot MealLogResponse
    into the internal DiaMate AI event format.
    """

    return {
        "patient_id": str(
            log["patientId"]
        ),
        "event_type": "MEAL",
        "timestamp": _timestamp_to_string(
            log["eatenAt"]
        ),
        "carbs_g": log[
            "carbsG"
        ],
    }


def activity_log_to_event(
    log: Dict,
) -> Dict:
    """
    Convert a Spring Boot ActivityLogResponse
    into the internal DiaMate AI event format.
    """

    return {
        "patient_id": str(
            log["patientId"]
        ),
        "event_type": "ACTIVITY",
        "timestamp": _timestamp_to_string(
            log["startedAt"]
        ),
        "activity_minutes": log[
            "durationMinutes"
        ],
    }


def convert_backend_logs_to_events(
    glucose_logs: List[Dict],
    meal_logs: List[Dict],
    activity_logs: List[Dict],
) -> List[Dict]:
    """
    Convert Spring Boot health-log DTO data into
    the common DiaMate AI event representation.

    Chronological sorting and deeper event validation
    are performed by the event-aggregation layer.
    """

    events = []

    for log in glucose_logs:
        events.append(
            glucose_log_to_event(
                log
            )
        )

    for log in meal_logs:
        events.append(
            meal_log_to_event(
                log
            )
        )

    for log in activity_logs:
        events.append(
            activity_log_to_event(
                log
            )
        )

    return events
