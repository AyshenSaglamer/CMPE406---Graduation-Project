package com.diamate.backend.entity;

/** glucose_logs.source. Clients may only send MANUAL or AI_ASSISTANT (see EntrySource); the rest come from devices and imports. */
public enum GlucoseSource {
    MANUAL,
    METER,
    CGM,
    CSV_IMPORT,
    AI_ASSISTANT,
    WEARABLE
}
