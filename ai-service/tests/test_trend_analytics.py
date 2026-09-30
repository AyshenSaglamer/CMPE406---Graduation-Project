import pytest

from analytics.trend_analytics import (
    calculate_daily_trends,
    calculate_weekly_trends,
    calculate_monthly_trends,
    calculate_glucose_trends,
)


# =========================================================
# TEST DATA
# =========================================================

SAMPLE_RECORDS = [
    {
        "timestamp": "2026-09-01 08:00:00",
        "glucose_mg_dl": 100,
    },
    {
        "timestamp": "2026-09-01 14:00:00",
        "glucose_mg_dl": 140,
    },
    {
        "timestamp": "2026-09-02 08:00:00",
        "glucose_mg_dl": 120,
    },
    {
        "timestamp": "2026-09-08 08:00:00",
        "glucose_mg_dl": 160,
    },
    {
        "timestamp": "2026-10-01 08:00:00",
        "glucose_mg_dl": 130,
    },
]


# =========================================================
# DAILY TREND TESTS
# =========================================================

def test_daily_trends():
    result = calculate_daily_trends(SAMPLE_RECORDS)

    assert len(result) == 4

    first_day = result[0]

    assert first_day["period"] == "2026-09-01"
    assert first_day["count"] == 2
    assert first_day["mean"] == 120.0
    assert first_day["minimum"] == 100.0
    assert first_day["maximum"] == 140.0


def test_daily_trends_multiple_days():
    result = calculate_daily_trends(SAMPLE_RECORDS)

    periods = [
        item["period"]
        for item in result
    ]

    assert "2026-09-01" in periods
    assert "2026-09-02" in periods
    assert "2026-09-08" in periods
    assert "2026-10-01" in periods


# =========================================================
# WEEKLY TREND TESTS
# =========================================================

def test_weekly_trends():
    result = calculate_weekly_trends(SAMPLE_RECORDS)

    assert len(result) == 3

    first_week = result[0]

    assert first_week["period"] == "2026-08-31"
    assert first_week["count"] == 3
    assert first_week["mean"] == 120.0
    assert first_week["minimum"] == 100.0
    assert first_week["maximum"] == 140.0


def test_weekly_trends_separate_weeks():
    result = calculate_weekly_trends(SAMPLE_RECORDS)

    periods = [
        item["period"]
        for item in result
    ]

    assert "2026-08-31" in periods
    assert "2026-09-07" in periods
    assert "2026-09-28" in periods


# =========================================================
# MONTHLY TREND TESTS
# =========================================================

def test_monthly_trends():
    result = calculate_monthly_trends(SAMPLE_RECORDS)

    assert len(result) == 2

    september = result[0]

    assert september["period"] == "2026-09"
    assert september["count"] == 4
    assert september["mean"] == 130.0
    assert september["minimum"] == 100.0
    assert september["maximum"] == 160.0


def test_monthly_trends_separate_months():
    result = calculate_monthly_trends(SAMPLE_RECORDS)

    assert result[0]["period"] == "2026-09"
    assert result[1]["period"] == "2026-10"


# =========================================================
# GENERIC TREND INTERFACE TESTS
# =========================================================

def test_generic_daily_period():
    result = calculate_glucose_trends(
        SAMPLE_RECORDS,
        period="daily",
    )

    expected = calculate_daily_trends(
        SAMPLE_RECORDS
    )

    assert result == expected


def test_generic_weekly_period():
    result = calculate_glucose_trends(
        SAMPLE_RECORDS,
        period="weekly",
    )

    expected = calculate_weekly_trends(
        SAMPLE_RECORDS
    )

    assert result == expected


def test_generic_monthly_period():
    result = calculate_glucose_trends(
        SAMPLE_RECORDS,
        period="monthly",
    )

    expected = calculate_monthly_trends(
        SAMPLE_RECORDS
    )

    assert result == expected


def test_invalid_period_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "Period must be daily, weekly, "
            "or monthly"
        ),
    ):
        calculate_glucose_trends(
            SAMPLE_RECORDS,
            period="yearly",
        )


# =========================================================
# INPUT VALIDATION TESTS
# =========================================================

def test_empty_records_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose records cannot be empty",
    ):
        calculate_daily_trends([])


def test_missing_timestamp_rejected():
    records = [
        {
            "glucose_mg_dl": 120,
        }
    ]

    with pytest.raises(
        ValueError,
        match=(
            "Each record must contain timestamp "
            "and glucose_mg_dl"
        ),
    ):
        calculate_daily_trends(records)


def test_missing_glucose_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
        }
    ]

    with pytest.raises(
        ValueError,
        match=(
            "Each record must contain timestamp "
            "and glucose_mg_dl"
        ),
    ):
        calculate_daily_trends(records)


def test_invalid_timestamp_rejected():
    records = [
        {
            "timestamp": "not-a-date",
            "glucose_mg_dl": 120,
        }
    ]

    with pytest.raises(
        ValueError,
        match="All timestamps must be valid",
    ):
        calculate_daily_trends(records)


def test_non_numeric_glucose_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": "hello",
        }
    ]

    with pytest.raises(
        ValueError,
        match="All glucose values must be numeric",
    ):
        calculate_daily_trends(records)


def test_zero_glucose_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 0,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Glucose values must be greater than zero",
    ):
        calculate_daily_trends(records)


def test_negative_glucose_rejected():
    records = [
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": -20,
        }
    ]

    with pytest.raises(
        ValueError,
        match="Glucose values must be greater than zero",
    ):
        calculate_daily_trends(records)


# =========================================================
# ORDERING TEST
# =========================================================

def test_records_are_sorted_by_period():
    records = [
        {
            "timestamp": "2026-09-03 08:00:00",
            "glucose_mg_dl": 130,
        },
        {
            "timestamp": "2026-09-01 08:00:00",
            "glucose_mg_dl": 110,
        },
        {
            "timestamp": "2026-09-02 08:00:00",
            "glucose_mg_dl": 120,
        },
    ]

    result = calculate_daily_trends(records)

    assert result[0]["period"] == "2026-09-01"
    assert result[1]["period"] == "2026-09-02"
    assert result[2]["period"] == "2026-09-03"
