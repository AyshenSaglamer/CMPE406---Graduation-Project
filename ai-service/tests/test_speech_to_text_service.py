import os
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from services.speech_to_text_service import (
    DIABETES_CONTEXT_PROMPT,
    get_whisper_model,
    transcribe_audio,
)


# =========================================================
# INPUT VALIDATION
# =========================================================

def test_non_bytes_audio_rejected():
    with pytest.raises(
        ValueError,
        match="Audio data must be provided as bytes",
    ):
        transcribe_audio(
            "not-bytes",
            ".wav",
        )


def test_empty_audio_rejected():
    with pytest.raises(
        ValueError,
        match="Audio data cannot be empty",
    ):
        transcribe_audio(
            b"",
            ".wav",
        )


@pytest.mark.parametrize(
    "extension",
    [
        ".exe",
        ".txt",
        ".pdf",
        ".jpg",
    ],
)
def test_unsupported_extension_rejected(
    extension,
):
    with pytest.raises(
        ValueError,
        match="Unsupported audio file extension",
    ):
        transcribe_audio(
            b"fake audio",
            extension,
        )


def test_extension_is_normalized():
    fake_model = MagicMock()

    fake_model.transcribe.return_value = (
        [
            SimpleNamespace(
                text="Hello",
            )
        ],
        None,
    )

    with patch(
        "services.speech_to_text_service."
        "get_whisper_model",
        return_value=fake_model,
    ):
        result = transcribe_audio(
            b"fake audio",
            "  .WAV  ",
        )

    assert result == "Hello"


# =========================================================
# TRANSCRIPTION
# =========================================================

def test_transcribe_audio_success():
    fake_model = MagicMock()

    fake_model.transcribe.return_value = (
        [
            SimpleNamespace(
                text=" My glucose is 145. ",
            ),
            SimpleNamespace(
                text=" I walked for 30 minutes. ",
            ),
        ],
        None,
    )

    with patch(
        "services.speech_to_text_service."
        "get_whisper_model",
        return_value=fake_model,
    ):
        result = transcribe_audio(
            b"fake audio data",
            ".wav",
        )

    assert result == (
        "My glucose is 145. "
        "I walked for 30 minutes."
    )


def test_empty_segments_are_ignored():
    fake_model = MagicMock()

    fake_model.transcribe.return_value = (
        [
            SimpleNamespace(text=""),
            SimpleNamespace(text="   "),
            SimpleNamespace(
                text="Glucose is 120",
            ),
        ],
        None,
    )

    with patch(
        "services.speech_to_text_service."
        "get_whisper_model",
        return_value=fake_model,
    ):
        result = transcribe_audio(
            b"fake audio",
            ".wav",
        )

    assert result == "Glucose is 120"


def test_no_detected_speech_rejected():
    fake_model = MagicMock()

    fake_model.transcribe.return_value = (
        [
            SimpleNamespace(text="   "),
            SimpleNamespace(text=""),
        ],
        None,
    )

    with patch(
        "services.speech_to_text_service."
        "get_whisper_model",
        return_value=fake_model,
    ):
        with pytest.raises(
            ValueError,
            match=(
                "No speech could be detected "
                "in the audio"
            ),
        ):
            transcribe_audio(
                b"fake audio",
                ".wav",
            )


# =========================================================
# WHISPER CONFIGURATION
# =========================================================

def test_whisper_called_with_diamate_settings():
    fake_model = MagicMock()

    fake_model.transcribe.return_value = (
        [
            SimpleNamespace(
                text="My glucose is 145",
            )
        ],
        None,
    )

    with patch(
        "services.speech_to_text_service."
        "get_whisper_model",
        return_value=fake_model,
    ):
        transcribe_audio(
            b"fake audio",
            ".wav",
        )

    fake_model.transcribe.assert_called_once()

    _, kwargs = (
        fake_model.transcribe.call_args
    )

    assert kwargs["beam_size"] == 5
    assert kwargs["language"] == "en"

    assert (
        kwargs["initial_prompt"]
        == DIABETES_CONTEXT_PROMPT
    )

    assert (
        kwargs["condition_on_previous_text"]
        is False
    )


# =========================================================
# TEMPORARY FILE CLEANUP
# =========================================================

def test_temporary_file_removed_after_success():
    fake_model = MagicMock()

    fake_model.transcribe.return_value = (
        [
            SimpleNamespace(
                text="Glucose is 120",
            )
        ],
        None,
    )

    captured_path = None

    with patch(
        "services.speech_to_text_service."
        "get_whisper_model",
        return_value=fake_model,
    ):
        result = transcribe_audio(
            b"fake audio",
            ".wav",
        )

        captured_path = (
            fake_model
            .transcribe
            .call_args
            .args[0]
        )

    assert result == "Glucose is 120"

    assert not os.path.exists(
        captured_path
    )


def test_temporary_file_removed_after_error():
    fake_model = MagicMock()

    fake_model.transcribe.side_effect = (
        RuntimeError(
            "Whisper failed"
        )
    )

    captured_path = None

    with patch(
        "services.speech_to_text_service."
        "get_whisper_model",
        return_value=fake_model,
    ):
        with pytest.raises(
            RuntimeError,
            match="Whisper failed",
        ):
            try:
                transcribe_audio(
                    b"fake audio",
                    ".wav",
                )
            finally:
                if (
                    fake_model
                    .transcribe
                    .call_args
                    is not None
                ):
                    captured_path = (
                        fake_model
                        .transcribe
                        .call_args
                        .args[0]
                    )

    assert captured_path is not None

    assert not os.path.exists(
        captured_path
    )


# =========================================================
# MODEL LOADING AND CACHE
# =========================================================

def test_whisper_model_configuration():
    get_whisper_model.cache_clear()

    fake_whisper_model = MagicMock()

    with patch(
        "services.speech_to_text_service."
        "WhisperModel",
        return_value=fake_whisper_model,
    ) as mock_model:
        with patch.dict(
            os.environ,
            {
                "WHISPER_MODEL_SIZE": "tiny",
            },
        ):
            model = get_whisper_model()

    assert model is fake_whisper_model

    mock_model.assert_called_once_with(
        "tiny",
        device="cpu",
        compute_type="int8",
    )

    get_whisper_model.cache_clear()


def test_whisper_model_is_cached():
    get_whisper_model.cache_clear()

    fake_whisper_model = MagicMock()

    with patch(
        "services.speech_to_text_service."
        "WhisperModel",
        return_value=fake_whisper_model,
    ) as mock_model:
        first_model = get_whisper_model()
        second_model = get_whisper_model()

    assert first_model is second_model

    assert mock_model.call_count == 1

    get_whisper_model.cache_clear()
