# DiaMate AI Service

## Diabetes Self-Management and Patient Monitoring Automation System

The **DiaMate AI Service** is the artificial intelligence and analytics component of the DiaMate graduation project.

DiaMate is designed to support diabetes self-management by allowing users to record and analyze information such as:

- Blood glucose
- Meals and carbohydrate intake
- Insulin and medication
- Physical activity
- Patient history

The AI service is implemented as a separate **FastAPI microservice** and communicates with the main **Spring Boot backend** through REST APIs.

> **Important:** DiaMate is a support and educational system. It is not intended to diagnose medical conditions, prescribe treatment, or recommend insulin doses.

---

# 1. AI Service Overview

The AI service provides:

- Natural Language Processing (NLP)
- Single-intent health log parsing
- Multi-intent health log parsing
- Voice input processing
- Speech-to-Text using Whisper
- Glucose analytics
- Time in Range calculations
- Trend analysis
- Meal-glucose correlation analysis
- Activity-glucose correlation analysis
- Patient-specific feature engineering
- Event aggregation
- Personalized pattern detection
- Experimental XGBoost trend prediction
- Patient summary generation
- Human-readable insights
- Input validation
- Standardized API error handling

The service is designed to be **modular**, meaning each major responsibility is implemented in a separate component.

---

# 2. High-Level Architecture

```text
                 DiaMate Application
                         |
                         v
                Spring Boot Backend
                         |
                    REST / JSON
                         |
                         v
               +------------------+
               | FastAPI AI       |
               | Service          |
               +------------------+
                         |
        +----------------+----------------+
        |                |                |
        v                v                v
       NLP           Analytics            ML
        |                |                |
        |                |                v
        |                |             XGBoost
        |                |
        |                v
        |          Pattern Detection
        |
        v
 Structured Health Data
```

For voice input:

```text
Voice
  |
  v
Audio Validation
  |
  v
Whisper Speech-to-Text
  |
  v
Transcript
  |
  v
NLP Parser
  |
  v
Structured Health Data
```

---

# 3. Technology Stack

The AI service uses:

- **Python 3.12**
- **FastAPI**
- **Pydantic**
- **NumPy**
- **Pandas**
- **scikit-learn**
- **XGBoost**
- **joblib**
- **faster-whisper**
- **pytest**
- **Docker**
- **GitHub Actions**

The main backend is implemented using:

- Spring Boot
- PostgreSQL
- REST APIs

---

# 4. FastAPI

FastAPI is used to expose the AI functionality through REST API endpoints.

An endpoint represents a specific operation that another component can request from the AI service.

For example:

```text
POST /api/v1/nlp/parse
```

allows another component to send text to the NLP system.

Example request:

```json
{
  "text": "My glucose is 125"
}
```

The NLP service analyzes the text and converts it into structured information.

---

# 5. Natural Language Processing

The NLP component allows users to enter diabetes-related information using natural language.

For example:

```text
My glucose is 125
```

can be interpreted as a glucose logging request.

The NLP system identifies the user's **intent** and extracts relevant values.

Supported intents include:

```text
LOG_GLUCOSE
LOG_INSULIN
LOG_MEAL
LOG_ACTIVITY
```

Examples:

```text
My glucose is 125
```

```text
I took 5 units of insulin
```

```text
I ate 40 grams of carbs
```

```text
I walked for 30 minutes
```

The NLP implementation uses deterministic parsing rules and pattern matching.

This provides predictable and testable behavior for the supported health logging commands.

---

# 6. Multi-Intent NLP

DiaMate also supports multiple health records inside one sentence.

Example:

```text
My glucose is 125, I ate 45 grams of carbs and walked for 30 minutes
```

The system can identify multiple intents from the same input.

Conceptually:

```text
Input
  |
  +--> LOG_GLUCOSE
  |
  +--> LOG_MEAL
  |
  +--> LOG_ACTIVITY
```

