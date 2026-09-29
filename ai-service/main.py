from fastapi import FastAPI

from models.schemas import ParseRequest
from services.nlp_service import (
    parse_nlp_text,
    parse_multiple_entries,
)


app = FastAPI(
    title="DiaMate AI Service",
    description=(
        "AI and NLP service for the DiaMate "
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


# ---------------------------------------------------------
# Single-entry NLP parsing
# ---------------------------------------------------------

@app.post("/api/v1/nlp/parse")
def parse_text(request: ParseRequest):
    return parse_nlp_text(request.text)


# ---------------------------------------------------------
# Multi-entry NLP parsing
# ---------------------------------------------------------

@app.post("/api/v1/nlp/parse-multiple")
def parse_multiple_text(request: ParseRequest):
    return parse_multiple_entries(request.text)
