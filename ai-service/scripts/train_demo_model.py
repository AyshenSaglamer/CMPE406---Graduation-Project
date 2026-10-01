"""
Train a deterministic synthetic XGBoost model for the
DiaMate AI development/demo environment.

IMPORTANT:
- The generated records are synthetic.
- The resulting model is NOT clinically validated.
- It must NOT be used for diagnosis, insulin dosing,
  medication decisions, or treatment recommendations.
"""

import sys
from pathlib import Path

import pandas as pd


# Allow the script to be executed directly:
#
# python scripts/train_demo_model.py
#
AI_SERVICE_ROOT = Path(
    __file__
).resolve().parents[1]

if str(AI_SERVICE_ROOT) not in sys.path:
    sys.path.insert(
        0,
        str(AI_SERVICE_ROOT),
    )


from ml.training import (  # noqa: E402
    LABEL_ENCODER_PATH,
    MODEL_PATH,
    train_glucose_trend_model,
)


def create_synthetic_patient_records():
    """
    Create deterministic synthetic patient histories.

    Patterns intentionally contain:
    - upward changes
    - downward changes
    - relatively stable changes

    This is designed to exercise the software pipeline,
    not to represent real clinical glucose behavior.
    """

    patient_patterns = {
        "demo_patient_001": [
            100,
            130,
            135,
            105,
            140,
            145,
            110,
            150,
            155,
            120,
            160,
            165,
            130,
            170,
            175,
            140,
            180,
            185,
            150,
            190,
            195,
            160,
            200,
            205,
            170,
            210,
            215,
            180,
            220,
            225,
        ],
        "demo_patient_002": [
            180,
            145,
            150,
            190,
            195,
            160,
            200,
            205,
            170,
            210,
            215,
            180,
            220,
            225,
            190,
            230,
            235,
            200,
            240,
            245,
            210,
            250,
            255,
            220,
            260,
            265,
            230,
            270,
            275,
            240,
        ],
        "demo_patient_003": [
            90,
            120,
            125,
            95,
            130,
            135,
            100,
            140,
            145,
            110,
            150,
            155,
            120,
            160,
            165,
            130,
            170,
            175,
            140,
            180,
            185,
            150,
            190,
            195,
            160,
            200,
            205,
            170,
            210,
            215,
        ],
    }

    records = []

    start_time = pd.Timestamp(
        "2026-01-01 08:00:00"
    )

    for patient_number, (
        patient_id,
        glucose_values,
    ) in enumerate(
        patient_patterns.items()
    ):
        for index, glucose in enumerate(
            glucose_values
        ):
            timestamp = (
                start_time
                + pd.Timedelta(
                    hours=index * 4
                )
            )

            carbs = (
                20
                + (
                    (
                        index
                        + patient_number
                    )
                    % 5
                )
                * 10
            )

            activity = (
                (
                    index
                    + patient_number
                )
                % 4
            ) * 10

            records.append(
                {
                    "patient_id": patient_id,
                    "timestamp": (
                        timestamp.isoformat()
                    ),
                    "glucose_mg_dl": glucose,
                    "carbs_g": carbs,
                    "activity_minutes": (
                        activity
                    ),
                }
            )

    return records


def main():
    print(
        "\n"
        "========================================"
    )
    print(
        " DiaMate Synthetic XGBoost Training"
    )
    print(
        "========================================\n"
    )

    records = (
        create_synthetic_patient_records()
    )

    print(
        f"Synthetic backend records: "
        f"{len(records)}"
    )

    patient_count = len(
        {
            record["patient_id"]
            for record in records
        }
    )

    print(
        f"Synthetic patients: "
        f"{patient_count}"
    )

    print(
        "\nTraining future-trend model..."
    )

    result = train_glucose_trend_model(
        records=records,
        test_ratio=0.20,
        save_model=True,
    )

    print(
        "\nTraining completed."
    )

    print(
        "\nPrediction target:"
    )
    print(
        result["prediction_target"]
    )

    print(
        "\nTraining samples:"
    )
    print(
        result["training_sample_size"]
    )

    print(
        "\nTest samples:"
    )
    print(
        result["test_sample_size"]
    )

    print(
        "\nPatients:"
    )
    print(
        result["patient_count"]
    )

    print(
        "\nModel features:"
    )

    for feature in result[
        "feature_names"
    ]:
        print(
            f"  - {feature}"
        )

    print(
        "\nClasses:"
    )

    for class_name in result[
        "classes"
    ]:
        print(
            f"  - {class_name}"
        )

    print(
        "\nDemo test accuracy:"
    )

    print(
        result[
            "metrics"
        ]["accuracy"]
    )

    print(
        "\nModel artifact:"
    )
    print(
        MODEL_PATH
    )

    print(
        "\nLabel encoder artifact:"
    )
    print(
        LABEL_ENCODER_PATH
    )

    print(
        "\nIMPORTANT:"
    )

    print(
        "This model was trained using "
        "deterministic synthetic data."
    )

    print(
        "Its accuracy is a software/demo metric, "
        "not evidence of clinical performance."
    )

    print(
        "It must not be used for diagnosis, "
        "treatment, or medication dosing."
    )

    print(
        "\n========================================\n"
    )


if __name__ == "__main__":
    main()