The multi-intent functionality is exposed separately so that the original single-intent functionality remains available.

---

# 7. Input Validation with Pydantic

Pydantic schemas are used to define and validate the expected structure of incoming API data.

For example, the NLP request requires a valid text field.

Validation can reject inputs such as:

- Missing text
- Empty text
- Whitespace-only text
- Excessively long text
- Invalid timestamps
- Invalid numeric values
- Invalid glucose range configurations

Validation occurs at the API boundary before invalid data reaches the analytics or machine-learning components.

---

# 8. Glucose Analytics

The analytics module calculates useful statistics from glucose history.

Examples include:

- Number of readings
- Mean glucose
- Minimum glucose
- Maximum glucose
- Standard deviation
- Time in Range

Example concept:

```text
Glucose history
      |
      v
Analytics
      |
      +--> Mean
      +--> Minimum
      +--> Maximum
      +--> Standard deviation
      +--> Time in Range
```

Target glucose ranges are configurable rather than being permanently hard-coded as medical recommendations.

---

# 9. Time in Range

Time in Range measures the percentage of glucose readings that fall inside a configured target range.

Conceptually:

```text
Readings inside configured range
-------------------------------- × 100
Total glucose readings
```

The default engineering configuration may use a range such as 70–180 mg/dL, but patient-specific target values can be supplied to the service.

DiaMate does not independently prescribe a patient's medical target range.

---

# 10. Trend Analytics

Trend analytics groups and analyzes glucose readings over time.

Supported time-based analysis includes:

- Daily trends
- Weekly trends
- Monthly trends

This helps transform individual glucose readings into more meaningful historical information.

---

# 11. Correlation Analytics

DiaMate can analyze associations between variables such as:

```text
Meal / carbohydrate intake
            ↕
         Glucose
```

and:

```text
Physical activity
        ↕
     Glucose
```

Pearson correlation can be used to measure these relationships.

Correlation is treated only as an **association**.

> Correlation does not imply causation.

The system therefore does not claim that one recorded variable medically caused another.

---

# 12. Backend Data Adapter

The backend adapter converts patient records into a consistent format that can be used by the analytics and machine-learning components.

Expected information includes:

```text
patient_id
timestamp
glucose_mg_dl
carbs_g
activity_minutes
```

The adapter performs operations such as:

- Data validation
- Timestamp conversion
- Numeric validation
- Sorting records by patient and time
- Preparing patient-specific histories

This creates a clear data contract between the backend and AI service.

---

# 13. Patient-Aware Processing

Patient histories must remain separate.

For example:

```text
Patient A
100 → 110 → 120
```

and:

```text
Patient B
150 → 140 → 130
```

must not accidentally become:

```text
100 → 110 → 120 → 150 → 140 → 130
```

Patient-aware processing ensures that historical features are calculated separately for each patient.

This helps prevent incorrect feature generation and data leakage between patients.

---

# 14. Feature Engineering

Feature engineering converts raw patient records into useful variables that a machine-learning model can process.

Examples include:

```text
glucose_mg_dl
previous_glucose
carbs_g
activity_minutes
hour_of_day
day_of_week
month
is_weekend
```

For example:

```text
timestamp
   |
   +--> hour_of_day
   +--> day_of_week
   +--> month
   +--> is_weekend
```

The model therefore receives structured numerical features rather than raw timestamps or unprocessed records.

---

# 15. Event Aggregation

Patient information may arrive as separate events.

Example:

```text
08:00  Glucose = 120
08:30  Meal = 40 g carbs
09:00  Activity = 20 min
10:00  Glucose = 135
```

Event aggregation combines these separate records into structured information that can be used for analysis.

Conceptually:

```text
Previous glucose = 120
Carbs            = 40 g
Activity         = 20 min
Current glucose  = 135
```

This helps prepare independently recorded events for analytics and machine-learning processing.

Future events are not allowed to leak backward into earlier records.

---

# 16. Machine Learning

