package com.diamate.backend.entity;

/** alerts.alert_type. Must match the CHECK constraint; the backend creates only the four glucose types for now. */
public enum AlertType {
    URGENT_LOW,
    LOW,
    HIGH,
    URGENT_HIGH,
    RAPID_RISE,
    RAPID_FALL,
    MISSED_DOSE,
    NO_DATA,
    PREDICTIVE_LOW
}
