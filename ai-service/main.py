import os

from fastapi import (
    FastAPI,
    File,
    HTTPException,
    UploadFile,
)

from models.schemas import (
    AnomalyDetectionRequest,
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

from services.anomaly_service import (
    analyze_patient_glucose_anomaly,
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
# OPENAPI TAGS
# ============================================================

OPENAPI_TAGS = [
    {
        "name": "System",
        "description": (
            "Service status and health-check endpoints."
        ),
    },
    {
        "name": "NLP",
        "description": (
            "Natural-language processing endpoints for "
            "converting patient-entered health text into "
            "structured DiaMate log data."
        ),
    },
    {
        "name": "Machine Learning",
        "description": (
            "Experimental machine-learning endpoints for "
            "classifying future glucose trend patterns. "
            "These endpoints do not provide diagnosis, "
            "treatment, or insulin-dosing recommendations."
        ),
    },
    {
        "name": "Insights",
        "description": (
            "Patient-history analytics, personalized "
            "pattern detection, statistical anomaly "
            "detection, and descriptive insight generation."
        ),
    },
    {
        "name": "Voice",
        "description": (
            "Speech-to-Text and NLP processing for "
            "voice-based health logging."
        ),
    },
]


# ============================================================
# FASTAPI APPLICATION
# ============================================================

app = FastAPI(
    title="DiaMate AI Service",
    description=(
        "AI microservice for the DiaMate diabetes "
        "self-management support system.\n\n"
        "The service provides natural-language health "
        "logging, voice input processing, patient-history "
        "analytics, personalized pattern detection, "
        "personalized statistical anomaly detection, and "
        "experimental XGBoost-based glucose trend "
        "classification.\n\n"
        "**Safety:** DiaMate is a self-management support "
        "tool. The AI service does not diagnose medical "
        "conditions, prescribe treatment, or recommend "
        "insulin doses."
    ),
    version="1.0.0",
    openapi_tags=OPENAPI_TAGS,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)


# ============================================================
# GLOBAL EXCEPTION HANDLERS
# ============================================================

register_exception_handlers(app)


# ============================================================
# BASIC ENDPOINTS
# ============================================================


@app.get(
    "/",
    tags=["System"],
    summary="Get AI service information",
    description=(
        "Returns basic information confirming that the "
        "DiaMate AI service is running."
    ),
)
def root():
    return {
        "service": "DiaMate AI Service",
        "status": "running",
    }


@app.get(
    "/health",
    tags=["System"],
    summary="Check AI service health",
    description=(
        "Lightweight health-check endpoint for deployment, "
        "Docker, and service monitoring."
    ),
)
def health():
    return {
        "status": "healthy",
    }


# ============================================================
# NLP ENDPOINTS
# ============================================================


@app.post(
    "/api/v1/nlp/parse",
    tags=["NLP"],
    summary="Parse a single health-log entry",
    description=(
        "Converts one natural-language patient health log "
        "into structured data. Supported log categories "
        "include glucose, insulin, meals/carbohydrates, "
        "and physical activity."
    ),
)
def parse_text(
    request: ParseRequest,
):
    return parse_nlp_text(
        request.text
    )


@app.post(
    "/api/v1/nlp/parse-multiple",
    tags=["NLP"],
    summary="Parse multiple health-log entries",
    description=(
        "Extracts multiple supported health-log intents "
        "from a single natural-language input. This allows "
        "a patient to describe several actions or readings "
        "in one sentence."
    ),
)
def parse_multiple(
    request: ParseRequest,
):
    return parse_multiple_entries(
        request.text
    )


# ============================================================
# MACHINE LEARNING ENDPOINTS
# ============================================================


@app.post(
    "/api/v1/ml/predict-trend",
    tags=["Machine Learning"],
    summary="Classify an experimental future glucose trend",
    description=(
        "Uses the saved XGBoost model and supplied feature "
        "values to classify the next glucose trend as "
        "LOWER, STABLE, or HIGHER. This output is "
        "experimental and is not a diagnosis, treatment "
        "recommendation, or insulin-dosing recommendation."
    ),
)
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
    "/api/v1/ml/predict-from-history",
    tags=["Machine Learning"],
    summary="Classify a trend from patient history",
    description=(
        "Builds patient-specific model features from "
        "sequential historical records and applies the "
        "saved XGBoost model to classify the next glucose "
        "trend. Patient histories must not contain records "
        "from multiple patients."
    ),
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


@app.post(
    "/api/v1/insights/summary",
    tags=["Insights"],
    summary="Generate a patient insight summary",
    description=(
        "Generates a descriptive summary from one "
        "patient's historical records. The response can "
        "include glucose statistics, configured "
        "time-in-range analysis, personalized patterns, "
        "descriptive associations, and experimental ML "
        "trend information when available. Associations "
        "do not establish causation."
    ),
)
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
# PERSONALIZED ANOMALY DETECTION
# ============================================================


@app.post(
    "/api/v1/insights/anomaly",
    tags=["Insights"],
    summary="Detect a personalized glucose anomaly",
    description=(
        "Compares the latest glucose reading with the "
        "same patient's previous logged glucose values. "
        "The earlier records form a personalized "
        "statistical baseline, while the latest record "
        "is evaluated using a configurable z-score "
        "threshold. This endpoint identifies statistical "
        "unusualness only and does not provide diagnosis, "
        "clinical risk classification, treatment, or "
        "medication advice."
    ),
)
def patient_glucose_anomaly(
    request: AnomalyDetectionRequest,
):
    try:
        records = [
            record.model_dump()
            for record in request.records
        ]

        return analyze_patient_glucose_anomaly(
            records=records,
            z_threshold=request.z_threshold,
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
                "Personalized glucose anomaly "
                "detection failed."
            ),
        )


# ============================================================
# VOICE ENDPOINT
# ============================================================


@app.post(
    "/api/v1/voice/parse",
    tags=["Voice"],
    summary="Process a voice health log",
    description=(
        "Accepts a supported audio file, validates the "
        "upload, converts speech to text with Whisper, "
        "and sends the resulting transcript through the "
        "existing multi-intent NLP pipeline. The current "
        "Speech-to-Text configuration is optimized for "
        "English diabetes self-management vocabulary."
    ),
)
async def parse_voice(
    audio: UploadFile = File(
        ...,
        description=(
            "Audio health-log file. Supported formats "
            "include WAV, MP3, M4A, WEBM, and OGG."
        ),
    ),
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
