from datetime import datetime
from typing import List

from pydantic import (
    BaseModel,
    Field,
    field_validator,
    model_validator,
)


# ============================================================
# NLP SCHEMAS
# ============================================================


class ParseRequest(BaseModel):
    """
    Request schema for natural-language health logging.
    """

    text: str = Field(
        ...,
        min_length=1,
        max_length=500,
        description=(
            "Natural-language patient health log."
        ),
        examples=[
            "My glucose is 125 mg/dL."
        ],
    )

    @model_validator(mode="after")
    def validate_text(self):
        """
        Reject text containing only whitespace.
        """

        self.text = self.text.strip()

        if not self.text:
            raise ValueError(
                "Text cannot be empty."
            )

        return self


# ============================================================
# DIRECT ML PREDICTION SCHEMA
# ============================================================


class TrendPredictionRequest(BaseModel):
    """
    Feature values used by the experimental
    glucose-trend XGBoost model.
    """

    glucose_mg_dl: float = Field(
        ...,
        gt=0,
        description=(
            "Current glucose reading in mg/dL."
        ),
    )

    previous_glucose: float = Field(
        ...,
        gt=0,
        description=(
            "Previous glucose reading in mg/dL."
        ),
    )

    carbs_g: float = Field(
        ...,
        ge=0,
        description=(
            "Logged carbohydrate amount in grams."
        ),
    )

    activity_minutes: float = Field(
        ...,
        ge=0,
        description=(
            "Logged physical activity duration "
            "in minutes."
        ),
    )

    hour_of_day: int = Field(
        ...,
        ge=0,
        le=23,
        description=(
            "Hour of day from 0 to 23."
        ),
    )

    day_of_week: int = Field(
        ...,
        ge=0,
        le=6,
        description=(
            "Day of week where Monday is 0 "
            "and Sunday is 6."
        ),
    )

    month: int = Field(
        ...,
        ge=1,
        le=12,
        description=(
            "Calendar month from 1 to 12."
        ),
    )

    is_weekend: int = Field(
        ...,
        ge=0,
        le=1,
        description=(
            "Weekend indicator: 1 for weekend, "
            "0 otherwise."
        ),
    )


# ============================================================
# PATIENT HISTORY RECORD
# ============================================================


class PatientHistoryRecord(BaseModel):
    """
    One normalized DiaMate patient-history record.

    This shared schema is used by history-based prediction,
    summaries, anomaly detection, and personalized
    baseline learning.
    """

    patient_id: str = Field(
        ...,
        min_length=1,
        description=(
            "Identifier of the patient who owns "
            "the record."
        ),
    )

    timestamp: str = Field(
        ...,
        min_length=1,
        description=(
            "Timestamp of the patient record."
        ),
        examples=[
            "2026-10-05T08:00:00"
        ],
    )

    glucose_mg_dl: float = Field(
        ...,
        gt=0,
        description=(
            "Glucose reading in mg/dL."
        ),
    )

    carbs_g: float = Field(
        ...,
        ge=0,
        description=(
            "Logged carbohydrate amount in grams."
        ),
    )

    activity_minutes: float = Field(
        ...,
        ge=0,
        description=(
            "Logged physical activity duration "
            "in minutes."
        ),
    )

    # --------------------------------------------------------
    # PATIENT ID VALIDATION
    # --------------------------------------------------------

    @field_validator("patient_id")
    @classmethod
    def validate_patient_id(
        cls,
        value: str,
    ) -> str:
        """
        Remove surrounding whitespace from patient_id
        and reject identifiers containing only spaces.
        """

        cleaned = value.strip()

        if not cleaned:
            raise ValueError(
                "patient_id cannot be empty."
            )

        return cleaned

    # --------------------------------------------------------
    # TIMESTAMP VALIDATION
    # --------------------------------------------------------

    @field_validator("timestamp")
    @classmethod
    def validate_timestamp(
        cls,
        value: str,
    ) -> str:
        """
        Remove surrounding whitespace and ensure the
        timestamp is a valid ISO-compatible date/time.
        """

        cleaned = value.strip()

        if not cleaned:
            raise ValueError(
                "timestamp cannot be empty."
            )

        try:
            datetime.fromisoformat(
                cleaned.replace(
                    "Z",
                    "+00:00",
                )
            )

        except ValueError as exc:
            raise ValueError(
                "timestamp must be a valid "
                "ISO date/time."
            ) from exc

        return cleaned


