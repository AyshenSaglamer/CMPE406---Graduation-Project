from fastapi import FastAPI, HTTPException, status

from ml.prediction import predict_with_saved_model
from models.schemas import (
    ParseRequest,
    TrendPredictionRequest,
)
from services.nlp_service import (
    parse_multiple_entries,
    parse_nlp_text,
)


app = FastAPI(
    title="DiaMate AI Service",
    description=(
        "AI, NLP, analytics, and experimental "
        "machine-learning service for the DiaMate "
        "diabetes self-management system"
    ),
    version="1.0.0",
)


@app.get("/")
def root():
    return {
        "service": "DiaMate AI Service",
        "status": "running",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
    }


@app.post("/api/v1/nlp/parse")
def parse_text(
    request: ParseRequest,
):
    return parse_nlp_text(
        request.text
    )


@app.post("/api/v1/nlp/parse-multiple")
def parse_multiple_text(
    request: ParseRequest,
):
    return parse_multiple_entries(
        request.text
    )


@app.post("/api/v1/ml/predict-trend")
def predict_trend(
    request: TrendPredictionRequest,
):
    """
    Predict an experimental glucose trend class.

    The ML component is intended for pattern analysis
    and software demonstration. It does not provide
    diagnosis, insulin dosing, or treatment advice.
    """

    try:
        result = predict_with_saved_model(
            request.model_dump()
        )

        return result

    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Glucose trend model is not "
                "currently available."
            ),
        ) from exc

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=(
                "Glucose trend prediction failed."
            ),
        ) from exc
