from services.nlp_service import (
    parse_nlp_text,
    parse_multiple_entries,
)


# ============================================================
# GLUCOSE TESTS
# ============================================================

def test_glucose():
    result = parse_nlp_text("My glucose is 120")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == 120
    assert result["unit"] == "mg/dL"
    assert result["status"] == "SUCCESS"


def test_glucose_decimal():
    result = parse_nlp_text("My glucose is 120.5")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == 120.5
    assert result["unit"] == "mg/dL"
    assert result["status"] == "SUCCESS"


def test_glucose_missing_value():
    result = parse_nlp_text("My glucose is")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["status"] == "MISSING_VALUE"
    assert result["value"] is None


def test_glucose_zero():
    result = parse_nlp_text("My glucose is 0")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["status"] == "INVALID_VALUE"


def test_glucose_negative():
    result = parse_nlp_text("My glucose is -50")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["status"] == "INVALID_VALUE"


# ============================================================
# INSULIN TESTS
# ============================================================

def test_insulin():
    result = parse_nlp_text(
        "I took 5 units of insulin"
    )

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] == 5
    assert result["unit"] == "units"
    assert result["status"] == "SUCCESS"


def test_insulin_decimal():
    result = parse_nlp_text(
        "I took 4.5 units of insulin"
    )

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] == 4.5
    assert result["unit"] == "units"
    assert result["status"] == "SUCCESS"


def test_insulin_missing_value():
    result = parse_nlp_text("I took insulin")

    assert result["intent"] == "LOG_INSULIN"
    assert result["status"] == "MISSING_VALUE"
    assert result["value"] is None


def test_insulin_zero():
    result = parse_nlp_text(
        "I took 0 units of insulin"
    )

    assert result["intent"] == "LOG_INSULIN"
    assert result["status"] == "INVALID_VALUE"


def test_insulin_negative():
    result = parse_nlp_text(
        "I took -5 units of insulin"
    )

    assert result["intent"] == "LOG_INSULIN"
    assert result["status"] == "INVALID_VALUE"


# ============================================================
# MEAL / CARBOHYDRATE TESTS
# ============================================================

def test_meal():
    result = parse_nlp_text(
        "I ate 50 grams of carbs"
    )

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] == 50
    assert result["unit"] == "grams"
    assert result["status"] == "SUCCESS"


def test_meal_decimal():
    result = parse_nlp_text(
        "I ate 42.5 grams of carbohydrates"
    )

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] == 42.5
    assert result["unit"] == "grams"
    assert result["status"] == "SUCCESS"


def test_meal_missing_value():
    result = parse_nlp_text(
        "I ate some carbs"
    )

    assert result["intent"] == "LOG_MEAL"
    assert result["status"] == "MISSING_VALUE"
    assert result["value"] is None


def test_meal_zero():
    result = parse_nlp_text(
        "I ate 0 grams of carbs"
    )

    assert result["intent"] == "LOG_MEAL"
    assert result["status"] == "INVALID_VALUE"


def test_meal_negative():
    result = parse_nlp_text(
        "I ate -20 grams of carbs"
    )

    assert result["intent"] == "LOG_MEAL"
    assert result["status"] == "INVALID_VALUE"


# ============================================================
# ACTIVITY TESTS
# ============================================================

