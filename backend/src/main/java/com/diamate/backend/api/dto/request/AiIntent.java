package com.diamate.backend.api.dto.request;

/**
 * The kinds of entry the AI assistant (POST /api/v1/ai/parse, "intent") recognises and the backend can save.
 * UNKNOWN is never sent back: the assistant leaves out what it did not understand.
 */
public enum AiIntent {
    LOG_GLUCOSE,
    LOG_INSULIN,
    LOG_MEAL,
    LOG_ACTIVITY
}
