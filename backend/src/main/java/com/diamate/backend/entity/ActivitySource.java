package com.diamate.backend.entity;

/** activity_logs.source. Must match the CHECK constraint (AI_ASSISTANT allowed since migration V6). */
public enum ActivitySource {
    MANUAL,
    WEARABLE,
    IMPORT,
    AI_ASSISTANT
}
