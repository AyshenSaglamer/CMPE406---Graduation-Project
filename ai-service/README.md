# DiaMate AI Service

DiaMate AI Service is the artificial intelligence and analytics microservice of the **DiaMate Diabetes Self-Management and Patient Monitoring Automation System**.

It is implemented with **Python and FastAPI** and communicates with the main **Spring Boot backend** through REST APIs.

The service supports natural-language health logging, voice input, patient-history analytics, personalized pattern detection, and experimental machine-learning-based glucose trend classification.

> **Important:** DiaMate is a diabetes self-management support system. It does not provide medical diagnosis, treatment recommendations, or insulin-dosing recommendations.

---

## Features

### Natural Language Processing

The NLP module converts natural-language health logs into structured data.

Supported log categories include:

- Glucose readings
- Insulin logs
- Meals and carbohydrate intake
- Physical activity

Example:

```text
My glucose is 125
```

can be converted into structured information containing:

```text
Intent: LOG_GLUCOSE
Value: 125
Unit: mg/dL
```

The service also supports **multi-intent parsing**, allowing multiple health-related entries to be extracted from one sentence.

---

### Voice Health Logging

DiaMate supports voice-based health logging using **faster-whisper**.

Processing pipeline:

```text
Audio
  ↓
Audio Validation
  ↓
Whisper Speech-to-Text
  ↓
Transcript
  ↓
Multi-Intent NLP
  ↓
Structured Health Log
```

Supported audio formats include:

- WAV
- MP3
- M4A
- WEBM
- OGG

The current Speech-to-Text configuration is optimized for English diabetes self-management vocabulary.

---

### Glucose Analytics

The analytics layer supports descriptive analysis of patient glucose history, including:

- Mean glucose
- Minimum and maximum glucose
- Standard deviation
- Configurable Time in Range
- Daily trends
- Weekly trends
- Monthly trends

Time-in-range boundaries are configurable and are not selected by the AI service as medical recommendations.

---

### Personalized Pattern Detection

DiaMate can analyze patient-specific historical records to identify descriptive patterns such as:

- Recent glucose changes compared with earlier records
- Meal/glucose associations
- Activity/glucose associations

These results describe associations in the logged data and do not establish causation.

---

### Machine Learning

DiaMate includes an experimental **XGBoost classifier** for future glucose trend classification.

Possible classes are:

```text
LOWER
STABLE
HIGHER
```

The model uses features such as:

- Current glucose
- Previous glucose
- Carbohydrate intake
- Activity duration
- Hour of day
- Day of week
- Month
- Weekend indicator

The machine-learning component is designed for experimental pattern classification and self-management support.

It must not be interpreted as a clinical prediction system or insulin-dosing system.

---

## Architecture

The AI service is part of the larger DiaMate architecture:

```text
Flutter / Client
       ↓
     Nginx
       ↓
Spring Boot Backend
       ↓
FastAPI AI Service
       ↓
NLP / Voice / Analytics / ML / Insights
```

Patient data is managed by the backend. The AI service receives the required data through API contracts and transforms it for analytics and machine-learning processing.

---

## AI Processing Architecture

```text
Patient Input
     │
     ├── Text
     │     ↓
     │    NLP
     │
     └── Voice
           ↓
        Whisper
           ↓
        Transcript
           ↓
          NLP

             ↓

      Structured Records
             ↓
       Patient History
             ↓
      Backend Adapter
             ↓
     Feature Engineering
             ↓
     ┌───────┴────────┐
     ↓                ↓
 Analytics         XGBoost
     ↓                ↓
 Pattern Detection    ↓
     └───────┬────────┘
             ↓
       Insight Engine
             ↓
       Patient Summary
```

---

## Technology Stack

The AI service uses:

- Python
- FastAPI
- Uvicorn
- Pydantic
- NumPy
- Pandas
- scikit-learn
- XGBoost
- joblib
- faster-whisper
- pytest
- Docker
- GitHub Actions

---

## API Endpoints

### System

```text
GET /
GET /health
```

### NLP

```text
POST /api/v1/nlp/parse
POST /api/v1/nlp/parse-multiple
```

