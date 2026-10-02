import pytest
from pydantic import ValidationError

from models.schemas import (
    HistoryPredictionRequest,
    ParseRequest,
    PatientHistoryRecord,
    PatientSummaryRequest,
    TrendPredictionRequest,
)


# =========================================================
# HELPERS
# =========================================================

def valid_history_record():
    return {
        "patient_id": "patient_123",
        "timestamp": "2026-10-02T14:00:00",
        "glucose_mg_dl": 145,
        "carbs_g": 40,
        "activity_minutes": 20,
    }


def valid_trend_prediction():
    return {
        "glucose_mg_dl": 145,
        "previous_glucose": 120,
        "carbs_g": 40,
        "activity_minutes": 20,
        "hour_of_day": 14,
        "day_of_week": 4,
        "month": 10,
        "is_weekend": 0,
    }


# =========================================================
# PARSE REQUEST
# =========================================================

def test_parse_request_accepts_valid_text():
    request = ParseRequest(
        text="My glucose is 125"
    )

    assert request.text == "My glucose is 125"


def test_parse_request_trims_whitespace():
    request = ParseRequest(
        text="   My glucose is 125   "
    )

    assert request.text == "My glucose is 125"


@pytest.mark.parametrize(
    "text",
    [
        "",
        "   ",
        "\n\t",
    ],
)
def test_parse_request_rejects_empty_text(text):
    with pytest.raises(ValidationError):
        ParseRequest(text=text)


def test_parse_request_rejects_text_over_500_characters():
    with pytest.raises(ValidationError):
        ParseRequest(text="a" * 501)


# =========================================================
# TREND PREDICTION REQUEST
# =========================================================

def test_trend_prediction_accepts_valid_data():
    request = TrendPredictionRequest(
        **valid_trend_prediction()
    )

    assert request.glucose_mg_dl == 145
    assert request.previous_glucose == 120
    assert request.carbs_g == 40
    assert request.activity_minutes == 20


@pytest.mark.parametrize(
    "field,value",
    [
        ("glucose_mg_dl", 0),
        ("glucose_mg_dl", -1),
        ("previous_glucose", 0),
        ("previous_glucose", -1),
        ("carbs_g", -1),
        ("activity_minutes", -1),
        ("hour_of_day", -1),
        ("hour_of_day", 24),
        ("day_of_week", -1),
        ("day_of_week", 7),
        ("month", 0),
        ("month", 13),
        ("is_weekend", -1),
        ("is_weekend", 2),
    ],
)
def test_trend_prediction_rejects_invalid_values(
    field,
    value,
):
    data = valid_trend_prediction()
    data[field] = value

    with pytest.raises(ValidationError):
        TrendPredictionRequest(**data)


# =========================================================
# PATIENT HISTORY RECORD
# =========================================================

def test_patient_history_record_accepts_valid_data():
    record = PatientHistoryRecord(
        **valid_history_record()
    )

    assert record.patient_id == "patient_123"
    assert record.glucose_mg_dl == 145


def test_patient_id_is_trimmed():
    data = valid_history_record()
    data["patient_id"] = "   patient_123   "

    record = PatientHistoryRecord(**data)

    assert record.patient_id == "patient_123"


@pytest.mark.parametrize(
    "patient_id",
    [
        "",
        "   ",
    ],
)
def test_patient_history_rejects_empty_patient_id(
    patient_id,
):
    data = valid_history_record()
    data["patient_id"] = patient_id

    with pytest.raises(ValidationError):
        PatientHistoryRecord(**data)


@pytest.mark.parametrize(
    "field,value",
    [
        ("glucose_mg_dl", 0),
        ("glucose_mg_dl", -10),
        ("carbs_g", -1),
        ("activity_minutes", -1),
    ],
)
def test_patient_history_rejects_invalid_numeric_values(
    field,
    value,
):
    data = valid_history_record()
    data[field] = value

    with pytest.raises(ValidationError):
        PatientHistoryRecord(**data)


# =========================================================
# HISTORY PREDICTION REQUEST
# =========================================================

def test_history_prediction_accepts_two_records():
    first = valid_history_record()

    second = valid_history_record()
    second["timestamp"] = "2026-10-02T15:00:00"
    second["glucose_mg_dl"] = 150

    request = HistoryPredictionRequest(
        records=[first, second]
    )

    assert len(request.records) == 2


def test_history_prediction_requires_at_least_two_records():
    with pytest.raises(ValidationError):
        HistoryPredictionRequest(
            records=[valid_history_record()]
        )


# =========================================================
# PATIENT SUMMARY REQUEST
# =========================================================

def test_patient_summary_accepts_valid_data():
    request = PatientSummaryRequest(
        records=[valid_history_record()],
        range_low=70,
        range_high=180,
    )

    assert len(request.records) == 1
    assert request.range_low == 70
    assert request.range_high == 180


def test_patient_summary_uses_default_range():
    request = PatientSummaryRequest(
        records=[valid_history_record()]
    )

    assert request.range_low == 70.0
    assert request.range_high == 180.0


def test_patient_summary_requires_at_least_one_record():
    with pytest.raises(ValidationError):
        PatientSummaryRequest(records=[])


@pytest.mark.parametrize(
    "field,value",
    [
        ("range_low", 0),
        ("range_low", -1),
        ("range_high", 0),
        ("range_high", -1),
    ],
)
def test_patient_summary_rejects_non_positive_ranges(
    field,
    value,
):
    data = {
        "records": [valid_history_record()],
        "range_low": 70,
        "range_high": 180,
    }

    data[field] = value

    with pytest.raises(ValidationError):
        PatientSummaryRequest(**data)
def test_patient_history_rejects_invalid_timestamp():
    data = valid_history_record()
    data["timestamp"] = "not-a-real-timestamp"

    with pytest.raises(ValidationError):
        PatientHistoryRecord(**data)


@pytest.mark.parametrize(
    "range_low,range_high",
    [
        (180, 70),
        (100, 100),
    ],
)
def test_patient_summary_rejects_invalid_range_order(
    range_low,
    range_high,
):
    with pytest.raises(ValidationError):
        PatientSummaryRequest(
            records=[valid_history_record()],
            range_low=range_low,
            range_high=range_high,
        )
