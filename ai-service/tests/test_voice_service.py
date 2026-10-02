from unittest.mock import patch

import pytest

from services.voice_service import (
    process_voice_transcript,
    transcribe_and_process_audio,
)


MOCK_NLP_RESULT = {
    "status": "SUCCESS",
    "input_type": "TEXT",
    "original_text": (
        "My glucose is 145 and "
        "I walked for 30 minutes"
    ),
    "result_count": 2,
    "results": [
        {
            "intent": "LOG_GLUCOSE",
        },
        {
            "intent": "LOG_ACTIVITY",
        },
    ],
}


@patch(
    "services.voice_service.parse_multiple_entries"
)
def test_process_voice_transcript_success(
    mock_parse,
):
    mock_parse.return_value = MOCK_NLP_RESULT

    result = process_voice_transcript(
        "My glucose is 145 and "
        "I walked for 30 minutes"
    )

    assert result["status"] == "SUCCESS"
    assert result["input_type"] == "VOICE"
    assert result["result_count"] == 2

    assert (
        result["transcript"]
        == "My glucose is 145 and "
        "I walked for 30 minutes"
    )

    assert (
        result["results"][0]["intent"]
        == "LOG_GLUCOSE"
    )

    assert (
        result["results"][1]["intent"]
        == "LOG_ACTIVITY"
    )


@patch(
    "services.voice_service.parse_multiple_entries"
)
def test_transcript_is_trimmed(
    mock_parse,
):
    mock_parse.return_value = MOCK_NLP_RESULT

    result = process_voice_transcript(
        "   My glucose is 145   "
    )

    assert (
        result["transcript"]
        == "My glucose is 145"
    )

    mock_parse.assert_called_once_with(
        "My glucose is 145"
    )


def test_empty_transcript_rejected():
    with pytest.raises(
        ValueError,
        match="Transcript cannot be empty",
    ):
        process_voice_transcript("")


def test_whitespace_transcript_rejected():
    with pytest.raises(
        ValueError,
        match="Transcript cannot be empty",
    ):
        process_voice_transcript("   ")


def test_non_string_transcript_rejected():
    with pytest.raises(
        ValueError,
        match="Transcript must be a string",
    ):
        process_voice_transcript(123)


def test_long_transcript_rejected():
    with pytest.raises(
        ValueError,
        match=(
            "Transcript cannot exceed "
            "500 characters"
        ),
    ):
        process_voice_transcript(
            "a" * 501
        )


def test_empty_audio_rejected():
    def fake_transcriber(
        audio_data: bytes,
    ) -> str:
        return "hello"

    with pytest.raises(
        ValueError,
        match="Audio data cannot be empty",
    ):
        transcribe_and_process_audio(
            b"",
            fake_transcriber,
        )


def test_invalid_audio_type_rejected():
    def fake_transcriber(
        audio_data: bytes,
    ) -> str:
        return "hello"

    with pytest.raises(
        ValueError,
        match=(
            "Audio data must be "
            "provided as bytes"
        ),
    ):
        transcribe_and_process_audio(
            "not bytes",
            fake_transcriber,
        )


@patch(
    "services.voice_service.parse_multiple_entries"
)
def test_audio_is_transcribed_then_parsed(
    mock_parse,
):
    mock_parse.return_value = MOCK_NLP_RESULT

    def fake_transcriber(
        audio_data: bytes,
    ) -> str:
        assert audio_data == b"fake audio"
        return (
            "My glucose is 145 and "
            "I walked for 30 minutes"
        )

    result = transcribe_and_process_audio(
        b"fake audio",
        fake_transcriber,
    )

    assert result["input_type"] == "VOICE"
    assert result["result_count"] == 2

    mock_parse.assert_called_once_with(
        "My glucose is 145 and "
        "I walked for 30 minutes"
    )


def test_invalid_transcriber_result_rejected():
    def fake_transcriber(
        audio_data: bytes,
    ):
        return None

    with pytest.raises(
        ValueError,
        match=(
            "Speech-to-Text must "
            "return a string"
        ),
    ):
        transcribe_and_process_audio(
            b"fake audio",
            fake_transcriber,
        )