### Machine Learning

```text
POST /api/v1/ml/predict-trend
POST /api/v1/ml/predict-from-history
```

### Insights

```text
POST /api/v1/insights/summary
```

### Voice

```text
POST /api/v1/voice/parse
```

---

## OpenAPI Documentation

When the AI service is running locally, interactive API documentation is available at:

```text
http://127.0.0.1:8000/docs
```

ReDoc documentation is available at:

```text
http://127.0.0.1:8000/redoc
```

The raw OpenAPI specification is available at:

```text
http://127.0.0.1:8000/openapi.json
```

---

## Local Development

### 1. Open the AI service directory

```bash
cd ai-service
```

### 2. Create a virtual environment

```bash
python3 -m venv venv
```

### 3. Activate the virtual environment

macOS/Linux:

```bash
source venv/bin/activate
```

### 4. Install dependencies

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### 5. Start the API

```bash
uvicorn main:app --reload --port 8000
```

The service will be available at:

```text
http://127.0.0.1:8000
```

---

## Running Tests

Run the complete AI service test suite with:

```bash
python -m pytest -q
```

The automated test suite covers areas including:

- NLP
- Multi-intent parsing
- Input validation
- Analytics
- Feature engineering
- Backend data adaptation
- Event aggregation
- Machine-learning training and prediction
- Patient-history prediction
- Pattern detection
- Insight generation
- Voice processing
- Speech-to-Text integration boundaries
- API error handling
- Request schemas

---

## Docker

The AI service can be built with Docker Compose from the project root:

```bash
docker compose build ai-service
```

Start the AI service with:

```bash
docker compose up -d ai-service
```

Check running services:

```bash
docker compose ps
```

Inside the Docker network, the Spring Boot backend communicates with the AI service using:

```text
http://ai-service:8000
```

For local development outside Docker, the backend defaults to:

```text
http://localhost:8000
```

This behavior is controlled through the:

```text
AI_SERVICE_BASE_URL
```

environment variable.

---

## Docker Health Check

The running AI container can be tested with:

```bash
docker compose exec ai-service \
  python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/health').read().decode())"
```

Expected response:

```json
{
  "status": "healthy"
}
```

---

## Continuous Integration

The project uses **GitHub Actions** for continuous integration.

The AI Service CI workflow automatically:

1. Checks out the repository
2. Creates a clean Ubuntu environment
3. Installs Python
4. Installs AI service dependencies
5. Runs the automated pytest suite

The workflow runs for relevant pushes to the `ai` branch and for relevant pull requests.

Workflow configuration:

```text
.github/workflows/ai-service-ci.yml
```

---

## Machine Learning Model Artifacts

Trained model artifacts are stored separately from the source code.

The project uses `joblib` for model persistence.

Generated `.joblib` model files should not be treated as source code and are excluded from normal Git/Docker source packaging where configured.

The current demo training pipeline uses synthetic data to validate the technical ML pipeline.

Synthetic demo performance must not be interpreted as clinical model performance.

---

## Data and Privacy

DiaMate is designed with healthcare-data privacy in mind.

Development and testing should use:

- Synthetic data
- Anonymized data
- Non-identifying patient IDs

Sensitive patient information should not be committed to source control.

The production architecture should use appropriate authorization, encrypted transport, secure secret management, and backend access controls.

---

## Safety

DiaMate AI is designed as a **self-management support component**.

The AI service:

- Does not diagnose diabetes or other medical conditions
- Does not prescribe treatment
- Does not recommend insulin doses
- Does not replace a healthcare professional
- Does not interpret descriptive correlation as causation
- Treats ML trend classification as experimental support information

---

## Project Context

DiaMate is a Computer Engineering graduation project focused on building an end-to-end diabetes self-management and patient-monitoring automation system.

The complete system combines:

- Mobile/web user interfaces
- Spring Boot backend services
- PostgreSQL data storage
- Secure authentication and authorization
- FastAPI-based AI services
- Analytics
- Machine learning
- Voice logging
- Patient monitoring and sharing functionality

The AI service is one component of the overall DiaMate platform.
