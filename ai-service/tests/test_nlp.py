from services.nlp_service import parse_nlp_text


def test_glucose():
    result = parse_nlp_text("My glucose is 125")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == 125.0
    assert result["unit"] == "mg/dL"


def test_glucose_missing_value():
    result = parse_nlp_text("My glucose is high")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] is None
    assert result["status"] == "MISSING_VALUE"


def test_insulin():
    result = parse_nlp_text("I took 6 units of insulin")

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] == 6.0
    assert result["unit"] == "units"


def test_insulin_missing_value():
    result = parse_nlp_text("I took insulin")

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] is None
    assert result["status"] == "MISSING_VALUE"


def test_meal():
    result = parse_nlp_text("I ate 45 grams of carbs")

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] == 45.0
    assert result["unit"] == "grams"


def test_walking():
    result = parse_nlp_text("I walked for 30 minutes")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["value"] == 30.0
    assert result["unit"] == "minutes"


def test_meal_missing_value():
    result = parse_nlp_text("I ate some carbs")

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] is None
    assert result["status"] == "MISSING_VALUE"


def test_squats():
    result = parse_nlp_text("I did 20 squats")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "squats"
    assert result["value"] == 20.0
    assert result["unit"] == "repetitions"


def test_running_distance():
    result = parse_nlp_text("I ran 5 km")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["value"] == 5.0
    assert result["unit"] == "km"


def test_yoga():
    result = parse_nlp_text("I did yoga for 1 hour")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "yoga"
    assert result["value"] == 1.0
    assert result["unit"] == "hours"


def test_activity_missing_value():
    result = parse_nlp_text("I went running")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["activity"] == "running"
    assert result["value"] is None
    assert result["status"] == "MISSING_VALUE"


def test_unknown():
    result = parse_nlp_text("Hello Dia")

    assert result["intent"] == "UNKNOWN"
    assert result["value"] is None
    assert result["unit"] is None


def test_negative_glucose():
    result = parse_nlp_text("My glucose is -20")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == -20.0
    assert result["status"] == "INVALID_VALUE"


def test_zero_glucose():
    result = parse_nlp_text("My glucose is 0")

    assert result["intent"] == "LOG_GLUCOSE"
    assert result["value"] == 0.0
    assert result["status"] == "INVALID_VALUE"


def test_negative_insulin():
    result = parse_nlp_text("I took -5 units of insulin")

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] == -5.0
    assert result["status"] == "INVALID_VALUE"


def test_zero_insulin():
    result = parse_nlp_text("I took 0 units of insulin")

    assert result["intent"] == "LOG_INSULIN"
    assert result["value"] == 0.0
    assert result["status"] == "INVALID_VALUE"


def test_negative_carbs():
    result = parse_nlp_text("I ate -30 grams of carbs")

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] == -30.0
    assert result["status"] == "INVALID_VALUE"


def test_zero_carbs():
    result = parse_nlp_text("I ate 0 grams of carbs")

    assert result["intent"] == "LOG_MEAL"
    assert result["value"] == 0.0
    assert result["status"] == "INVALID_VALUE"


def test_negative_activity():
    result = parse_nlp_text("I walked for -30 minutes")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["value"] == -30.0
    assert result["status"] == "INVALID_VALUE"


def test_zero_activity():
    result = parse_nlp_text("I did 0 squats")

    assert result["intent"] == "LOG_ACTIVITY"
    assert result["value"] == 0.0
    assert result["status"] == "INVALID_VALUE"
