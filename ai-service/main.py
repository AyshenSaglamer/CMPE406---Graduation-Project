import os

from fastapi import (
    FastAPI,
    File,
    HTTPException,
    UploadFile,
)

from models.schemas import (
    AnomalyDetectionRequest,
    DataQualityRequest,
    HistoryPredictionRequest,
    ModelDriftRequest,
    ParseRequest,
    PatientSummaryRequest,
    PersonalizedBaselineRequest,
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

from services.baseline_service import (
    build_personalized_baseline,
)

from services.data_quality_service import (
    build_data_quality_report,
)

from services.drift_service import (
    analyze_model_drift,
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
            "classifying future glucose trend patterns "
            "and monitoring model-input data drift. "
            "These endpoints do not provide diagnosis, "
            "treatment, clinical-risk assessment, or "
            "insulin-dosing recommendations."
        ),
    },
    {
        "name": "Insights",
        "description": (
            "Patient-history analytics, personalized "
            "baseline learning, personalized statistical "
            "anomaly detection, data-quality analysis, "
            "and descriptive insight generation."
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
        "analytics, personalized baseline learning, "
        "personalized statistical anomaly detection, "
        "data-quality analysis, experimental "
        "XGBoost-based glucose trend classification, "
        "explainable AI, prediction confidence and "
        "uncertainty, and model-input drift monitoring."
        "\n\n"
        "**Safety:** DiaMate is a self-management support "
        "tool. The AI service does not diagnose medical "
        "conditions, prescribe treatment, estimate "
        "clinical risk, or recommend insulin doses."
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
# SYSTEM ENDPOINTS
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
# MACHINE LEARNING - DIRECT TREND PREDICTION
# ============================================================


@app.post(
    "/api/v1/ml/predict-trend",
    tags=["Machine Learning"],
    summary="Classify an experimental future glucose trend",
    description=(
        "Uses the saved XGBoost model and supplied feature "
        "values to classify the next glucose trend as "
        "LOWER, STABLE, or HIGHER. The prediction response "
        "can include class probabilities, descriptive "
        "confidence and uncertainty, and explainable-AI "
        "information. These outputs describe model "
        "behaviour and must not be interpreted as "
        "clinical probabilities."
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
                "Glucose trend prediction failed."
            ),
        )


# ============================================================
# MACHINE LEARNING - HISTORY PREDICTION
# ============================================================


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
                "Patient history prediction failed."
            ),
        )


# ============================================================
# MACHINE LEARNING - MODEL DRIFT MONITORING
# ============================================================


@app.post(
    "/api/v1/ml/drift",
    tags=["Machine Learning"],
    summary="Analyze model-input data drift",
    description=(
        "Compares historical reference patient records "
        "with newer patient records to identify "
        "statistical changes in the model-input "
        "distribution. Drift is an engineering "
        "model-monitoring signal only. It does not "
        "represent diagnosis, clinical deterioration, "
        "medical risk, treatment advice, or medication "
        "guidance."
    ),
)
def model_input_drift(
    request: ModelDriftRequest,
):
    try:
        reference_records = [
            record.model_dump()
            for record
            in request.reference_records
        ]

        current_records = [
            record.model_dump()
            for record
            in request.current_records
        ]

        return analyze_model_drift(
            reference_records=reference_records,
            current_records=current_records,
            mean_shift_threshold=(
                request.mean_shift_threshold
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
                "Model-input drift analysis failed."
            ),
        )


# ============================================================
# INSIGHTS - PERSONALIZED BASELINE
# ============================================================


@app.post(
    "/api/v1/insights/baseline",
    tags=["Insights"],
    summary="Learn a personalized glucose baseline",
    description=(
        "Learns descriptive glucose patterns from one "
        "patient's historical records. The response "
        "includes an overall personal baseline, "
        "time-of-day baselines, and weekday/weekend "
        "baselines. These values describe historical "
        "patterns only and are not medical target ranges."
    ),
)
def personalized_baseline(
    request: PersonalizedBaselineRequest,
):
    try:
        records = [
            record.model_dump()
            for record in request.records
        ]

        return build_personalized_baseline(
            records=records,
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
                "Personalized baseline learning failed."
            ),
        )


# ============================================================
# INSIGHTS - PATIENT SUMMARY
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
# INSIGHTS - PERSONALIZED ANOMALY DETECTION
# ============================================================


@app.post(
    "/api/v1/insights/anomaly",
    tags=["Insights"],
    summary="Detect a personalized glucose anomaly",
    description=(
        "Evaluates the latest glucose reading relative to "
        "the patient's own historical statistical pattern. "
        "When sufficient matching time-of-day history is "
        "available, a contextual baseline is used. "
        "Otherwise, the analysis falls back to the overall "
        "historical baseline. Statistical unusualness does "
        "not represent diagnosis, clinical risk, treatment, "
        "or medication advice."
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
# INSIGHTS - DATA QUALITY
# ============================================================


@app.post(
    "/api/v1/insights/data-quality",
    tags=["Insights"],
    summary="Analyze patient-history data quality",
    description=(
        "Analyzes one patient's historical records for "
        "data-quality issues such as missing values, "
        "duplicate records, invalid timestamps, and large "
        "logging gaps. The configurable logging-gap "
        "threshold is an engineering threshold and not a "
        "clinical threshold."
    ),
)
def patient_data_quality(
    request: DataQualityRequest,
):
    try:
        records = [
            record.model_dump()
            for record in request.records
        ]

        return build_data_quality_report(
            records=records,
            large_gap_hours=(
                request.large_gap_hours
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
                "Patient-history data-quality "
                "analysis failed."
            ),
        )


# ============================================================
# VOICE
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
        # VALIDATE AUDIO
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
        # WHISPER TRANSCRIBER ADAPTER
        # ----------------------------------------------------

        def whisper_transcriber(
            data: bytes,
        ) -> str:
            return transcribe_audio(
                data,
                file_extension=extension,
            )

        # ----------------------------------------------------
        # AUDIO -> WHISPER -> TRANSCRIPT -> NLP
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
