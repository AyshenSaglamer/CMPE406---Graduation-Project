package com.diamate.backend.api.dto.response;

import java.math.BigDecimal;
import java.time.Instant;

import com.diamate.backend.entity.Alert;
import com.diamate.backend.entity.AlertSeverity;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.entity.AlertType;

// One alert of a patient. valueMgdl is the glucose value that triggered it; glucoseLogId is null once that reading
// is gone from the database (the alert is kept as history). acknowledgedBy is the first person who handled it,
// resolvedBy the one who resolved it (null for alerts resolved before V7).
public record AlertResponse(long id, long patientId, AlertType alertType, AlertSeverity severity, Long glucoseLogId,
        BigDecimal valueMgdl, String message, AlertStatus status, Instant triggeredAt, Long acknowledgedBy,
        Instant acknowledgedAt, Instant resolvedAt, Long resolvedBy) {

    public static AlertResponse from(Alert alert) {
        return new AlertResponse(alert.getId(), alert.getPatientId(), alert.getAlertType(), alert.getSeverity(),
                alert.getGlucoseLogId(), alert.getValueMgdl(), alert.getMessage(), alert.getStatus(),
                alert.getTriggeredAt(), alert.getAcknowledgedBy(), alert.getAcknowledgedAt(), alert.getResolvedAt(),
                alert.getResolvedBy());
    }
}
