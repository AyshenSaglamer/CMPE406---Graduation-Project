package com.diamate.backend.api.dto.request;

/**
 * How the patient entered a meal, as sent by the app: EntrySource plus AI_PHOTO, which only a meal can have. A separate
 * type, so "AI_PHOTO" on a glucose, insulin or activity log is refused (400) like any unknown value. IMPORT is set by
 * imports, never by a request. Missing (null) means MANUAL.
 */
public enum MealEntrySource {
    MANUAL,
    // The patient confirmed values that the AI assistant (POST /api/v1/ai/parse or /ai/voice) understood.
    AI_ASSISTANT,
    // The patient confirmed (or corrected) a food recognised from a photo (POST /api/v1/ai/food).
    AI_PHOTO
}
