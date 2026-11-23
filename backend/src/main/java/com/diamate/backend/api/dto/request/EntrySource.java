package com.diamate.backend.api.dto.request;

/**
 * How the patient entered a log, as sent by the app. Only these two are accepted from clients;
 * METER, CGM, PUMP, IMPORT, ... are set by device and import integrations, never by a request.
 * Missing (null) means MANUAL.
 */
public enum EntrySource {
    MANUAL,
    // The patient confirmed values that the AI assistant (POST /api/v1/ai/parse) extracted from text or voice.
    AI_ASSISTANT
}
