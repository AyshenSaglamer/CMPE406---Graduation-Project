from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


# ============================================================
# BASIC API
# ============================================================

def test_root():
    response = client.get("/")

    assert response.status_code == 200

    data = response.json()

    assert data["service"] == "DiaMate AI Service"
    assert data["status"] == "running"


def test_health():
    response = client.get("/health")

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "healthy"


# ============================================================
# SINGLE-ENTRY API
# ============================================================

def test_parse_glucose():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "My glucose is 120"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_GLUCOSE"
    assert data["value"] == 120
    assert data["unit"] == "mg/dL"
    assert data["status"] == "SUCCESS"
    assert data["input_type"] == "TEXT"


def test_parse_insulin():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "I took 5 units of insulin"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_INSULIN"
    assert data["value"] == 5
    assert data["unit"] == "units"
    assert data["status"] == "SUCCESS"


def test_parse_meal():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "I ate 50 grams of carbs"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_MEAL"
    assert data["value"] == 50
    assert data["unit"] == "grams"
    assert data["status"] == "SUCCESS"


def test_parse_activity():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "I walked for 30 minutes"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_ACTIVITY"
    assert data["activity"] == "walked"
    assert data["value"] == 30
    assert data["unit"] == "minutes"
    assert data["status"] == "SUCCESS"


# ============================================================
# SINGLE-ENTRY VALIDATION
# ============================================================

def test_parse_glucose_missing_value():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "My glucose is"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_GLUCOSE"
    assert data["status"] == "MISSING_VALUE"
    assert data["value"] is None


def test_parse_glucose_invalid_value():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "My glucose is -50"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_GLUCOSE"
    assert data["status"] == "INVALID_VALUE"
    assert data["value"] == -50


def test_parse_insulin_missing_value():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "I took insulin"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_INSULIN"
    assert data["status"] == "MISSING_VALUE"


def test_parse_activity_missing_value():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "I went walking"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_ACTIVITY"
    assert data["status"] == "MISSING_VALUE"


# ============================================================
# UNKNOWN
# ============================================================

def test_parse_unknown():
    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": "Hello Dia"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "UNKNOWN"
    assert data["status"] == "UNKNOWN"
    assert data["value"] is None


# ============================================================
# REQUEST VALIDATION
# ============================================================

def test_parse_missing_text_field():
    response = client.post(
        "/api/v1/nlp/parse",
        json={},
    )

    assert response.status_code == 422


def test_parse_malformed_json():
    response = client.post(
        "/api/v1/nlp/parse",
        content='{"text":',
        headers={
            "Content-Type": "application/json"
        },
    )

    assert response.status_code == 422


# ============================================================
# MULTI-INTENT API
# ============================================================

def test_parse_multiple_glucose_and_insulin():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={
            "text": (
                "My glucose is 130 "
                "and I took 6 units of insulin"
            )
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["input_type"] == "TEXT"
    assert data["result_count"] == 2
    assert len(data["results"]) == 2

    glucose = data["results"][0]
    insulin = data["results"][1]

    assert glucose["intent"] == "LOG_GLUCOSE"
    assert glucose["value"] == 130
    assert glucose["unit"] == "mg/dL"

    assert insulin["intent"] == "LOG_INSULIN"
    assert insulin["value"] == 6
    assert insulin["unit"] == "units"


def test_parse_multiple_three_entries():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={
            "text": (
                "My glucose is 120, "
                "I took 5 units of insulin "
                "and I walked for 30 minutes"
            )
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["input_type"] == "TEXT"
    assert data["result_count"] == 3
    assert len(data["results"]) == 3

    glucose = data["results"][0]
    insulin = data["results"][1]
    activity = data["results"][2]

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

def test_parse_multiple_partial_understanding():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={
            "text": (
                "My glucose is 125 "
                "and blah blah something"
            )
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["input_type"] == "TEXT"
    assert data["result_count"] == 1
    assert len(data["results"]) == 1

    glucose = data["results"][0]

    assert glucose["intent"] == "LOG_GLUCOSE"
    assert glucose["value"] == 125
    assert glucose["unit"] == "mg/dL"


# ============================================================
# MULTI-INTENT UNKNOWN
# ============================================================

def test_parse_multiple_unknown():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={
            "text": "hello there and how are you"
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "UNKNOWN"
    assert data["input_type"] == "TEXT"
    assert data["result_count"] == 0
    assert data["results"] == []


# ============================================================
# MULTI-INTENT REQUEST VALIDATION
# ============================================================

def test_parse_multiple_missing_text_field():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={},
    )

    assert response.status_code == 422


def test_parse_multiple_malformed_json():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        content='{"text":',
        headers={
            "Content-Type": "application/json"
        },
    )

    assert response.status_code == 422


# ============================================================
# ORIGINAL TEXT
# ============================================================

def test_parse_original_text():
    text = "My glucose is 140"

    response = client.post(
        "/api/v1/nlp/parse",
        json={
            "text": text
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["original_text"] == text


def test_parse_multiple_original_text():
    text = (
        "My glucose is 130 "
        "and I took 6 units of insulin"
    )

    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={
            "text": text
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["original_text"] == text


# ============================================================
# RESULT COUNT
# ============================================================

def test_parse_multiple_result_count():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={
            "text": (
                "My glucose is 120 "
                "and I took 5 units of insulin"
            )
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["result_count"] == 2
    assert len(data["results"]) == 2
