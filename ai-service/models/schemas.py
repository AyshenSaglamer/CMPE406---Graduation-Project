from typing import List

from pydantic import (
    BaseModel,
    Field,
    field_validator,
)


# =========================================================
# NLP
# =========================================================

class ParseRequest(BaseModel):
    text: str = Field(
        ...,
        min_length=1,
        max_length=500,
        description=(
            "Natural-language health log input."
        ),
        examples=[
            (
                "My glucose is 125 and I took "
                "5 units of insulin"
            )
        ],
    )

    @field_validator("text")
    @classmethod
    def validate_text(
        cls,
        value: str,
    ) -> str:
        cleaned_value = value.strip()

        if not cleaned_value:
            raise ValueError(
                "Text must not be empty "
                "or whitespace."
            )

        return cleaned_value


# =========================================================
# DIRECT ML PREDICTION
# =========================================================

class TrendPredictionRequest(BaseModel):
    glucose_mg_dl: float = Field(
        ...,
        gt=0,
        description="Current glucose reading.",
        examples=[135],
    )

    previous_glucose: float = Field(
        ...,
        gt=0,
        description="Previous glucose reading.",
        examples=[120],
    )

    carbs_g: float = Field(
        ...,
        ge=0,
        description=(
            "Carbohydrate amount in grams."
        ),
        examples=[40],
    )

    activity_minutes: float = Field(
        ...,
        ge=0,
        description=(
            "Activity duration in minutes."
        ),
        examples=[30],
    )

    hour_of_day: int = Field(
        ...,
        ge=0,
        le=23,
        description=(
            "Hour of day from 0 to 23."
        ),
        examples=[14],
    )

    day_of_week: int = Field(
        ...,
        ge=0,
        le=6,
        description=(
            "Day of week where Monday=0 "
            "and Sunday=6."
        ),
        examples=[2],
    )

    month: int = Field(
        ...,
        ge=1,
        le=12,
        description=(
            "Calendar month from 1 to 12."
        ),
        examples=[9],
    )

    is_weekend: int = Field(
        ...,
        ge=0,
        le=1,
        description=(
            "Weekend indicator: "
            "0 for no, 1 for yes."
        ),
        examples=[0],
    )


# =========================================================
# PATIENT HISTORY ML PREDICTION
# =========================================================

class PatientHistoryRecord(BaseModel):
    patient_id: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description=(
            "Anonymous or internal patient "
            "identifier."
        ),
        examples=["patient_123"],
    )

    timestamp: str = Field(
        ...,
        min_length=1,
        description=(
            "Timestamp of the patient record."
        ),
        examples=[
            "2026-10-01T14:00:00"
        ],
    )

    glucose_mg_dl: float = Field(
        ...,
        gt=0,
        description="Logged glucose value.",
        examples=[145],
    )

    carbs_g: float = Field(
        ...,
        ge=0,
        description=(
            "Logged carbohydrate amount "
            "in grams."
        ),
        examples=[40],
    )

    activity_minutes: float = Field(
        ...,
        ge=0,
        description=(
            "Logged activity duration "
            "in minutes."
        ),
        examples=[20],
    )

    @field_validator("patient_id")
    @classmethod
    def validate_patient_id(
        cls,
        value: str,
    ) -> str:
        cleaned_value = value.strip()

        if not cleaned_value:
            raise ValueError(
                "patient_id cannot be empty."
            )

        return cleaned_value


class HistoryPredictionRequest(BaseModel):
    records: List[PatientHistoryRecord] = Field(
        ...,
        min_length=2,
        description=(
            "Sequential records belonging "
            "to one patient."
        ),
    )