# ============================================================
# HISTORY-BASED ML PREDICTION
# ============================================================


class HistoryPredictionRequest(BaseModel):
    """
    Request schema for glucose-trend prediction
    from sequential patient history.
    """

    records: List[PatientHistoryRecord] = Field(
        ...,
        min_length=2,
        description=(
            "Sequential historical records belonging "
            "to one patient. At least two records are "
            "required for history-based prediction."
        ),
    )


# ============================================================
# PATIENT INSIGHT SUMMARY
# ============================================================


class PatientSummaryRequest(BaseModel):
    """
    Request schema for descriptive patient-history
    summaries and personalized insights.
    """

    records: List[PatientHistoryRecord] = Field(
        ...,
        min_length=1,
        description=(
            "Historical records belonging to "
            "one patient."
        ),
    )

    range_low: float = Field(
        default=70.0,
        gt=0,
        description=(
            "Configured lower glucose range boundary. "
            "This value should come from the patient "
            "profile or application configuration."
        ),
        examples=[
            70.0
        ],
    )

    range_high: float = Field(
        default=180.0,
        gt=0,
        description=(
            "Configured upper glucose range boundary. "
            "This value should come from the patient "
            "profile or application configuration."
        ),
        examples=[
            180.0
        ],
    )

    @model_validator(mode="after")
    def validate_range(self):
        """
        Ensure the configured lower boundary is
        less than the upper boundary.
        """

        if self.range_low >= self.range_high:
            raise ValueError(
                "range_low must be less than range_high"
            )

        return self


# ============================================================
# PERSONALIZED ANOMALY DETECTION
# ============================================================


class AnomalyDetectionRequest(BaseModel):
    """
    Request schema for personalized statistical
    glucose anomaly detection.

    The latest record is treated as the current
    observation.

    Earlier records form the patient's personal
    statistical baseline.
    """

    records: List[PatientHistoryRecord] = Field(
        ...,
        min_length=6,
        description=(
            "Sequential records belonging to one patient. "
            "At least 6 records are required: 5 historical "
            "records for the personal baseline and 1 "
            "current record."
        ),
    )

    z_threshold: float = Field(
        default=2.0,
        gt=0,
        description=(
            "Statistical z-score threshold used to identify "
            "a reading as unusual relative to the patient's "
            "own historical pattern. This is an engineering "
            "threshold and not a clinical threshold."
        ),
        examples=[
            2.0
        ],
    )


# ============================================================
# PERSONALIZED BASELINE LEARNING
# ============================================================


class PersonalizedBaselineRequest(BaseModel):
    """
    Request schema for personalized historical
    glucose baseline learning.

    The supplied records must belong to one patient.

    The resulting baseline describes the patient's
    own historical glucose patterns and must not be
    interpreted as a medical target range.
    """

    records: List[PatientHistoryRecord] = Field(
        ...,
        min_length=5,
        description=(
            "Historical records belonging to one patient. "
            "At least 5 records are required to learn a "
            "personalized glucose baseline."
        ),
    )
# ============================================================
# DATA QUALITY ANALYSIS
# ============================================================


class DataQualityRequest(BaseModel):
    """
    Request schema for patient-history data-quality
    analysis.

    The analysis checks logging/data completeness and
    consistency. It does not evaluate medical status.
    """

    records: List[PatientHistoryRecord] = Field(
        ...,
        min_length=1,
        description=(
            "Historical records belonging to one patient "
            "for data-quality analysis."
        ),
    )

    large_gap_hours: float = Field(
        default=24.0,
        gt=0,
        description=(
            "Configurable engineering threshold used to "
            "identify large time gaps between sequential "
            "patient-history records. This is not a "
            "clinical threshold."
        ),
        examples=[
            24.0
        ],
    )