DiaMate contains an experimental machine-learning pipeline based on **XGBoost**.

The model performs glucose trend classification.

The target classes are:

```text
LOWER
STABLE
HIGHER
```

The purpose is to classify the expected direction of the next glucose trend based on structured historical features.

The model is **not** used to:

- Diagnose diabetes
- Recommend medication
- Calculate insulin doses
- Replace healthcare professionals

---

# 17. Why XGBoost?

XGBoost is a tree-based machine-learning algorithm.

A decision tree can be understood as a sequence of questions used to reach a result.

Conceptually:

```text
Is glucose high?
       |
   +---+---+
  Yes      No
   |        |
Were carbs  ...
high?
```

XGBoost combines many decision trees.

This is called an **ensemble** approach.

XGBoost was selected because DiaMate uses structured tabular features such as:

- Glucose
- Previous glucose
- Carbohydrates
- Activity
- Time-based variables

Tree-based boosting models are suitable for learning nonlinear relationships between these kinds of variables.

---

# 18. Model Training

Training means allowing the model to learn patterns from example data.

Conceptually:

```text
Patient Data
     |
     v
Feature Engineering
     |
     v
Training Data
     |
     v
XGBoost
     |
     v
Trained Model
```

The project uses a temporal train/test strategy.

Earlier patient records are used for training and later records are used for testing.

This better represents the idea of using historical information to evaluate future trend classification.

---

# 19. Train/Test Split

The dataset is divided into two main parts:

```text
Dataset
   |
   +--> Training Data
   |
   +--> Test Data
```

Training data is used by the model to learn.

Test data is used to evaluate the model on data that was not used for training.

The test data must not be used to teach the model.

Otherwise, data leakage could produce misleading evaluation results.

---

# 20. Synthetic Data

Synthetic patient data can be used during development.

Synthetic data is artificially generated data that resembles the structure of real patient records.

It is useful for:

- Software development
- Pipeline testing
- Demonstrating machine-learning functionality
- Avoiding unnecessary exposure of real patient information

Synthetic-data performance must not be interpreted as clinical performance.

Clinical deployment would require appropriately collected real-world data, external validation, clinical evaluation, and relevant regulatory processes.

---

# 21. Model Persistence

After training, machine-learning models can be saved using **joblib**.

Conceptually:

```text
Train model
    |
    v
Save model
    |
    v
.joblib file
    |
    v
Load later for prediction
```

This prevents the system from needing to retrain the model every time a prediction is requested.

Model artifacts are excluded from the normal Docker image because the current development model is based on synthetic/demo data and should not be confused with a production clinical model.

---

# 22. Prediction

The AI service provides endpoints that can request predictions from the machine-learning pipeline.

A prediction flow can be represented as:

```text
Patient History
      |
      v
Validation
      |
      v
Feature Engineering
      |
      v
XGBoost Model
      |
      v
LOWER / STABLE / HIGHER
```

The prediction represents an experimental glucose trend classification rather than a medical recommendation.

---

# 23. Personalized Pattern Detection

The pattern detection component analyzes an individual patient's historical records.

It looks for patterns such as:

- Recent glucose behavior compared with earlier records
- Associations between meals and glucose
- Associations between activity and glucose

The important point is that the analysis is based on the **individual patient's own history**.

The system describes observed patterns without claiming medical causation.

---

# 24. Insight Generation

Raw numerical results can be difficult for users to understand.

The insight service converts analytical results into human-readable descriptions.

Conceptually:

```text
Analytics / ML Results
          |
          v
    Insight Service
          |
          v
Human-readable explanation
```

The explanations remain descriptive and avoid diagnosis or treatment recommendations.

---

# 25. Patient Summary

The patient summary functionality combines multiple components.

Conceptually:

```text
Patient History
      |
      +--> Glucose Analytics
      |
      +--> Time in Range
      |
      +--> Pattern Detection
      |
      +--> ML Trend Classification
      |
      v
Patient Summary
```

