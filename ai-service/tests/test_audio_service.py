import pytest

from services.audio_service import (
    MAX_AUDIO_SIZE_BYTES,
    validate_audio_upload,
)


def test_valid_wav_audio():
    validate_audio_upload(
        filename="voice.wav",
        content_type="audio/wav",
        audio_data=b"fake audio",
    )


def test_valid_mp3_audio():
    validate_audio_upload(
        filename="voice.mp3",
        content_type="audio/mpeg",
        audio_data=b"fake audio",
    )


def test_empty_filename_rejected():
    with pytest.raises(
        ValueError,
        match="Audio filename is required",
    ):
        validate_audio_upload(
            filename="",
            content_type="audio/wav",
            audio_data=b"fake audio",
        )


def test_invalid_extension_rejected():
    with pytest.raises(
        ValueError,
        match="Unsupported audio file extension",
    ):
        validate_audio_upload(
            filename="voice.exe",
            content_type="audio/wav",
            audio_data=b"fake audio",
        )


def test_invalid_content_type_rejected():
    with pytest.raises(
        ValueError,
        match="Unsupported audio content type",
    ):
        validate_audio_upload(
            filename="voice.wav",
            content_type="application/pdf",
            audio_data=b"fake audio",
        )


def test_empty_audio_rejected():
    with pytest.raises(
        ValueError,
        match="Audio file cannot be empty",
    ):
        validate_audio_upload(
            filename="voice.wav",
            content_type="audio/wav",
            audio_data=b"",
        )


def test_large_audio_rejected():
    oversized_audio = (
        b"a" * (MAX_AUDIO_SIZE_BYTES + 1)
    )

    with pytest.raises(
        ValueError,
        match="Audio file cannot exceed 10 MB",
    ):
        validate_audio_upload(
            filename="voice.wav",
            content_type="audio/wav",
            audio_data=oversized_audio,
        )
