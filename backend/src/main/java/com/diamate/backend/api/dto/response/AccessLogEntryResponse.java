package com.diamate.backend.api.dto.response;

import java.time.Instant;
import java.util.Map;

/**
 * One line of a patient's access log: who (other than the patient) did what with their data, and when.
 * action: VIEW_PATIENT_DATA (dataType says what was read; success false = refused, e.g. no permission),
 * ALERT_STATUS_CHANGED, CARE_ACCEPTED, CARE_DECLINED, CARE_REVOKED ... dataType: GLUCOSE_LOGS, MEAL_LOGS, ALERTS ...
 * for a read, otherwise the kind of thing changed (ALERT, CARE_RELATIONSHIP). The actor's IP address and browser are
 * not shown to the patient.
 */
public record AccessLogEntryResponse(Instant at, Long actorId, String actorFirstName, String actorLastName,
        String actorRole, String action, String dataType, String entityId, boolean success,
        Map<String, Object> details) {
}
