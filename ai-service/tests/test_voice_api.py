from unittest.mock import patch

from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


# =========================================================
# ERROR CONTRACT HELPER
# =========================================================

def assert_api_error(
    response,
    *,
    status_code,
    code,
    message,
):
    assert response.status_code == status_code

    body = response.json()

    assert body["status"] == "ERROR"
    assert body["error"]["code"] == code
    assert body["error"]["message"] == message


SUCCESSFUL_NLP_RESPONSE = {
    "status": "SUCCESS",
    "input_type": "VOICE",
    "transcript": (
        "My glucose is 145 and "
        "I walked for 30 minutes."
    ),
    "result_count": 2,
    "results": [
        {
            "intent": "LOG_GLUCOSE",
            "value": 145.0,
            "unit": "mg/dL",
            "status": "SUCCESS",
            "input_type": "TEXT",
        },
        {
            "intent": "LOG_ACTIVITY",
            "value": 30.0,
            "unit": "minutes",
            "status": "SUCCESS",
            "activity": "walk",
            "input_type": "TEXT",
        },
    ],
}


# =========================================================
# SUCCESS
# =========================================================

@patch(
    "main.transcribe_and_process_audio"
)
def test_voice_endpoint_success(
    mock_process_audio,
):
    mock_process_audio.return_value = (
        SUCCESSFUL_NLP_RESPONSE
    )

    response = client.post(
        "/api/v1/voice/parse",
        files={
            "audio": (
                "voice.wav",
                b"fake audio content",
                "audio/wav",
            )
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "SUCCESS"
    assert data["input_type"] == "VOICE"
    assert data["result_count"] == 2

    assert (
        data["results"][0]["intent"]
        == "LOG_GLUCOSE"
    )

    assert (
        data["results"][1]["intent"]
        == "LOG_ACTIVITY"
    )

    mock_process_audio.assert_called_once()


# =========================================================
# REQUEST VALIDATION
# =========================================================

def test_voice_endpoint_missing_file():
    response = client.post(
        "/api/v1/voice/parse"
    )

    assert response.status_code == 422


def test_voice_endpoint_empty_file():
    response = client.post(
        "/api/v1/voice/parse",
        files={
            "audio": (
                "voice.wav",
                b"",
                "audio/wav",
            )
        },
    )

    assert_api_error(
        response,
        status_code=422,
        code="INVALID_INPUT",
        message="Audio file cannot be empty.",
    )


def test_voice_endpoint_invalid_extension():
    response = client.post(
        "/api/v1/voice/parse",
        files={
            "audio": (
                "voice.exe",
                b"fake audio",
                "audio/wav",
            )
        },
    )

    assert_api_error(
        response,
        status_code=422,
        code="INVALID_INPUT",
        message=(
            "Unsupported audio file extension."
        ),
    )


def test_voice_endpoint_invalid_content_type():
    response = client.post(
        "/api/v1/voice/parse",
        files={
            "audio": (
                "voice.wav",
                b"fake audio",
                "application/pdf",
            )
        },
    )

    assert_api_error(
        response,
        status_code=422,
        code="INVALID_INPUT",
        message=(
            "Unsupported audio content type."
        ),
    )


# =========================================================
# SPEECH-TO-TEXT ERRORS
# =========================================================

@patch(
    "main.transcribe_and_process_audio"
)
def test_voice_endpoint_no_speech(
    mock_process_audio,
):
    mock_process_audio.side_effect = ValueError(
        "No speech could be detected "
        "in the audio."
    )

    response = client.post(
        "/api/v1/voice/parse",
        files={
            "audio": (
                "voice.wav",
                b"fake audio",
                "audio/wav",
            )
        },
    )

    assert_api_error(
        response,
        status_code=422,
        code="INVALID_INPUT",
        message=(
            "No speech could be detected "
            "in the audio."
        ),
    )


@patch(
    "main.transcribe_and_process_audio"
)
def test_voice_endpoint_stt_runtime_error(
    mock_process_audio,
):
    mock_process_audio.side_effect = RuntimeError(
        "Speech-to-Text engine failed."
    )

    response = client.post(
        "/api/v1/voice/parse",
        files={
            "audio": (
                "voice.wav",
                b"fake audio",
                "audio/wav",
            )
        },
    )

    assert_api_error(
        response,
        status_code=503,
        code="SERVICE_UNAVAILABLE",
        message=(
            "Speech-to-Text engine failed."
        ),
    )


# =========================================================
# UNEXPECTED ERROR
# =========================================================

@patch(
    "main.transcribe_and_process_audio"
)
def test_voice_endpoint_unexpected_error(
    mock_process_audio,
):
    mock_process_audio.side_effect = Exception(
        "Unexpected internal error"
    )

    response = client.post(
        "/api/v1/voice/parse",
        files={
            "audio": (
                "voice.wav",
                b"fake audio",
                "audio/wav",
            )
        },
    )

    assert_api_error(
        response,
        status_code=500,
        code="INTERNAL_ERROR",
        message="Voice processing failed.",
    )
