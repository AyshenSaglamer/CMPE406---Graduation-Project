from fastapi import (
    FastAPI,
    HTTPException,
)

from models.schemas import (
    HistoryPredictionRequest,
    ParseRequest,
    TrendPredictionRequest,
)

from ml.history_prediction import (
    predict_from_patient_history,
)

from ml.prediction import (
    predict_with_saved_model,
)

from services.nlp_service import (
    parse_multiple_entries,
    parse_nlp_text,
)


app = FastAPI(
    title="DiaMate AI Service",
    description=(
        "AI and NLP service for the DiaMate "
        "diabetes self-management support system."
    ),
    version="1.0.0",
)


# =========================================================
# BASIC ROUTES
# =========================================================

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


# =========================================================
# NLP - SINGLE INTENT
# =========================================================

@app.post("/api/v1/nlp/parse")
def parse_text(
    request: ParseRequest,
):
    return parse_nlp_text(
        request.text
    )


# =========================================================
# NLP - MULTI INTENT
# =========================================================

@app.post("/api/v1/nlp/parse-multiple")
def parse_multiple(
    request: ParseRequest,
):
    """
    Parse multiple supported health-log intents
    from one natural-language input.

    parse_multiple_entries already returns the
    complete API response contract.
    """

    return parse_multiple_entries(
        request.text
    )


# =========================================================
# DIRECT ML PREDICTION
# =========================================================

@app.post("/api/v1/ml/predict-trend")
def predict_trend(
    request: TrendPredictionRequest,
):
    """
    Experimental next-glucose-trend
    classification.

    This endpoint does not provide diagnosis,
    medication dosing, or treatment advice.
    """

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


# =========================================================
# HISTORY-BASED ML PREDICTION
# =========================================================

@app.post(
    "/api/v1/ml/predict-from-history"
)
def predict_trend_from_history(
    request: HistoryPredictionRequest,
):
    """
    Build prediction features automatically from
    sequential patient history and classify the
    direction of the next glucose reading.

    Only supplied historical information is used.

    This endpoint does not provide diagnosis,
    medication dosing, or treatment
    recommendations.
    """

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
