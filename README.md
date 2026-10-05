# DiaMate

## Diabetes Self-Management and Patient Monitoring Automation System

**DiaMate** is an end-to-end diabetes self-management and patient-monitoring platform developed as a Computer Engineering graduation project.

The system is designed for **patients with Type 1 or Type 2 diabetes, caregivers, and clinicians**. It brings daily diabetes-management activities into one platform, including glucose monitoring, insulin and medication tracking, meal and carbohydrate logging, physical-activity recording, reminders, analytics, reporting, and AI-assisted interaction.

DiaMate combines a **Flutter mobile/web client**, **Spring Boot backend**, **PostgreSQL database**, and a separate **FastAPI AI microservice**.

> **Medical Disclaimer:** DiaMate is a self-management support and educational software system. It is not intended to diagnose medical conditions, prescribe treatment, replace healthcare professionals, or recommend insulin doses.

---

## 🎯 Project Goals

DiaMate aims to make daily diabetes record-keeping easier and more accessible while providing patients and authorized caregivers or clinicians with meaningful historical information.

The project focuses on:

- Low-friction daily health logging
- Glucose history and trend visualization
- Insulin and medication tracking
- Meal and carbohydrate tracking
- Physical-activity tracking
- Medication reminders and adherence support
- Hypo/hyper alert workflows
- Patient-history analytics
- Clinician/caregiver data sharing
- PDF/CSV reporting
- Role-based access control
- Secure handling of health-related information
- Accessibility for elderly and less technical users
- AI-assisted text and voice logging
- Experimental patient-history machine learning

---

## ✨ Key Features

### 🩸 Glucose Tracking

Patients can record glucose measurements and review historical information through daily, weekly, and monthly analytics.

The platform supports configurable glucose ranges and descriptive statistics such as averages, minimum/maximum readings, standard deviation, and Time in Range.

### 💉 Insulin & Medication

DiaMate supports medication and insulin logging together with medication scheduling, reminders, and missed-dose workflows.

### 🍽️ Meal & Carbohydrate Tracking

Patients can record meals and carbohydrate intake so that nutritional context can be viewed together with glucose history.

### 🏃 Physical Activity

Physical-activity records can be stored and analyzed alongside glucose data.

### 🔔 Reminders & Alerts

The project includes reminder and notification workflows for medication adherence and glucose-related follow-up.

Alert functionality is intended as a support mechanism rather than a diagnostic system.

### 📊 Analytics & Trends

Historical records can be transformed into:

- Daily trends
- Weekly trends
- Monthly trends
- Summary statistics
- Time in Range
- Meal/glucose associations
- Activity/glucose associations
- Personalized historical patterns

### 👨‍⚕️ Patient, Caregiver & Clinician Roles

DiaMate is designed around three primary roles:

```text
PATIENT
CLINICIAN
CAREGIVER
```

Role-based access control is used so that users only access functionality and information appropriate to their role.

### 📄 Reporting & Sharing

The project scope includes secure sharing of relevant patient information with authorized clinicians/caregivers together with PDF/CSV reporting.

### ♿ Accessibility

The application is designed with accessibility in mind, including low-friction navigation and support for elderly users.

Voice-based logging is also intended to reduce the effort required for frequent health-data entry.

---

# 🏗️ System Architecture

DiaMate uses a modular architecture with separate client, backend, database, and AI responsibilities.

```text
                   +----------------------+
                   |   Flutter Client     |
                   |   Mobile / Web       |
                   +----------+-----------+
                              |
                              | REST / JSON
                              v
                   +----------------------+
                   | Spring Boot Backend  |
                   | API / Security       |
                   +----+-------------+---+
                        |             |
                        |             | REST / JSON
                        v             v
              +---------------+   +--------------------+
              |  PostgreSQL   |   | FastAPI AI Service |
              |   Database    |   +---------+----------+
              +---------------+             |
                                            |
                              +-------------+-------------+
                              |             |             |
                              v             v             v
                             NLP        Analytics          ML
                              |             |             |
                              |             |        XGBoost / SHAP
                              +-------------+-------------+
                                            |
                                            v
                                   Structured AI Results
```

The separation allows the Java backend and Python AI functionality to evolve independently while communicating through REST APIs.

---

# 🤖 AI & Machine Learning

The DiaMate AI layer is implemented as a separate **FastAPI microservice**.

## Natural Language Processing

Users can enter health information using natural language.

Example:

```text
My glucose is 125, I ate 45 grams of carbs and walked for 30 minutes.
```

Supported logging intents include:

```text
LOG_GLUCOSE
LOG_INSULIN
LOG_MEAL
LOG_ACTIVITY
```

Both single-intent and multi-intent parsing are supported.

## 🎙️ Voice Logging

DiaMate uses **faster-whisper** for Speech-to-Text.

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
DiaMate NLP
    |
    v
