package com.diamate.backend.service;

import java.util.Optional;

import org.springframework.stereotype.Service;

import com.diamate.backend.entity.Alert;
import com.diamate.backend.entity.AlertSeverity;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.entity.AlertType;
import com.diamate.backend.entity.GlucoseLog;
import com.diamate.backend.repository.AlertRepository;

/**
 * Creates an alert when a new glucose reading is outside the patient's own thresholds (patient_profiles).
 * The database decides the type (fn_glucose_alert_type); the backend decides severity and text and saves it.
 * Sending a push notification is not part of this yet.
 */
@Service
public class GlucoseAlertService {

    private final AlertRepository alertRepository;

    public GlucoseAlertService(AlertRepository alertRepository) {
        this.alertRepository = alertRepository;
    }

    /** Called for a new reading, and again when the value of a reading is corrected (after dismissOpenAlerts). */
    public Optional<Alert> checkReading(GlucoseLog log) {
        return alertRepository.classifyGlucose(log.getPatientId(), log.getGlucoseValue())
                .map(AlertType::valueOf)
                .map(type -> alertRepository.save(new Alert(log.getPatientId(), type, severityOf(type), log.getId(),
                        log.getGlucoseValue(), messageOf(type, log.getGlucoseValue()))));
    }

    /**
     * The reading was deleted or its value corrected: an alert that nobody has handled yet (OPEN) would otherwise
     * keep warning the care team about a value that does not exist. It becomes DISMISSED (kept as history).
     * ACKNOWLEDGED / RESOLVED alerts are not touched: someone already acted on them.
     */
    public void dismissOpenAlerts(GlucoseLog log) {
        alertRepository.changeStatusOfReadingAlerts(log.getId(), AlertStatus.OPEN, AlertStatus.DISMISSED);
    }

    static AlertSeverity severityOf(AlertType type) {
        return switch (type) {
            case URGENT_LOW, URGENT_HIGH -> AlertSeverity.CRITICAL;
            default -> AlertSeverity.WARNING;
        };
    }

    static String messageOf(AlertType type, int valueMgdl) {
        String label = switch (type) {
            case URGENT_LOW -> "Urgent low glucose";
            case LOW -> "Low glucose";
            case HIGH -> "High glucose";
            case URGENT_HIGH -> "Urgent high glucose";
            default -> "Glucose alert";
        };
        return label + ": " + valueMgdl + " mg/dL";
    }
}
