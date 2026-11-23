from pathlib import Path


ALLOWED_AUDIO_EXTENSIONS = {
    ".wav",
    ".mp3",
    ".m4a",
    ".webm",
    ".ogg",
}

ALLOWED_AUDIO_CONTENT_TYPES = {
    "audio/wav",
    "audio/x-wav",
    "audio/mpeg",
    "audio/mp4",
    "audio/x-m4a",
    "audio/webm",
    "audio/ogg",
    "video/webm",
}

MAX_AUDIO_SIZE_BYTES = 10 * 1024 * 1024


def validate_audio_upload(
    *,
    filename: str,
    content_type: str,
    audio_data: bytes,
) -> None:
    """
    Validate an uploaded audio file before it is sent
    to the Speech-to-Text component.
    """

    if not filename:
        raise ValueError(
            "Audio filename is required."
        )

    extension = Path(
        filename
    ).suffix.lower()

    if extension not in ALLOWED_AUDIO_EXTENSIONS:
        raise ValueError(
            "Unsupported audio file extension."
        )

    if (
        content_type
        not in ALLOWED_AUDIO_CONTENT_TYPES
    ):
        raise ValueError(
            "Unsupported audio content type."
        )

    if not audio_data:
        raise ValueError(
            "Audio file cannot be empty."
        )

    if len(audio_data) > MAX_AUDIO_SIZE_BYTES:
        raise ValueError(
            "Audio file cannot exceed 10 MB."
        )
