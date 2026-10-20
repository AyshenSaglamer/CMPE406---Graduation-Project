package com.diamate.backend.service;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.GlucoseLog;
import com.diamate.backend.entity.GlucoseSource;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.GlucoseLogRepository;

/**
 * Glucose logs of one patient. The same pattern is used for insulin, meal and activity logs:
 * access check first (HealthDataAccess), then the rules, then the repository.
 */
@Service
public class GlucoseLogService {

    private static final String NOT_FOUND = "Glucose log not found";

    private final GlucoseLogRepository repository;
    private final HealthDataAccess access;
    private final GlucoseAlertService alertService;
    private final Clock clock;

    public GlucoseLogService(GlucoseLogRepository repository, HealthDataAccess access, GlucoseAlertService alertService,
            Clock clock) {
        this.repository = repository;
        this.access = access;
        this.alertService = alertService;
        this.clock = clock;
    }

    @Transactional
    public CreateResult<GlucoseLogResponse> create(long viewerId, long patientId, GlucoseLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        LogRules.requireLogTime(request.measurementTime(), "measurementTime", clock);

        Optional<GlucoseLog> existing = LogRules.existing(repository, patientId, request.clientUuid());
        if (existing.isPresent()) {
            return CreateResult.existing(GlucoseLogResponse.from(existing.get()));
        }

        GlucoseLog log = new GlucoseLog(patientId, request.clientUuid(),
                LogRules.source(request.source(), GlucoseSource.class), viewerId);
        apply(log, request);
        GlucoseLog saved = LogRules.saveNew(repository, log);
        alertService.checkReading(saved);
        return CreateResult.created(GlucoseLogResponse.from(saved));
    }

    // Not @Transactional: the access check may write an audit row in its own transaction (see HealthDataAccess);
    // the repository query has its own read-only transaction.
    public PageResponse<GlucoseLogResponse> list(long viewerId, long patientId, Instant from, Instant to, int page,
            int size) {
        access.checkCanRead(viewerId, patientId, PatientDataType.GLUCOSE_LOGS);
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        return PageResponse.from(repository.findInRange(patientId, window.from(), window.to(), window.pageable()),
                GlucoseLogResponse::from);
    }

    // Not @Transactional, like list().
    public GlucoseLogResponse get(long viewerId, long patientId, long logId) {
        access.checkCanRead(viewerId, patientId, PatientDataType.GLUCOSE_LOGS);
        return GlucoseLogResponse.from(find(patientId, logId));
    }

    @Transactional
    public GlucoseLogResponse update(long viewerId, long patientId, long logId, GlucoseLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        GlucoseLog log = find(patientId, logId);
        LogRules.requireLogTime(request.measurementTime(), "measurementTime", clock);
        int previousValue = log.getGlucoseValue();
        apply(log, request);
        // Flush now so the new updated_at (set by a database trigger) is read back into the response.
        GlucoseLog saved = repository.saveAndFlush(log);
        // A corrected value (e.g. 48 typed instead of 148): the old alert no longer applies, the new value is checked.
        if (saved.getGlucoseValue() != previousValue) {
            alertService.dismissOpenAlerts(saved);
            alertService.checkReading(saved);
        }
        return GlucoseLogResponse.from(saved);
    }

    @Transactional
    public void delete(long viewerId, long patientId, long logId) {
        access.checkCanWrite(viewerId, patientId);
        GlucoseLog log = find(patientId, logId);
        log.markDeleted(clock.instant()); // soft delete: an UPDATE on commit, the row stays
        alertService.dismissOpenAlerts(log);
    }

    private GlucoseLog find(long patientId, long logId) {
        return repository.findByIdAndPatientId(logId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    private static void apply(GlucoseLog log, GlucoseLogRequest request) {
        log.update(request.glucoseValue(), request.measurementTime(), request.mealContext(),
                LogRules.text(request.notes()));
    }
}
