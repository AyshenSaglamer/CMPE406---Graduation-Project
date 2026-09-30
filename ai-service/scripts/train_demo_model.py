import sys
from pathlib import Path

import pandas as pd

# Allow the script to import the ai-service modules
AI_SERVICE_ROOT = Path(__file__).resolve().parents[1]

if str(AI_SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_SERVICE_ROOT))

from ml.training import train_glucose_trend_model


def create_demo_records():
    """
    Create deterministic synthetic records only for
    validating the DiaMate ML software pipeline.

    These are not real patient records and must not be
    interpreted as clinical evidence.
    """

    glucose_pattern = [
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
        190,
        230,
        235,
        200,
        240,
        245,
        210,
    ]

    records = []

    start_time = pd.Timestamp(
        "2026-01-01 08:00:00"
    )

    for index, glucose in enumerate(
        glucose_pattern
    ):
        timestamp = (
            start_time
            + pd.Timedelta(hours=index * 4)
        )

        records.append(
            {
                "timestamp": timestamp.isoformat(),
                "glucose_mg_dl": glucose,
                "carbs_g": 20 + (index % 5) * 10,
                "activity_minutes": (
                    (index % 4) * 10
                ),
            }
        )

    return records


def main():
    print(
        "Creating synthetic DiaMate demo data..."
    )

    records = create_demo_records()

    print(
        f"Created {len(records)} records."
    )

    print("Training XGBoost model...")

    result = train_glucose_trend_model(
        records,
        test_ratio=0.20,
        save_model=True,
    )

    print("\nTraining completed.")
    print(
        "Training samples:",
        result["training_sample_size"],
    )
    print(
        "Test samples:",
        result["test_sample_size"],
    )
    print(
        "Classes:",
        result["classes"],
    )
    print(
        "Features:",
        result["feature_names"],
    )
    print(
        "Demo accuracy:",
        result["metrics"]["accuracy"],
    )

    print("\nSaved artifacts:")

    for name, path in result[
        "artifacts"
    ].items():
        print(
            f"  {name}: {path}"
        )

    print(
        "\nIMPORTANT: This model was trained on "
        "synthetic demonstration data. Its metrics "
        "do not represent clinical performance."
    )


if __name__ == "__main__":
    main()
