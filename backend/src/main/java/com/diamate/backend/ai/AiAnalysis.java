package com.diamate.backend.ai;

/**
 * The patient-history analyses of the AI service (Ayşen, ai-service /api/v1/integration/...). All of them take the
 * same request (FastApiPatientSummaryRequest) and answer a JSON object that the backend passes on unchanged.
 *
 * Anomaly, data quality, drift and prediction describe the patient's own data and the model's behaviour; they are not
 * a diagnosis, a clinical risk or treatment advice (ai-service README).
 */
public enum AiAnalysis {

    /** Statistics, patterns and insights of the period. */
    SUMMARY("/api/v1/integration/patient-summary"),
    /** Glucose values that are unusual compared with the patient's own pattern (needs at least 6 readings). */
    ANOMALY("/api/v1/integration/patient-anomaly"),
    /** Technical quality of the logs: missing values, duplicates, invalid times, long gaps. */
    DATA_QUALITY("/api/v1/integration/patient-data-quality"),
    /** Whether the newer data differs from an older reference period (model monitoring; needs at least 10). */
    DRIFT("/api/v1/integration/patient-drift"),
    /** Experimental XGBoost glucose trend, with probabilities, confidence and explanation. */
    PREDICTION("/api/v1/integration/patient-prediction");

    private final String path;

    AiAnalysis(String path) {
        this.path = path;
    }

    public String path() {
        return path;
    }
}