This acts as an orchestrator that runs multiple analysis components and combines their results.

---

# 26. Voice Input

DiaMate supports voice-based health logging.

The voice pipeline is:

```text
Audio
  |
  v
Audio Validation
  |
  v
Whisper
  |
  v
Transcript
  |
  v
Existing NLP Parser
  |
  v
Structured Health Data
```

For example, a user could say:

```text
My glucose is 125 and I walked for 30 minutes
```

Whisper converts the audio into text.

The existing NLP system then interprets the transcript.

This design avoids duplicating the NLP logic.

---

# 27. Whisper Speech-to-Text

The voice system uses **faster-whisper**.

Whisper is responsible for Speech-to-Text.

It does not determine the health intent itself.

The responsibilities are separated:

```text
Whisper
   |
   | Speech → Text
   v
Transcript
   |
   | Text → Meaning
   v
DiaMate NLP
```

In simple terms:

> Whisper is the ear; the DiaMate NLP component interprets the resulting text.

---

# 28. Audio Validation

Before speech recognition begins, uploaded audio is validated.

Validation includes:

- Supported file extensions
- Supported MIME types
- Empty files
- File size limits

Supported formats include common formats such as:

```text
.wav
.mp3
.m4a
.webm
.ogg
```

Temporary files used during transcription are removed after processing.

---

# 29. API Error Handling

The AI service uses a standardized error response structure.

Conceptually:

```json
{
  "status": "ERROR",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input."
  }
}
```

This makes errors easier for clients to process consistently.

A global exception handler converts common errors into the standard format.

Unexpected internal exceptions return generic messages so that unnecessary internal implementation details are not exposed to clients.

---

# 30. API Endpoints

The AI service includes the following main endpoints.

## System

```text
GET /
GET /health
```

These endpoints can be used to verify that the service is running.

---

## NLP

### Single-intent parsing

```text
POST /api/v1/nlp/parse
```

Example request:

```json
{
  "text": "My glucose is 125"
}
```

### Multi-intent parsing

```text
POST /api/v1/nlp/parse-multiple
```

Example input:

```text
My glucose is 125, I ate 45 grams of carbs and walked for 30 minutes
```

---

## Machine Learning

### Direct trend prediction

```text
POST /api/v1/ml/predict-trend
```

### Prediction from patient history

```text
POST /api/v1/ml/predict-from-history
```

The history-based endpoint prepares patient history and uses the latest valid feature row for trend classification.

---

## Insights

### Patient summary

```text
POST /api/v1/insights/summary
```

The summary endpoint can combine:

- Glucose statistics
- Time in Range
- Pattern detection
- Experimental ML trend prediction
- Human-readable insights

---

## Voice

### Voice parsing

```text
POST /api/v1/voice/parse
```

The endpoint accepts an audio file, performs Speech-to-Text, and passes the resulting transcript through the NLP pipeline.

---

# 31. OpenAPI and Swagger Documentation

FastAPI automatically provides interactive API documentation.

When the AI service is running locally:

```text
Swagger UI:
http://127.0.0.1:8000/docs
```

```text
ReDoc:
http://127.0.0.1:8000/redoc
```

```text
OpenAPI JSON:
http://127.0.0.1:8000/openapi.json
```

Swagger UI can be used to inspect endpoints and manually send API requests.

---

# 32. Running the AI Service Locally

Navigate to the AI service:

```bash
cd ~/DiaMate/ai-service
```

Activate the virtual environment:

```bash
source venv/bin/activate
```

Start FastAPI:

```bash
uvicorn main:app --reload --port 8000
```

The service should then be available at:

