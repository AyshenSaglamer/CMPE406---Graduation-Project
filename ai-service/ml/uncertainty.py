from typing import Dict, List

import math
import numpy as np


DEFAULT_LOW_CONFIDENCE_THRESHOLD = 0.50
DEFAULT_HIGH_CONFIDENCE_THRESHOLD = 0.75


def _validate_probabilities(
    probabilities: List[float],
) -> List[float]:
    """
    Validate model class probabilities.
    """

    if probabilities is None:
        raise ValueError(
            "Class probabilities cannot be None."
        )

    if len(probabilities) < 2:
        raise ValueError(
            "At least two class probabilities are required."
        )

    cleaned = []

    for probability in probabilities:
        try:
            value = float(probability)
        except (TypeError, ValueError):
            raise ValueError(
                "Class probabilities must be numeric."
            )

        if not math.isfinite(value):
            raise ValueError(
                "Class probabilities must be finite."
            )

        if value < 0.0 or value > 1.0:
            raise ValueError(
                "Class probabilities must be between 0 and 1."
            )

        cleaned.append(value)

    total = sum(cleaned)

    if not np.isclose(
        total,
        1.0,
        atol=1e-4,
    ):
        raise ValueError(
            "Class probabilities must sum to 1."
        )

    return cleaned


def _confidence_level(
    confidence: float,
    low_threshold: float,
    high_threshold: float,
) -> str:
    """
    Convert a numeric model confidence into a simple
    descriptive engineering category.
    """

    if confidence < low_threshold:
        return "LOW"

    if confidence < high_threshold:
        return "MODERATE"

    return "HIGH"


def calculate_prediction_uncertainty(
    probabilities: List[float],
    class_names: List[str],
    low_threshold: float = (
        DEFAULT_LOW_CONFIDENCE_THRESHOLD
    ),
    high_threshold: float = (
        DEFAULT_HIGH_CONFIDENCE_THRESHOLD
    ),
) -> Dict:
    """
    Calculate descriptive confidence and uncertainty
    information from classifier probabilities.

    These values describe model behaviour only.
    They are not clinical probabilities.
    """

    cleaned_probabilities = _validate_probabilities(
        probabilities
    )

    if class_names is None:
        raise ValueError(
            "Class names cannot be None."
        )

    if len(class_names) != len(
        cleaned_probabilities
    ):
        raise ValueError(
            "The number of class names must match "
            "the number of class probabilities."
        )

    if not (
        0.0
        < low_threshold
        < high_threshold
        <= 1.0
    ):
        raise ValueError(
            "Confidence thresholds must satisfy "
            "0 < low_threshold < high_threshold <= 1."
        )

    normalized_names = [
        str(name)
        for name in class_names
    ]

    confidence = max(
        cleaned_probabilities
    )

    predicted_index = int(
        np.argmax(
            cleaned_probabilities
        )
    )

    predicted_class = (
        normalized_names[
            predicted_index
        ]
    )

    uncertainty = (
        1.0 - confidence
    )

    probability_map = {
        class_name: round(
            probability,
            6,
        )
        for class_name, probability
        in zip(
            normalized_names,
            cleaned_probabilities,
        )
    }

    return {
        "predicted_class": predicted_class,

        "confidence": {
            "score": round(
                confidence,
                6,
            ),
            "level": _confidence_level(
                confidence,
                low_threshold,
                high_threshold,
            ),
        },

        "uncertainty": {
            "score": round(
                uncertainty,
                6,
            ),
        },

        "class_probabilities": (
            probability_map
        ),

        "method": (
            "maximum_class_probability"
        ),

        "scope": (
            "model_prediction_uncertainty"
        ),

        "disclaimer": (
            "Confidence and uncertainty describe "
            "the machine-learning model's output "
            "distribution only. They do not represent "
            "clinical probability, diagnosis, medical "
            "risk, treatment advice, or medication "
            "guidance."
        ),
    }
