import math

import pytest

from analytics.glucose_analytics import (
    calculate_glucose_statistics,
    calculate_time_in_range,
)


# =========================================================
# GLUCOSE STATISTICS TESTS
# =========================================================

def test_calculate_glucose_statistics():
    result = calculate_glucose_statistics(
        [100, 120, 140, 160]
    )

    assert result["count"] == 4
    assert result["mean"] == 130.0
    assert result["minimum"] == 100.0
    assert result["maximum"] == 160.0
    assert result["standard_deviation"] == 22.36


def test_single_glucose_value():
    result = calculate_glucose_statistics([120])

    assert result["count"] == 1
    assert result["mean"] == 120.0
    assert result["minimum"] == 120.0
    assert result["maximum"] == 120.0
    assert result["standard_deviation"] == 0.0


def test_decimal_glucose_values():
    result = calculate_glucose_statistics(
        [100.5, 120.5, 140.5]
    )

    assert result["count"] == 3
    assert result["mean"] == 120.5
    assert result["minimum"] == 100.5
    assert result["maximum"] == 140.5


def test_empty_glucose_values_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose values cannot be empty",
    ):
        calculate_glucose_statistics([])


def test_zero_glucose_rejected():
    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        calculate_glucose_statistics(
            [100, 0, 120]
        )


def test_negative_glucose_rejected():
    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        calculate_glucose_statistics(
            [100, -20, 120]
        )


def test_nan_glucose_rejected():
    with pytest.raises(
        ValueError,
        match="missing values",
    ):
        calculate_glucose_statistics(
            [100, math.nan, 120]
        )


def test_infinite_glucose_rejected():
    with pytest.raises(
        ValueError,
        match="finite",
    ):
        calculate_glucose_statistics(
            [100, math.inf, 120]
        )


# =========================================================
# TIME IN RANGE TESTS
# =========================================================

def test_time_in_range():
    result = calculate_time_in_range(
        [60, 70, 100, 180, 200]
    )

    assert result["total_readings"] == 5

    assert result["below_range_count"] == 1
    assert result["in_range_count"] == 3
    assert result["above_range_count"] == 1

    assert result["below_range_percentage"] == 20.0
    assert result["time_in_range_percentage"] == 60.0
    assert result["above_range_percentage"] == 20.0

    assert result["lower_bound"] == 70.0
    assert result["upper_bound"] == 180.0


def test_all_values_in_range():
    result = calculate_time_in_range(
        [80, 100, 120, 150]
    )

    assert result["total_readings"] == 4
    assert result["below_range_count"] == 0
    assert result["in_range_count"] == 4
    assert result["above_range_count"] == 0

    assert result["time_in_range_percentage"] == 100.0


def test_all_values_below_range():
    result = calculate_time_in_range(
        [50, 60, 65]
    )

    assert result["below_range_count"] == 3
    assert result["in_range_count"] == 0
    assert result["above_range_count"] == 0

    assert result["below_range_percentage"] == 100.0


def test_all_values_above_range():
    result = calculate_time_in_range(
        [190, 200, 250]
    )

    assert result["below_range_count"] == 0
    assert result["in_range_count"] == 0
    assert result["above_range_count"] == 3

    assert result["above_range_percentage"] == 100.0


def test_custom_time_in_range_bounds():
    result = calculate_time_in_range(
        [80, 100, 150, 170],
        lower_bound=90,
        upper_bound=160,
    )

    assert result["below_range_count"] == 1
    assert result["in_range_count"] == 2
    assert result["above_range_count"] == 1

    assert result["time_in_range_percentage"] == 50.0

    assert result["lower_bound"] == 90.0
    assert result["upper_bound"] == 160.0


def test_time_in_range_includes_boundary_values():
    result = calculate_time_in_range(
        [70, 180]
    )

    assert result["below_range_count"] == 0
    assert result["in_range_count"] == 2
    assert result["above_range_count"] == 0

    assert result["time_in_range_percentage"] == 100.0


def test_time_in_range_empty_values_rejected():
    with pytest.raises(
        ValueError,
        match="Glucose values cannot be empty",
    ):
        calculate_time_in_range([])


def test_time_in_range_invalid_lower_bound():
    with pytest.raises(
        ValueError,
        match="Range bounds must be greater than zero",
    ):
        calculate_time_in_range(
            [100, 120],
            lower_bound=0,
            upper_bound=180,
        )


def test_time_in_range_invalid_upper_bound():
    with pytest.raises(
        ValueError,
        match="Range bounds must be greater than zero",
    ):
        calculate_time_in_range(
            [100, 120],
            lower_bound=70,
            upper_bound=0,
        )


def test_time_in_range_rejects_reversed_bounds():
    with pytest.raises(
        ValueError,
        match="Lower bound must be less than upper bound",
    ):
        calculate_time_in_range(
            [100, 120],
            lower_bound=180,
            upper_bound=70,
        )


def test_time_in_range_rejects_equal_bounds():
    with pytest.raises(
        ValueError,
        match="Lower bound must be less than upper bound",
    ):
        calculate_time_in_range(
            [100, 120],
            lower_bound=100,
            upper_bound=100,
        )
