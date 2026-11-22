import os

from faster_whisper import WhisperModel


model_size = os.getenv("WHISPER_MODEL_SIZE", "base")

print(f"Downloading Whisper model: {model_size}")

WhisperModel(
    model_size,
    device="cpu",
    compute_type="int8",
)

print(f"Whisper model '{model_size}' is ready.")
