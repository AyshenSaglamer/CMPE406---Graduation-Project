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
import com.diamate.backend.repository.PatientAccessRepository;

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
        LogRules.requireNotInFuture(request.measurementTime(), "measurementTime", clock);

        if (request.clientUuid() != null) {
            Optional<GlucoseLog> existing = repository.findByPatientIdAndClientUuid(patientId, request.clientUuid());
            if (existing.isPresent()) {
                return CreateResult.existing(GlucoseLogResponse.from(existing.get()));
            }
        }

        GlucoseLog log = new GlucoseLog(patientId, request.clientUuid(),
                LogRules.source(request.source(), GlucoseSource.class), viewerId);
        apply(log, request);
        GlucoseLog saved = LogRules.saveNew(repository, log);
        alertService.checkReading(saved);
        return CreateResult.created(GlucoseLogResponse.from(saved));
    }

    @Transactional(readOnly = true)
    public PageResponse<GlucoseLogResponse> list(long viewerId, long patientId, Instant from, Instant to, int page,
            int size) {
        access.checkCanRead(viewerId, patientId, PatientAccessRepository.PERMISSION_GLUCOSE);
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        return PageResponse.from(repository.findInRange(patientId, window.from(), window.to(), window.pageable()),
                GlucoseLogResponse::from);
    }

    @Transactional(readOnly = true)
    public GlucoseLogResponse get(long viewerId, long patientId, long logId) {
        access.checkCanRead(viewerId, patientId, PatientAccessRepository.PERMISSION_GLUCOSE);
        return GlucoseLogResponse.from(find(patientId, logId));
    }

    @Transactional
    public GlucoseLogResponse update(long viewerId, long patientId, long logId, GlucoseLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        GlucoseLog log = find(patientId, logId);
        LogRules.requireNotInFuture(request.measurementTime(), "measurementTime", clock);
        apply(log, request);
        // Flush now so the new updated_at (set by a database trigger) is read back into the response.
        return GlucoseLogResponse.from(repository.saveAndFlush(log));
    }

    @Transactional
    public void delete(long viewerId, long patientId, long logId) {
        access.checkCanWrite(viewerId, patientId);
        find(patientId, logId).markDeleted(clock.instant()); // soft delete: an UPDATE on commit, the row stays
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
