import pytest

from analytics.correlation_analytics import (
    calculate_activity_glucose_correlation,
    calculate_glucose_correlations,
    calculate_meal_glucose_correlation,
)


# =========================================================
# TEST DATA
# =========================================================

SAMPLE_RECORDS = [
    {
        "glucose_mg_dl": 90,
        "carbs_g": 20,
        "activity_minutes": 60,
    },
    {
        "glucose_mg_dl": 110,
        "carbs_g": 30,
        "activity_minutes": 45,
    },
    {
        "glucose_mg_dl": 130,
        "carbs_g": 40,
        "activity_minutes": 30,
    },
    {
        "glucose_mg_dl": 150,
        "carbs_g": 50,
        "activity_minutes": 20,
    },
    {
        "glucose_mg_dl": 170,
        "carbs_g": 60,
        "activity_minutes": 10,
    },
]


# =========================================================
# MEAL ↔ GLUCOSE TESTS
# =========================================================

def test_meal_glucose_correlation():
    result = calculate_meal_glucose_correlation(
        SAMPLE_RECORDS
    )

    assert result["feature"] == "carbs_g"
    assert result["target"] == "glucose_mg_dl"
    assert result["method"] == "pearson"
    assert result["sample_size"] == 5

    assert result["correlation"] == 1.0


# =========================================================
# ACTIVITY ↔ GLUCOSE TESTS
# =========================================================

def test_activity_glucose_correlation():
    result = calculate_activity_glucose_correlation(
        SAMPLE_RECORDS
    )

    assert result["feature"] == "activity_minutes"
    assert result["target"] == "glucose_mg_dl"
    assert result["method"] == "pearson"
    assert result["sample_size"] == 5

    assert result["correlation"] < 0


# =========================================================
# COMBINED ANALYTICS TEST
# =========================================================

def test_all_glucose_correlations():
    result = calculate_glucose_correlations(
        SAMPLE_RECORDS
    )

    assert "meal_glucose" in result
    assert "activity_glucose" in result

    assert (
        result["meal_glucose"]["feature"]
        == "carbs_g"
    )

    assert (
        result["activity_glucose"]["feature"]
        == "activity_minutes"
    )


# =========================================================
# INPUT VALIDATION TESTS
# =========================================================

def test_empty_records_rejected():
    with pytest.raises(
        ValueError,
        match="Analytics records cannot be empty",
    ):
        calculate_glucose_correlations([])


def test_missing_glucose_field_rejected():
    records = [
        {
            "carbs_g": 30,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Each record must contain",
    ):
        calculate_glucose_correlations(records)


def test_missing_carbs_field_rejected():
    records = [
        {
            "glucose_mg_dl": 120,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Each record must contain",
    ):
        calculate_glucose_correlations(records)


def test_missing_activity_field_rejected():
    records = [
        {
            "glucose_mg_dl": 120,
            "carbs_g": 30,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Each record must contain",
    ):
        calculate_glucose_correlations(records)


def test_non_numeric_glucose_rejected():
    records = [
        {
            "glucose_mg_dl": "hello",
            "carbs_g": 30,
            "activity_minutes": 20,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 30,
        },
    ]

    with pytest.raises(
        ValueError,
        match="glucose_mg_dl must contain numeric values",
    ):
        calculate_glucose_correlations(records)


def test_non_numeric_carbs_rejected():
    records = [
        {
            "glucose_mg_dl": 100,
            "carbs_g": "food",
            "activity_minutes": 20,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 30,
        },
    ]

    with pytest.raises(
        ValueError,
        match="carbs_g must contain numeric values",
    ):
        calculate_glucose_correlations(records)


def test_negative_glucose_rejected():
    records = [
        {
            "glucose_mg_dl": -100,
            "carbs_g": 20,
            "activity_minutes": 30,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 20,
        },
    ]

    with pytest.raises(
        ValueError,
        match="Glucose values must be greater than zero",
    ):
        calculate_glucose_correlations(records)


def test_negative_carbs_rejected():
    records = [
        {
            "glucose_mg_dl": 100,
            "carbs_g": -20,
            "activity_minutes": 30,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 20,
        },
    ]

    with pytest.raises(
        ValueError,
        match="Carbohydrate values cannot be negative",
    ):
        calculate_glucose_correlations(records)


def test_negative_activity_rejected():
    records = [
        {
            "glucose_mg_dl": 100,
            "carbs_g": 20,
            "activity_minutes": -30,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 20,
        },
    ]

    with pytest.raises(
        ValueError,
        match="Activity minutes cannot be negative",
    ):
        calculate_glucose_correlations(records)


# =========================================================
# CORRELATION REQUIREMENT TESTS
# =========================================================

def test_single_record_rejected():
    records = [
        {
            "glucose_mg_dl": 120,
            "carbs_g": 30,
            "activity_minutes": 20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="At least two records are required",
    ):
        calculate_meal_glucose_correlation(records)


def test_constant_carbs_rejected():
    records = [
        {
            "glucose_mg_dl": 100,
            "carbs_g": 30,
            "activity_minutes": 10,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 30,
            "activity_minutes": 20,
        },
        {
            "glucose_mg_dl": 140,
            "carbs_g": 30,
            "activity_minutes": 30,
        },
    ]

    with pytest.raises(
        ValueError,
        match="carbs_g must contain at least two different values",
    ):
        calculate_meal_glucose_correlation(records)


def test_constant_glucose_rejected():
    records = [
        {
            "glucose_mg_dl": 120,
            "carbs_g": 20,
            "activity_minutes": 10,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 40,
            "activity_minutes": 20,
        },
        {
            "glucose_mg_dl": 120,
            "carbs_g": 60,
            "activity_minutes": 30,
        },
    ]

    with pytest.raises(
        ValueError,
        match=(
            "glucose_mg_dl must contain at least "
            "two different values"
        ),
    ):
        calculate_meal_glucose_correlation(records)