```text
http://127.0.0.1:8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

---

# 33. Running Tests

Activate the virtual environment:

```bash
cd ~/DiaMate/ai-service
source venv/bin/activate
```

Run the complete AI test suite:

```bash
python -m pytest -v
```

The test suite covers areas including:

- NLP
- Multi-intent parsing
- API behavior
- Input validation
- Glucose analytics
- Trend analytics
- Correlation analytics
- Feature engineering
- Backend adaptation
- Event aggregation
- ML target generation
- Model training
- Prediction
- Patient-history prediction
- Pattern detection
- Insight generation
- Patient summaries
- Voice processing
- Audio validation
- Speech-to-Text integration logic
- Error handling

External dependencies such as the real Whisper model can be mocked during automated tests where appropriate.

---

# 34. Testing Strategy

The project uses several levels of testing.

## Unit Tests

Test individual functions or modules independently.

Example:

```text
glucose analytics
NLP parser
feature engineering
```

## Integration Tests

Test multiple components working together.

Example:

```text
API
 ↓
NLP service
 ↓
Response
```

## Regression Tests

The complete test suite is run after changes to check that previously working functionality has not been broken.

## End-to-End Integration

The project has also been tested across the containerized service path:

```text
HTTPS Request
     |
     v
Nginx
     |
     v
Spring Boot
     |
     v
FastAPI
     |
     v
NLP
     |
     v
JSON Response
```

---

# 35. Docker

The AI service can run inside a Docker container.

Docker packages the application and its dependencies into a consistent environment.

Build the AI service:

```bash
docker compose build ai-service
```

Start it:

```bash
docker compose up -d ai-service
```

The project can also start the complete Docker Compose environment:

```bash
docker compose up -d --build
```

Docker Compose coordinates services such as:

```text
Nginx
Spring Boot Backend
FastAPI AI Service
PostgreSQL
```

Inside Docker Compose, the Spring Boot backend communicates with the AI service using:

```text
http://ai-service:8000
```

rather than localhost.

---

# 36. Environment Configuration

Environment variables are used to provide configuration without hard-coding environment-specific values into application logic.

Examples include:

```text
AI_SERVICE_BASE_URL
JWT_SECRET
WHISPER_MODEL_SIZE
```

This allows local and Docker environments to use different configuration values without changing source code.

Secrets should never be committed directly to the repository.

---

# 37. Continuous Integration

The AI service uses **GitHub Actions** for Continuous Integration (CI).

The workflow is located under:

```text
.github/workflows/
```

When relevant AI-service code is pushed or included in a pull request, CI automatically:

```text
Checkout code
     |
     v
Set up Python
     |
     v
Install dependencies
     |
     v
Run pytest
```

This helps detect regressions before code changes are integrated.

---

# 38. Project Structure

A simplified structure of the AI service is:

```text
ai-service/
│
├── main.py
├── README.md
├── requirements.txt
├── Dockerfile
├── .dockerignore
├── pytest.ini
│
├── models/
│   ├── schemas.py
│   └── error_schemas.py
│
├── services/
│   ├── nlp_service.py
│   ├── insight_service.py
│   ├── summary_service.py
│   ├── pattern_service.py
│   ├── voice_service.py
│   ├── audio_service.py
│   ├── speech_to_text_service.py
│   ├── error_service.py
│   └── exception_handlers.py
│
├── analytics/
│   ├── glucose_analytics.py
│   ├── trend_analytics.py
│   ├── correlation_analytics.py
│   └── feature_engineering.py
│
├── data/
│   ├── backend_adapter.py
│   └── event_aggregation.py
│
├── ml/
│   ├── target_builder.py
│   ├── future_target_builder.py
│   ├── training.py
│   ├── prediction.py
│   ├── history_prediction.py
│   └── models/
│
├── scripts/
│   └── train_demo_model.py
│
└── tests/
```

---

# 39. Separation of Responsibilities

The AI service follows a modular design.

Different modules have different responsibilities:

```text
main.py
→ API endpoints

models/
→ Request/response schemas

services/
→ Application logic

analytics/
→ Statistical analysis

data/
→ Data preparation and aggregation

ml/
→ Machine-learning pipeline