Structured Health Data
```

Whisper converts speech into text; the DiaMate NLP layer interprets the resulting text.

## Patient Analytics

The AI/analytics layer supports:

- Glucose statistics
- Time in Range
- Daily/weekly/monthly trends
- Meal/glucose correlation
- Activity/glucose correlation
- Personalized pattern detection
- Patient summary generation

Correlations are treated as associations and do not establish medical causation.

## Personalized Baseline Learning

DiaMate can construct descriptive historical baselines from an individual patient's records.

These baselines represent the patient's historical behavior and are **not medical target ranges**.

## Personalized Anomaly Detection

The latest glucose observation can be compared with patient-specific historical behavior.

When sufficient contextual history exists, a time-of-day baseline can be used. Otherwise, the system falls back to the patient's overall historical baseline.

Statistical anomalies are not treated as medical diagnoses.

## Data Quality Analysis

Patient-history data can be analyzed for issues such as:

- Missing values
- Duplicate records
- Invalid timestamps
- Large logging gaps

Engineering data-quality thresholds are kept separate from clinical thresholds.

---

# 🧠 XGBoost Trend Classification

DiaMate contains an experimental XGBoost pipeline that classifies the expected direction of the next glucose trend as:

```text
LOWER
STABLE
HIGHER
```

Model features include:

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

Patient histories are processed independently to avoid cross-patient feature leakage.

A temporal train/test strategy uses earlier patient records for training and later records for evaluation.

Development can use synthetic data. Performance on synthetic data must not be interpreted as clinical performance.

---

## Confidence & Uncertainty

ML responses can include the class-probability distribution together with descriptive confidence and uncertainty.

These values describe **model-output certainty**, not clinical probability or medical risk.

---

## Explainable AI

DiaMate supports:

- **Global feature importance** to show which inputs the XGBoost model generally relies on.
- **Local SHAP explanations** to describe feature contributions to an individual prediction.

SHAP explains model behavior; it does not prove medical causation.

---

## Model-Input Drift Monitoring

The AI service can compare a historical reference window with a more recent patient-data window to identify changes in model-input distributions.

The current implementation uses standardized mean shifts and reports:

```text
DRIFT_DETECTED
```

or:

```text
NO_DRIFT_DETECTED
```

Drift is an engineering monitoring signal. It does not indicate clinical deterioration or prove that a prediction is incorrect.

For detailed AI documentation, see:

```text
ai-service/README.md
```

---

# 🔐 Security & Privacy

DiaMate handles health-related information, making security and privacy core design requirements.

The project architecture includes or plans for:

- JWT-based authentication
- Role-Based Access Control
- Password hashing
- Input validation
- Authorization checks
- Secure REST APIs
- HTTPS/TLS deployment
- Environment-based secret configuration
- Safe API error handling
- Audit trails
- Synthetic/anonymized development data
- Protection of sensitive data
- OWASP Secure Coding principles

Secrets should never be committed directly to the repository.

---

# 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| Mobile / Web | Flutter / Dart |
| Backend | Spring Boot / Java |
| Database | PostgreSQL |
| AI API | FastAPI / Python |
| Validation | Pydantic |
| Analytics | NumPy / Pandas |
| Machine Learning | XGBoost / scikit-learn |
| Explainability | SHAP |
| Speech-to-Text | faster-whisper |
| Authentication | JWT / Spring Security |
| Containers | Docker / Docker Compose |
| Testing | pytest / backend tests |
| CI | GitHub Actions |
| API Style | REST / JSON |

---

# 📁 Repository Structure

A simplified repository layout is:

```text
DiaMate/
│
├── README.md
├── docker-compose.yml
│
├── backend/
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
│
├── ai-service/
│   ├── main.py
│   ├── README.md
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── models/
│   ├── services/
│   ├── analytics/
│   ├── data/
│   ├── ml/
│   ├── scripts/
│   └── tests/
│
└── frontend/
    └── Flutter application
```

The exact structure can evolve as the project is integrated.

---

# 🔌 AI API Overview

The FastAPI service currently exposes AI functionality through endpoints including:

### System

```text
GET  /
GET  /health
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
POST /api/v1/ml/drift
```

### Insights

```text
POST /api/v1/insights/summary
POST /api/v1/insights/anomaly
POST /api/v1/insights/baseline
POST /api/v1/insights/data-quality
```

### Voice

```text
POST /api/v1/voice/parse
```

FastAPI interactive documentation is available locally at:

```text
http://127.0.0.1:8000/docs
```

---

# 🚀 Running the Project

## Docker Compose

The project is designed to run as a containerized multi-service application.

From the repository root:

```bash
docker compose up -d --build
```

The containerized architecture can coordinate:

```text
Nginx
  |
  v
Spring Boot Backend
  |
  +------> PostgreSQL
  |
  +------> FastAPI AI Service