def test_walking():
    result = parse_nlp_text(
        "I walked for 30 minutes"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "walked"
    assert result["value"] == 30
    assert result["unit"] == "minutes"
    assert result["status"] == "SUCCESS"


def test_running():
    result = parse_nlp_text("I ran 5 km")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "ran"
    assert result["value"] == 5
    assert result["unit"] == "km"
    assert result["status"] == "SUCCESS"


def test_swimming():
    result = parse_nlp_text(
        "I swam for 45 minutes"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "swam"
    assert result["value"] == 45
    assert result["unit"] == "minutes"
    assert result["status"] == "SUCCESS"


def test_cycling():
    result = parse_nlp_text(
        "I cycled for 1 hour"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "cycled"
    assert result["value"] == 1
    assert result["unit"] == "hours"
    assert result["status"] == "SUCCESS"


def test_squats():
    result = parse_nlp_text("I did 40 squats")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "squats"
    assert result["value"] == 40
    assert result["unit"] == "repetitions"
    assert result["status"] == "SUCCESS"


def test_activity_missing_value():
    result = parse_nlp_text(
        "I went walking"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["status"] == "MISSING_VALUE"


def test_activity_zero():
    result = parse_nlp_text(
        "I walked for 0 minutes"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["status"] == "INVALID_VALUE"


def test_activity_negative():
    result = parse_nlp_text(
        "I walked for -10 minutes"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["status"] == "INVALID_VALUE"


# ============================================================
# UNKNOWN INPUT
# ============================================================

def test_unknown():
    result = parse_nlp_text("Hello Dia")

    assert result["intent"] == "UNKNOWN"
    assert result["status"] == "UNKNOWN"
    assert result["value"] is None


# ============================================================
# RESPONSE STRUCTURE
# ============================================================

def test_input_type():
    result = parse_nlp_text(
        "My glucose is 120"
    )

    assert result["input_type"] == "TEXT"


def test_original_text():
    text = "My glucose is 120"

    result = parse_nlp_text(text)

    assert result["original_text"] == text


# ============================================================
# NATURAL LANGUAGE TESTS
# ============================================================

def test_natural_glucose_blood_sugar():
    result = parse_nlp_text(
        "My blood sugar was 135"
    )

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == 135
    assert result["unit"] == "mg/dL"
    assert result["status"] == "SUCCESS"


def test_natural_glucose_sugar_level():
    result = parse_nlp_text(
        "My sugar level is 142"
    )

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == 142
    assert result["status"] == "SUCCESS"


def test_natural_insulin():
    result = parse_nlp_text(
        "I injected 6 units of insulin"
    )

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] == 6
    assert result["unit"] == "units"
    assert result["status"] == "SUCCESS"


def test_natural_meal():
    result = parse_nlp_text(
        "My meal had 55 grams of carbohydrates"
    )

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] == 55
    assert result["unit"] == "grams"
    assert result["status"] == "SUCCESS"


def test_natural_walking():
    result = parse_nlp_text(
        "I went walking for 45 minutes"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["value"] == 45
    assert result["unit"] == "minutes"
    assert result["status"] == "SUCCESS"


# ============================================================
# SENTENCE VARIATIONS
# ============================================================

def test_glucose_sentence_variation():
    result = parse_nlp_text(
        "I checked my glucose and it was 128"
    )

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == 128
    assert result["status"] == "SUCCESS"


def test_insulin_sentence_variation():
    result = parse_nlp_text(
        "Just had 7 units of insulin"
    )

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] == 7
    assert result["status"] == "SUCCESS"


def test_carbs_sentence_variation():
    result = parse_nlp_text(
        "Lunch contained 60g of carbs"
    )

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] == 60
    assert result["status"] == "SUCCESS"


def test_activity_hours():
    result = parse_nlp_text(
        "I exercised for 1.5 hours"
    )

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["value"] == 1.5
    assert result["unit"] == "hours"
    assert result["status"] == "SUCCESS"


def test_activity_distance():
    result = parse_nlp_text("I ran 5 km")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["value"] == 5
    assert result["unit"] == "km"
    assert result["status"] == "SUCCESS"


def test_missing_glucose_value():
    result = parse_nlp_text(
        "I checked my blood sugar"
    )

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["status"] == "MISSING_VALUE"


def test_missing_insulin_value():
    result = parse_nlp_text(
        "I took my insulin"
    )

    assert result["intent"] == "LOG_INSULIN"
    assert result["status"] == "MISSING_VALUE"


# ============================================================
# MULTI-INTENT
# ============================================================

def test_multiple_glucose_and_insulin():
    result = parse_multiple_entries(
        "My glucose is 130 "
        "and I took 6 units of insulin"
    )

    assert result["status"] == "SUCCESS"
    assert result["input_type"] == "TEXT"
    assert result["result_count"] == 2
    assert len(result["results"]) == 2

    glucose = result["results"][0]
    insulin = result["results"][1]

    assert glucose["intent"] == "LOG_GLUCOSE"
    assert glucose["value"] == 130
    assert glucose["unit"] == "mg/dL"

    assert insulin["intent"] == "LOG_INSULIN"
    assert insulin["value"] == 6
    assert insulin["unit"] == "units"


def test_multiple_three_health_entries():
    result = parse_multiple_entries(
        "My glucose is 120, "
        "I took 5 units of insulin "
        "and I walked for 30 minutes"
    )

    assert result["status"] == "SUCCESS"
    assert result["input_type"] == "TEXT"
    assert result["result_count"] == 3
    assert len(result["results"]) == 3

    glucose = result["results"][0]
    insulin = result["results"][1]
    activity = result["results"][2]

    assert glucose["intent"] == "LOG_GLUCOSE"
    assert glucose["value"] == 120
    assert glucose["unit"] == "mg/dL"

    assert insulin["intent"] == "LOG_INSULIN"
    assert insulin["value"] == 5
    assert insulin["unit"] == "units"

    assert activity["intent"] == "LOG_ACTIVITY"
    assert activity["activity"] == "walked"
    assert activity["value"] == 30
    assert activity["unit"] == "minutes"


# ============================================================
# PARTIAL UNDERSTANDING
# ============================================================

def test_multiple_partial_understanding():
    result = parse_multiple_entries(
        "My glucose is 125 "
        "and blah blah something"
    )

    assert result["status"] == "SUCCESS"
    assert result["input_type"] == "TEXT"
    assert result["result_count"] == 1
    assert len(result["results"]) == 1

    glucose = result["results"][0]

    assert glucose["intent"] == "LOG_GLUCOSE"
    assert glucose["value"] == 125
    assert glucose["unit"] == "mg/dL"
    assert glucose["status"] == "SUCCESS"


# ============================================================
# MULTI-INTENT UNKNOWN
# ============================================================

def test_multiple_unknown_input():
    result = parse_multiple_entries(
        "hello there and how are you"
    )

    assert result["status"] == "UNKNOWN"
    assert result["input_type"] == "TEXT"
    assert result["result_count"] == 0
    assert result["results"] == []


# ============================================================
# MULTI-INTENT ORIGINAL TEXT
# ============================================================

def test_multiple_preserves_original_text():
    text = (
        "My glucose is 130 "
        "and I took 6 units of insulin"
    )

    result = parse_multiple_entries(text)

    assert result["original_text"] == text


# ============================================================
# RESULT COUNT
# ============================================================

def test_multiple_result_count():
    result = parse_multiple_entries(
        "My glucose is 120, "
        "I took 5 units of insulin "
        "and I walked for 30 minutes"
    )

    assert result["status"] == "SUCCESS"
    assert result["result_count"] == 3
    assert len(result["results"]) == 3


def test_multiple_unknown_result_count():
    result = parse_multiple_entries(
        "hello there and how are you"
    )

    assert result["status"] == "UNKNOWN"
    assert result["result_count"] == 0
    assert result["results"] == []
