package com.diamate.backend.service;

import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import com.diamate.backend.api.dto.response.AlertResponse;
import com.diamate.backend.api.dto.response.CareTeamAlertResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.Alert;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.AlertRepository;
import com.diamate.backend.repository.PatientAccessRepository;
import com.diamate.backend.repository.PatientAccessRepository.CareTeamPatientRow;

/**
 * Alerts of one patient (created by GlucoseAlertService when a reading is out of range).
 * Who: the patient, or a clinician / caregiver whose ACTIVE relationship grants can_receive_alerts
 * (HealthDataAccess, 404 otherwise). The same people may also acknowledge and resolve an alert.
 *
 * Status flow: OPEN -> ACKNOWLEDGED -> RESOLVED (or OPEN -> RESOLVED). DISMISSED is set only by the backend,
 * when the reading behind the alert is deleted or corrected.
 *
 * Not @Transactional: the access check writes its audit row in its own transaction (see HealthDataAccess), and a
 * refused attempt must stay in the audit log. Each repository call has its own transaction.
 */
@Service
public class AlertService {

    private static final String NOT_FOUND = "Alert not found";

    private final AlertRepository repository;
    private final HealthDataAccess access;
    private final PatientAccessRepository patientAccessRepository;
    private final AuditService auditService;
    private final Clock clock;

    public AlertService(AlertRepository repository, HealthDataAccess access,
            PatientAccessRepository patientAccessRepository, AuditService auditService, Clock clock) {
        this.repository = repository;
        this.access = access;
        this.patientAccessRepository = patientAccessRepository;
        this.auditService = auditService;
        this.clock = clock;
    }

    /**
     * Newest first; status is optional. Unlike the log lists there is no default 14-day window: alerts are few,
     * and an OPEN alert must stay visible until someone handles it (the overview counts all OPEN alerts too).
     */
    public PageResponse<AlertResponse> list(long viewerId, long patientId, AlertStatus status, Instant from,
            Instant to, int page, int size) {
        access.checkCanRead(viewerId, patientId, PatientDataType.ALERTS);
        Instant start = from != null ? from : Instant.EPOCH;
        Instant end = to != null ? to : clock.instant().plus(LogRules.FUTURE_TOLERANCE);
        LogRules.Window window = LogRules.window(start, end, page, size, clock);
        Page<Alert> alerts = status == null
                ? repository.findInRange(patientId, window.from(), window.to(), window.pageable())
                : repository.findInRangeWithStatus(patientId, status, window.from(), window.to(), window.pageable());
        return PageResponse.from(alerts, AlertResponse::from);
    }

    public AlertResponse get(long viewerId, long patientId, long alertId) {
        access.checkCanRead(viewerId, patientId, PatientDataType.ALERTS);
        return AlertResponse.from(find(patientId, alertId));
    }

    /**
     * ACKNOWLEDGED or RESOLVED. Asking for the status the alert already has returns it unchanged (a retried request
     * from the app is not an error); going backwards, or handling a DISMISSED alert, is 409.
     *
     * The change itself is one conditional UPDATE (AlertRepository.acknowledgeIfOpen / resolveIfNotClosed), not
     * "read, change in Java, save": two people acknowledging at the same moment cannot overwrite each other (the
     * first one is recorded), and an alert the backend dismissed in between (its reading was deleted) is not reopened
     * as ACKNOWLEDGED. Every change is written to the audit log.
     */
    public AlertResponse changeStatus(long viewerId, long patientId, long alertId, AlertStatus newStatus) {
        if (newStatus != AlertStatus.ACKNOWLEDGED && newStatus != AlertStatus.RESOLVED) {
            throw new InvalidFieldException("status", "Status must be ACKNOWLEDGED or RESOLVED");
        }
        access.checkCanRead(viewerId, patientId, PatientDataType.ALERTS);
        Alert current = find(patientId, alertId);
        AlertStatus before = current.getStatus();
        if (before == newStatus) {
            return AlertResponse.from(current);
        }
        Instant now = clock.instant();
        int changed = newStatus == AlertStatus.ACKNOWLEDGED
                ? repository.acknowledgeIfOpen(alertId, patientId, viewerId, now)
                : repository.resolveIfNotClosed(alertId, patientId, viewerId, now);
        Alert after = find(patientId, alertId);
        if (changed == 0) {
            // Not changeable from its current status, possibly because someone else changed it a moment ago.
            if (after.getStatus() == newStatus) {
                return AlertResponse.from(after);
            }
            // Locale.ROOT: with a Turkish default locale "DISMISSED" would become "dısmıssed".
            throw new ResourceConflictException(
                    "Alert is already " + after.getStatus().name().toLowerCase(Locale.ROOT));
        }
        auditService.alertStatusChanged(viewerId, patientId, alertId, before, newStatus);
        return AlertResponse.from(after);
    }

    /**
     * GET /care-team/alerts: the alerts of every patient who shares alerts with this clinician / caregiver, newest
     * first, in one request (instead of one request per patient). The patients are the ones of GET
     * /care-team/patients with can_receive_alerts: ACTIVE, not expired relationship of an active patient, the same
     * rule as fn_can_access(..., 'alerts'). A read is audited once per patient whose alerts are on the returned page.
     */
    public PageResponse<CareTeamAlertResponse> careTeamAlerts(long memberId, AlertStatus status, int page, int size) {
        Pageable pageable = LogRules.page(page, size);
        Map<Long, CareTeamPatientRow> patients = patientAccessRepository.findActivePatientsOf(memberId).stream()
                .filter(CareTeamPatientRow::canReceiveAlerts)
                .collect(Collectors.toMap(CareTeamPatientRow::patientId, Function.identity(), (a, b) -> a,
                        LinkedHashMap::new));
        if (patients.isEmpty()) {
            return new PageResponse<>(List.of(), page, size, 0, 0); // no IN () query with an empty list
        }
        Page<Alert> alerts = status == null
                ? repository.findForPatients(patients.keySet(), pageable)
                : repository.findForPatientsWithStatus(patients.keySet(), status, pageable);
        alerts.getContent().stream().map(Alert::getPatientId).distinct()
                .forEach(patientId -> auditService.patientDataViewed(memberId, patientId, PatientDataType.ALERTS,
                        true));
        return PageResponse.from(alerts, alert -> CareTeamAlertResponse.from(patients.get(alert.getPatientId()), alert));
    }

    private Alert find(long patientId, long alertId) {
        return repository.findByIdAndPatientId(alertId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }
}
