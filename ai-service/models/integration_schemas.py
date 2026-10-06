from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class BackendGlucoseLog(BaseModel):
    """
    Relevant glucose-log fields received from
    the DiaMate Spring Boot backend.
    """

    id: Optional[int] = None

    patientId: int = Field(
        ...,
        gt=0,
        description="Patient identifier from Spring Boot.",
    )

    glucoseValue: float = Field(
        ...,
        gt=0,
        description="Glucose value in mg/dL.",
    )

    measurementTime: datetime = Field(
        ...,
        description="Time when glucose was measured.",
    )

    clientUuid: Optional[UUID] = None


class BackendMealLog(BaseModel):
    """
    Relevant meal-log fields received from
    the DiaMate Spring Boot backend.
    """

    id: Optional[int] = None

    patientId: int = Field(
        ...,
        gt=0,
        description="Patient identifier from Spring Boot.",
    )

    eatenAt: datetime = Field(
        ...,
        description="Time when the meal was consumed.",
    )

    carbsG: float = Field(
        ...,
        ge=0,
        description="Logged carbohydrate amount in grams.",
    )

    clientUuid: Optional[UUID] = None


class BackendActivityLog(BaseModel):
    """
    Relevant activity-log fields received from
    the DiaMate Spring Boot backend.
    """

    id: Optional[int] = None

    patientId: int = Field(
        ...,
        gt=0,
        description="Patient identifier from Spring Boot.",
    )

    startedAt: datetime = Field(
        ...,
        description="Time when the activity started.",
    )

    durationMinutes: float = Field(
        ...,
        ge=0,
        description="Activity duration in minutes.",
    )

    clientUuid: Optional[UUID] = None


class BackendHistoryRequest(BaseModel):
    """
    Health-log collections supplied by the
    DiaMate Spring Boot backend for AI processing.
    """

    glucoseLogs: List[BackendGlucoseLog] = Field(
        default_factory=list,
        description=(
            "Glucose logs supplied by the Spring Boot backend."
        ),
    )

    mealLogs: List[BackendMealLog] = Field(
        default_factory=list,
        description=(
            "Meal logs supplied by the Spring Boot backend."
        ),
    )

    activityLogs: List[BackendActivityLog] = Field(
        default_factory=list,
        description=(
            "Activity logs supplied by the Spring Boot backend."
        ),
    )

    rangeLow: float = Field(
        default=70.0,
        gt=0,
        description=(
            "Configured lower glucose range boundary. "
            "This is supplied by the application or "
            "patient configuration and is not selected "
            "by the AI service."
        ),
    )

    rangeHigh: float = Field(
        default=180.0,
        gt=0,
        description=(
            "Configured upper glucose range boundary. "
            "This is supplied by the application or "
            "patient configuration and is not selected "
            "by the AI service."
        ),
    )

    @model_validator(mode="after")
    def validate_request(self):
        """
        Validate the relationship between configured
        range values and basic request contents.
        """

        if self.rangeLow >= self.rangeHigh:
            raise ValueError(
                "rangeLow must be lower than rangeHigh."
            )

        if not self.glucoseLogs:
            raise ValueError(
                "At least one glucose log is required."
            )

        return self
