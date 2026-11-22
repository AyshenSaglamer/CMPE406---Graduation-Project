from typing import Callable, Dict

from services.nlp_service import parse_multiple_entries


def process_voice_transcript(transcript: str) -> Dict:
    """
    Process an already-transcribed voice command through
    DiaMate's existing NLP pipeline.
    """

    if not isinstance(transcript, str):
        raise ValueError("Transcript must be a string.")

    cleaned_transcript = transcript.strip()

    if not cleaned_transcript:
        raise ValueError("Transcript cannot be empty.")

    if len(cleaned_transcript) > 500:
        raise ValueError(
            "Transcript cannot exceed 500 characters."
        )

    nlp_result = parse_multiple_entries(
        cleaned_transcript
    )

    return {
        "status": nlp_result["status"],
        "input_type": "VOICE",
        "transcript": cleaned_transcript,
        "result_count": nlp_result[
            "result_count"
        ],
        "results": nlp_result["results"],
    }


def transcribe_and_process_audio(
    audio_data: bytes,
    transcriber: Callable[[bytes], str],
) -> Dict:
    """
    Convert audio to text using a supplied Speech-to-Text
    function and then process the transcript with NLP.
    """

    if not isinstance(audio_data, bytes):
        raise ValueError(
            "Audio data must be provided as bytes."
        )

    if not audio_data:
        raise ValueError(
            "Audio data cannot be empty."
        )

    transcript = transcriber(audio_data)

    if not isinstance(transcript, str):
        raise ValueError(
            "Speech-to-Text must return a string."
        )

    result = process_voice_transcript(
        transcript
    )

    return result
