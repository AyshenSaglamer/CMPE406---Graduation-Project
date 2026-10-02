import os

from fastapi import (
    FastAPI,
    File,
    HTTPException,
    UploadFile,
)

from models.schemas import (
    HistoryPredictionRequest,
    ParseRequest,
    PatientSummaryRequest,
    TrendPredictionRequest,
)

from ml.history_prediction import (
    predict_from_patient_history,
)

from ml.prediction import (
    predict_with_saved_model,
)

from services.audio_service import (
    validate_audio_upload,
)

from services.exception_handlers import (
    register_exception_handlers,
)

from services.nlp_service import (
    parse_multiple_entries,
    parse_nlp_text,
)

from services.speech_to_text_service import (
    transcribe_audio,
)

from services.summary_service import (
    build_patient_summary,
)

from services.voice_service import (
    transcribe_and_process_audio,
)


# ============================================================
# FASTAPI APPLICATION
# ============================================================

app = FastAPI(
    title="DiaMate AI Service",
    description=(
        "AI, analytics, NLP, machine learning, "
        "and voice service for the DiaMate "
        "diabetes self-management support system."
    ),
    version="1.0.0",
)


# ============================================================
# GLOBAL EXCEPTION HANDLERS
# ============================================================

register_exception_handlers(app)


# ============================================================
# BASIC ENDPOINTS
# ============================================================


@app.get("/")
def root():
    return {
        "service": "DiaMate AI Service",
        "status": "running",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
    }


# ============================================================
# NLP ENDPOINTS
# ============================================================


@app.post("/api/v1/nlp/parse")
def parse_text(
    request: ParseRequest,
):
    return parse_nlp_text(
        request.text
    )


@app.post("/api/v1/nlp/parse-multiple")
def parse_multiple(
    request: ParseRequest,
):
    return parse_multiple_entries(
        request.text
    )


# ============================================================
# MACHINE LEARNING ENDPOINTS
# ============================================================


@app.post("/api/v1/ml/predict-trend")
def predict_trend(
    request: TrendPredictionRequest,
):
    try:
        return predict_with_saved_model(
            request.model_dump()
        )

    except FileNotFoundError:
        raise HTTPException(
            status_code=503,
            detail=(
                "Glucose trend model is not "
                "currently available."
            ),
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )

    except Exception:
        raise HTTPException(
            status_code=500,
            detail=(
                "Glucose trend prediction "
                "failed."
            ),
        )


@app.post(
    "/api/v1/ml/predict-from-history"
)
def predict_trend_from_history(
    request: HistoryPredictionRequest,
):
    try:
        records = [
            record.model_dump()
            for record in request.records
        ]

        return predict_from_patient_history(
            records
        )

    except FileNotFoundError:
        raise HTTPException(
            status_code=503,
            detail=(
                "Glucose trend model is not "
                "currently available."
            ),
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )

    except Exception:
        raise HTTPException(
            status_code=500,
            detail=(
                "Patient history prediction "
                "failed."
            ),
        )


# ============================================================
# PATIENT INSIGHT SUMMARY
# ============================================================


@app.post("/api/v1/insights/summary")
def patient_insight_summary(
    request: PatientSummaryRequest,
):
    try:
        records = [
            record.model_dump()
            for record in request.records
        ]

        return build_patient_summary(
            records=records,
            range_low=request.range_low,
            range_high=request.range_high,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )

    except Exception:
        raise HTTPException(
            status_code=500,
            detail=(
                "Patient insight summary "
                "generation failed."
            ),
        )


# ============================================================
# VOICE ENDPOINT
# ============================================================


@app.post("/api/v1/voice/parse")
async def parse_voice(
    audio: UploadFile = File(...),
):
    try:
        audio_data = await audio.read()

        filename = (
            audio.filename or ""
        )

        content_type = (
            audio.content_type or ""
        )

        # ----------------------------------------------------
        # Validate uploaded audio
        # ----------------------------------------------------

        validate_audio_upload(
            filename=filename,
            content_type=content_type,
            audio_data=audio_data,
        )

        extension = os.path.splitext(
            filename
        )[1].lower()

        # ----------------------------------------------------
        # Whisper Speech-to-Text adapter
        # ----------------------------------------------------

        def whisper_transcriber(
            data: bytes,
        ) -> str:
            return transcribe_audio(
                data,
                file_extension=extension,
            )

        # ----------------------------------------------------
        # Audio -> Whisper -> Transcript -> NLP
        # ----------------------------------------------------

        return transcribe_and_process_audio(
            audio_data,
            whisper_transcriber,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )

    except FileNotFoundError:
        raise HTTPException(
            status_code=503,
            detail=(
                "Speech-to-Text service is not "
                "currently available."
            ),
        )

    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        )

    except Exception:
        raise HTTPException(
            status_code=500,
            detail=(
                "Voice processing failed."
            ),
        )

    finally:
        await audio.close()
