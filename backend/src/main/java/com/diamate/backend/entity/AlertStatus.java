package com.diamate.backend.entity;

/** alerts.status. Must match the CHECK constraint. */
public enum AlertStatus {
    OPEN,
    ACKNOWLEDGED,
    RESOLVED,
    DISMISSED
}
