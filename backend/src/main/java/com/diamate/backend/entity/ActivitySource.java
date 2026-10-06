package com.diamate.backend.entity;

/** activity_logs.source. Must match the CHECK constraint (note: no AI_ASSISTANT here, unlike the other log tables). */
public enum ActivitySource {
    MANUAL,
    WEARABLE,
    IMPORT
}
