package com.diamate.backend.service;

/**
 * The kinds of patient data the API returns, each with the care_relationships permission that shares it
 * (the permission names understood by the database function fn_can_access). The name is also written to the
 * audit log (VIEW_PATIENT_DATA).
 */
public enum PatientDataType {

    OVERVIEW("glucose"), // summary card: last glucose reading and open alerts
    GLUCOSE_LOGS("glucose"),
    INSULIN_LOGS("medications"), // there is no separate insulin flag: insulin is shared as "medications"
    MEAL_LOGS("meals"),
    ACTIVITY_LOGS("activity"),
    ALERTS("alerts"); // care_relationships.can_receive_alerts

    private final String permission;

    PatientDataType(String permission) {
        this.permission = permission;
    }

    public String permission() {
        return permission;
    }
}
