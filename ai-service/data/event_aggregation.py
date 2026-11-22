from datetime import datetime
from math import isfinite
from typing import Dict, List


SUPPORTED_EVENT_TYPES = {
    "GLUCOSE",
    "MEAL",
    "ACTIVITY",
}


def _parse_timestamp(value: str) -> datetime:
    """
    Convert an ISO timestamp string into a
    datetime object.
    """

    if not isinstance(value, str):
        raise ValueError(
            "Event timestamp must be a string."
        )

    cleaned = value.strip()

    if not cleaned:
        raise ValueError(
            "Event timestamp cannot be empty."
        )

    try:
        return datetime.fromisoformat(cleaned)
    except ValueError as exc:
        raise ValueError(
            "Event timestamp must be a valid "
            "ISO-8601 datetime."
        ) from exc


def _validate_number(
    value,
    *,
    field_name: str,
    allow_zero: bool,
) -> float:
    """
    Validate a required numeric event value.
    """

    if isinstance(value, bool):
        raise ValueError(
            f"{field_name} must be numeric."
        )

    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{field_name} must be numeric."
        ) from exc

    if not isfinite(number):
        raise ValueError(
            f"{field_name} must be finite."
        )

    if allow_zero:
        if number < 0:
            raise ValueError(
                f"{field_name} cannot be negative."
            )
    elif number <= 0:
        raise ValueError(
            f"{field_name} must be greater "
            "than zero."
        )

    return number


def _validate_optional_number(
    value,
    *,
    field_name: str,
    allow_zero: bool,
):
    """
    Validate an optional numeric event value.

    None means that the value is unknown.
    Unknown values remain None and are not
    converted to zero.
    """

    if value is None:
        return None

    return _validate_number(
        value,
        field_name=field_name,
        allow_zero=allow_zero,
    )


def normalize_patient_events(
    events: List[Dict],
) -> List[Dict]:
    """
    Validate and sort raw patient events.

    Supported events:

    - GLUCOSE
    - MEAL
    - ACTIVITY

    Glucose values are required.

    Meal carbohydrate amounts and activity
    durations may be unknown. Unknown values
    are represented as None.
    """

    if not events:
        raise ValueError(
            "Patient events cannot be empty."
        )

    normalized = []

    for event in events:
        if not isinstance(event, dict):
            raise ValueError(
                "Each patient event must "
                "be an object."
            )

        patient_id = str(
            event.get(
                "patient_id",
                "",
            )
        ).strip()

        if not patient_id:
            raise ValueError(
                "patient_id is required."
            )

        event_type = str(
            event.get(
                "event_type",
                "",
            )
        ).strip().upper()

        if (
            event_type
            not in SUPPORTED_EVENT_TYPES
        ):
            raise ValueError(
                "Unsupported event type."
            )

        timestamp = _parse_timestamp(
            event.get("timestamp")
        )

        normalized_event = {
            "patient_id": patient_id,
            "event_type": event_type,
            "timestamp": timestamp,
        }

        if event_type == "GLUCOSE":
            normalized_event[
                "glucose_mg_dl"
            ] = _validate_number(
                event.get(
                    "glucose_mg_dl"
                ),
                field_name="glucose_mg_dl",
                allow_zero=False,
            )

        elif event_type == "MEAL":
            normalized_event[
                "carbs_g"
            ] = _validate_optional_number(
                event.get("carbs_g"),
                field_name="carbs_g",
                allow_zero=True,
            )

        elif event_type == "ACTIVITY":
            normalized_event[
                "activity_minutes"
            ] = _validate_optional_number(
                event.get(
                    "activity_minutes"
                ),
                field_name=(
                    "activity_minutes"
                ),
                allow_zero=True,
            )

        normalized.append(
            normalized_event
        )

    patient_ids = {
        event["patient_id"]
        for event in normalized
    }

    if len(patient_ids) != 1:
        raise ValueError(
            "Events must belong to "
            "exactly one patient."
        )

    normalized.sort(
        key=lambda event: event["timestamp"]
    )

    return normalized


def aggregate_events_for_ml(
    events: List[Dict],
) -> List[Dict]:
    """
    Convert time-ordered patient events into
    glucose-centered ML records.

    Known meal carbohydrate amounts and activity
    minutes are accumulated only after the
    previous glucose event and up to the
    current glucose event.

    Unknown meal carbohydrate amounts and
    activity durations are not treated as zero;
    they are simply excluded from the numeric
    accumulation.

    Future events are never used.
    """

    normalized = normalize_patient_events(
        events
    )

    patient_id = normalized[0][
        "patient_id"
    ]

    records = []

    pending_carbs = 0.0
    pending_activity = 0.0

    previous_glucose = None

    for event in normalized:
        event_type = event[
            "event_type"
        ]

        if event_type == "MEAL":
            carbs_g = event[
                "carbs_g"
            ]

            if carbs_g is not None:
                pending_carbs += carbs_g

            continue

        if event_type == "ACTIVITY":
            activity_minutes = event[
                "activity_minutes"
            ]

            if activity_minutes is not None:
                pending_activity += (
                    activity_minutes
                )

            continue

        if event_type == "GLUCOSE":
            current_glucose = event[
                "glucose_mg_dl"
            ]

            if previous_glucose is not None:
                records.append(
                    {
                        "patient_id": (
                            patient_id
                        ),
                        "timestamp": (
                            event[
                                "timestamp"
                            ].isoformat()
                        ),
                        "glucose_mg_dl": (
                            current_glucose
                        ),
                        "previous_glucose": (
                            previous_glucose
                        ),
                        "carbs_g": round(
                            pending_carbs,
                            2,
                        ),
                        "activity_minutes": (
                            round(
                                pending_activity,
                                2,
                            )
                        ),
                    }
                )

            previous_glucose = (
                current_glucose
            )

            # Start a new interval after each
            # glucose observation.
            pending_carbs = 0.0
            pending_activity = 0.0

    return records