```

Inside Docker Compose, the Spring Boot backend can communicate with the AI service using:

```text
http://ai-service:8000
```

rather than `localhost`.

---

## Running the AI Service Separately

```bash
cd ai-service
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

---

# 🧪 Testing

The project uses multiple testing levels.

### Unit Testing

Individual modules and functions are tested independently.

### Integration Testing

Interactions between components and APIs are tested together.

### Regression Testing

Existing test suites are rerun after changes to ensure previously working behavior has not been broken.

### End-to-End Testing

The project architecture supports testing across the service chain:

```text
Client
  |
  v
Nginx / API
  |
  v
Spring Boot
  |
  +------> PostgreSQL
  |
  v
FastAPI
  |
  v
AI / Analytics
```

Run the complete AI test suite with:

```bash
cd ai-service
source venv/bin/activate
python -m pytest -v
```

---

# 🔄 Continuous Integration

The AI service uses **GitHub Actions** to automatically install dependencies and run automated tests when relevant changes are pushed or submitted through pull requests.

```text
Push / Pull Request
        |
        v
GitHub Actions
        |
        v
Install Dependencies
        |
        v
Run Automated Tests
```

This helps identify regressions before integration.

---

# 👥 Target Users

DiaMate is designed for:

### Patients

- Record daily health information
- Monitor glucose history
- Track meals, medication, and activity
- Receive reminders
- Review trends and summaries
- Use text or voice for easier data entry

### Caregivers

- Access authorized patient information
- Support monitoring and follow-up

### Clinicians

- Review authorized patient histories
- Examine reports and trends
- Support patient follow-up using recorded information

---

# 📊 Project Status

DiaMate is under active graduation-project development.

Major AI-service functionality currently includes:

- NLP and multi-intent parsing
- Voice / Whisper processing
- Glucose analytics
- Trend and correlation analytics
- Patient-aware data processing
- Personalized pattern detection
- Personalized baseline learning
- Personalized anomaly detection
- Data-quality analysis
- XGBoost trend classification
- Confidence and uncertainty reporting
- Global feature importance
- Local SHAP explanations
- Model-input drift monitoring
- Patient summaries
- Standardized API errors
- Automated AI tests
- Docker support
- Continuous Integration

Final product completion also depends on integration across the backend, Flutter client, database, reporting, reminders, sharing, offline/synchronization, and other team-owned components.

---

# 🔭 Planned / Team-Level Work

Project-level work can include:

- Final backend/frontend integration
- Medication reminder workflows
- Clinician/caregiver sharing
- PDF/CSV export
- Offline-first synchronization
- Final accessibility polish
- Production deployment configuration
- End-to-end testing
- Final project documentation and demonstration
- Integration with the team's separate Food Vision component
- Nutrition-data integration with user confirmation/editing of estimates

---

# 🧑‍💻 Development Approach

DiaMate follows an iterative software-development approach with modular components and version control.

The project separates major responsibilities across:

```text
Frontend
Backend
Database
Security
AI / Analytics
Testing
Deployment
Documentation
```

This modular structure makes individual components easier to test, maintain, integrate, and extend.

---

# ⚠️ AI & Medical Safety

DiaMate deliberately separates engineering/statistical outputs from clinical conclusions.

| System Output | Intended Meaning | Not Intended As |
|---|---|---|
| Glucose analytics | Historical data summary | Diagnosis |
| Correlation | Statistical association | Medical causation |
| ML trend | Experimental classification | Treatment advice |
| Confidence | Model-output certainty | Clinical probability |
| SHAP | Model feature contribution | Medical causation |
| Anomaly | Statistical unusualness | Hypo/hyper diagnosis |
| Baseline | Historical patient behavior | Medical target |
| Drift | Input-distribution change | Clinical deterioration |

DiaMate does not make insulin-dosing decisions.

---

# 📚 Graduation Project

**Project:** Diabetes Self-Management and Patient Monitoring Automation System  
**Product Name:** DiaMate  
**Department:** Computer Engineering  
**Project Type:** Software Graduation Project

DiaMate demonstrates the integration of modern software-engineering technologies into a modular health-support platform:

```text
Flutter
   +
Spring Boot
   +
PostgreSQL
   +
FastAPI
   +
NLP
   +
Whisper
   +
Analytics
   +
XGBoost
   +
SHAP
   +
Docker
   +
Automated Testing
   +
Continuous Integration
```

The overall objective is to provide a usable and extensible diabetes self-management support platform while maintaining clear boundaries between software-generated insights and professional medical decision-making.

---

# 📄 Disclaimer

DiaMate is an academic software project intended for diabetes self-management support and educational purposes.

It is **not a medical device** and does not provide medical diagnosis, treatment decisions, medication prescriptions, or insulin-dosing recommendations.
