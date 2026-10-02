import os
import tempfile
from functools import lru_cache

from faster_whisper import WhisperModel


DEFAULT_MODEL_SIZE = "base"

ALLOWED_AUDIO_EXTENSIONS = {
    ".wav",
    ".mp3",
    ".m4a",
    ".webm",
    ".ogg",
}

DIABETES_CONTEXT_PROMPT = (
    "Diabetes self-management health log. "
    "The speaker may mention glucose, blood glucose, blood sugar, "
    "insulin, insulin units, carbohydrates, carbs, meals, medication, "
    "walking, exercise, physical activity, symptoms, and glucose readings "
    "in milligrams per deciliter."
)


@lru_cache(maxsize=1)
def get_whisper_model() -> WhisperModel:
    """
    Load the Whisper model once and reuse it for
    later transcription requests.
    """

    model_size = os.getenv(
        "WHISPER_MODEL_SIZE",
        DEFAULT_MODEL_SIZE,
    )

    return WhisperModel(
        model_size,
        device="cpu",
        compute_type="int8",
    )


def transcribe_audio(
    audio_data: bytes,
    file_extension: str = ".wav",
) -> str:
    """
    Convert audio bytes into English text using
    a Whisper speech-to-text model.

    DiaMate-specific vocabulary is supplied as context
    to improve recognition of diabetes-related terms.
    """

    if not isinstance(audio_data, bytes):
        raise ValueError(
            "Audio data must be provided as bytes."
        )

    if not audio_data:
        raise ValueError(
            "Audio data cannot be empty."
        )

    normalized_extension = (
        file_extension.strip().lower()
    )

    if (
        normalized_extension
        not in ALLOWED_AUDIO_EXTENSIONS
    ):
        raise ValueError(
            "Unsupported audio file extension."
        )

    temporary_path = None

    try:
        # Whisper works with an audio file path,
        # so uploaded bytes are stored temporarily.
        with tempfile.NamedTemporaryFile(
            suffix=normalized_extension,
            delete=False,
        ) as temporary_file:
            temporary_file.write(audio_data)
            temporary_path = temporary_file.name

        model = get_whisper_model()

        segments, _ = model.transcribe(
            temporary_path,
            beam_size=5,

            # DiaMate currently expects English
            # voice commands.
            language="en",

            # Give Whisper diabetes-related context.
            initial_prompt=DIABETES_CONTEXT_PROMPT,

            # Reduce the chance of carrying incorrect
            # text context between audio segments.
            condition_on_previous_text=False,
        )

        transcript_parts = []

        for segment in segments:
            text = segment.text.strip()

            if text:
                transcript_parts.append(text)

        transcript = " ".join(
            transcript_parts
        ).strip()

        if not transcript:
            raise ValueError(
                "No speech could be detected "
                "in the audio."
            )

        return transcript

    finally:
        # Do not permanently store uploaded voice data.
        if (
            temporary_path
            and os.path.exists(temporary_path)
        ):
            os.remove(temporary_path)
