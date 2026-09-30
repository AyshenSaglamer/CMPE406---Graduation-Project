from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


# =========================================================
# ROOT & HEALTH ENDPOINT TESTS
# =========================================================

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


# =========================================================
# SINGLE NLP PARSE ENDPOINT TESTS
# =========================================================

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
        json={"text": "I took 6 units of insulin"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_INSULIN"
    assert data["value"] == 6
    assert data["unit"] == "units"
    assert data["status"] == "SUCCESS"


def test_parse_meal():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "I ate 45 grams of carbs"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_MEAL"
    assert data["value"] == 45
    assert data["unit"] == "grams"
    assert data["status"] == "SUCCESS"


def test_parse_activity():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "I walked for 30 minutes"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_ACTIVITY"
    assert data["value"] == 30
    assert data["unit"] == "minutes"
    assert data["status"] == "SUCCESS"


# =========================================================
# SINGLE PARSE VALUE VALIDATION TESTS
# =========================================================

def test_parse_missing_glucose_value():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "My glucose is high"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_GLUCOSE"
    assert data["status"] == "MISSING_VALUE"


def test_parse_invalid_glucose_value():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "My glucose is -20"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "LOG_GLUCOSE"
    assert data["status"] == "INVALID_VALUE"


def test_parse_unknown_input():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "Today is a beautiful day"},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["intent"] == "UNKNOWN"
    assert data["status"] == "UNKNOWN"


# =========================================================
# SINGLE PARSE REQUEST FORMAT TESTS
# =========================================================

def test_parse_missing_text_field():
    response = client.post(
        "/api/v1/nlp/parse",
        json={},
    )

    assert response.status_code == 422


def test_parse_malformed_json():
    response = client.post(
        "/api/v1/nlp/parse",
        content="{bad json}",
        headers={"Content-Type": "application/json"},
    )

    assert response.status_code == 422


# =========================================================
# SINGLE PARSE INPUT VALIDATION TESTS
# =========================================================

def test_parse_rejects_empty_text():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": ""},
    )

    assert response.status_code == 422


def test_parse_rejects_whitespace_only_text():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "     "},
    )

    assert response.status_code == 422


def test_parse_rejects_text_over_500_characters():
    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": "a" * 501},
    )

    assert response.status_code == 422


# =========================================================
# SINGLE PARSE ORIGINAL TEXT TEST
# =========================================================

def test_parse_preserves_original_text():
    text = "My glucose is 135"

    response = client.post(
        "/api/v1/nlp/parse",
        json={"text": text},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["original_text"] == text


# =========================================================
# MULTI-INTENT ENDPOINT TESTS
# =========================================================

def test_parse_multiple_glucose_and_insulin():
    text = (
        "My glucose is 130 and "
        "I took 6 units of insulin"
    )

    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": text},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["input_type"] == "TEXT"
    assert data["result_count"] == 2
    assert len(data["results"]) == 2

    intents = [
        result["intent"]
        for result in data["results"]
    ]

    assert "LOG_GLUCOSE" in intents
    assert "LOG_INSULIN" in intents


def test_parse_multiple_three_entries():
    text = (
        "My glucose is 125 and "
        "I took 5 units of insulin and "
        "I walked for 30 minutes"
    )

    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": text},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["result_count"] == 3
    assert len(data["results"]) == 3

    intents = [
        result["intent"]
        for result in data["results"]
    ]

    assert "LOG_GLUCOSE" in intents
    assert "LOG_INSULIN" in intents
    assert "LOG_ACTIVITY" in intents


def test_parse_multiple_partial_understanding():
    text = (
        "My glucose is 140 and "
        "the weather is nice"
    )

    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": text},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["result_count"] == 1
    assert len(data["results"]) == 1

    assert data["results"][0]["intent"] == "LOG_GLUCOSE"


def test_parse_multiple_unknown():
    text = (
        "Today is sunny and "
        "I like listening to music"
    )

    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": text},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "UNKNOWN"
    assert data["result_count"] == 0
    assert data["results"] == []


def test_parse_multiple_preserves_original_text():
    text = (
        "My glucose is 120 and "
        "I took 4 units of insulin"
    )

    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": text},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["original_text"] == text


# =========================================================
# MULTI-INTENT REQUEST FORMAT TESTS
# =========================================================

def test_parse_multiple_missing_text_field():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={},
    )

    assert response.status_code == 422


def test_parse_multiple_malformed_json():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        content="{bad json}",
        headers={"Content-Type": "application/json"},
    )

    assert response.status_code == 422


# =========================================================
# MULTI-INTENT INPUT VALIDATION TESTS
# =========================================================

def test_parse_multiple_rejects_empty_text():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": ""},
    )

    assert response.status_code == 422


def test_parse_multiple_rejects_whitespace_only_text():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": "     "},
    )

    assert response.status_code == 422


def test_parse_multiple_rejects_text_over_500_characters():
    response = client.post(
        "/api/v1/nlp/parse-multiple",
        json={"text": "a" * 501},
    )

    assert response.status_code == 422