tests/
→ Automated verification
```

This separation makes the system easier to:

- Understand
- Test
- Maintain
- Extend
- Debug

---

# 40. Privacy and Security

DiaMate handles health-related information, so privacy and security are important design considerations.

The project follows principles such as:

- Input validation
- Authentication and authorization at the application level
- Role-based access control
- Secure API communication
- Protection against unnecessary information disclosure
- Avoiding unnecessary storage of temporary data
- Synthetic or anonymized development data
- Environment-based secret configuration
- Secure error handling

Production deployment should use HTTPS and appropriate protection for sensitive data.

---

# 41. AI Safety

DiaMate AI functionality is intended as a **support tool**.

It does not provide:

```text
Diagnosis
Treatment decisions
Medication prescriptions
Insulin dose recommendations
```

Analytics describe patterns found in recorded data.

Machine-learning predictions are experimental classifications.

Food or nutrition estimates, where implemented, should be treated as estimates and confirmed by the user.

The system should not replace qualified healthcare professionals.

---

# 42. Current ML Limitations

The current machine-learning implementation is primarily intended to demonstrate and validate the software architecture and ML pipeline.

Important limitations include:

- Development can use synthetic data.
- Synthetic-data performance does not demonstrate clinical accuracy.
- The model has not undergone clinical validation.
- Predictions must not be interpreted as medical advice.
- Real-world deployment would require appropriate real patient datasets and external evaluation.
- Regulatory and clinical requirements would need to be considered before medical use.

---

# 43. Future Work

Potential future improvements include:

- Validation using appropriate real-world datasets
- Additional CGM data import formats
- Improved multilingual NLP
- More extensive Speech-to-Text evaluation
- Advanced patient-specific analytics
- Food image recognition integration
- Nutrition database integration
- Clinician/caregiver reporting
- Additional accessibility functionality
- More advanced natural-language summaries
- Production monitoring and deployment infrastructure

These extensions should preserve the project's safety principle of providing decision support rather than diagnosis or treatment.

---

# 44. Example Complete AI Flow

A typical text request can follow:

```text
User
 |
 v
Flutter Application
 |
 v
Spring Boot Backend
 |
 v
FastAPI Endpoint
 |
 v
Pydantic Validation
 |
 v
NLP Parsing
 |
 v
Structured Health Data
```

For historical analysis:

```text
Patient History
      |
      v
Backend Adapter / Event Aggregation
      |
      v
Analytics
      |
      v
Feature Engineering
      |
      +-------------------+
      |                   |
      v                   v
Pattern Detection       XGBoost
      |                   |
      +---------+---------+
                |
                v
         Insight Service
                |
                v
          Patient Summary
```

For voice:

```text
User Speech
    |
    v
Audio Validation
    |
    v
Whisper
    |
    v
Transcript
    |
    v
NLP
    |
    v
Structured Result
```

---

# 45. Graduation Project Context

DiaMate was developed as a Computer Engineering graduation project.

The overall project focuses on an end-to-end diabetes self-management and patient-monitoring system.

The AI service contributes functionality including:

- Natural-language health logging
- Voice-based interaction
- Patient-history analytics
- Personalized pattern detection
- Experimental machine-learning trend classification
- Structured API integration

The AI functionality is separated from the main Spring Boot application as a FastAPI microservice.

---

# 46. Summary

The DiaMate AI service combines:

```text
FastAPI
   +
NLP
   +
Whisper Speech-to-Text
   +
Patient Analytics
   +
Event Aggregation
   +
Feature Engineering
   +
Personalized Pattern Detection
   +
XGBoost
   +
Insight Generation
   +
Automated Testing
   +
Docker
   +
Continuous Integration
```

The result is a modular AI service that can communicate with the DiaMate backend through REST APIs while keeping AI-specific Python functionality separated from the main application.

The system is designed as a diabetes self-management support tool and does not make diagnostic, treatment, or insulin-dosing decisions.
