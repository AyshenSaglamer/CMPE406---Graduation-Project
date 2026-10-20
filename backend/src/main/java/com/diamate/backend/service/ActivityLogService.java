package com.diamate.backend.service;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.ActivityLogRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.ActivityLog;
import com.diamate.backend.entity.ActivitySource;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.ActivityLogRepository;

/** Activity logs of one patient (same pattern as GlucoseLogService). Shared with the care team under "activity". */
@Service
public class ActivityLogService {

    private static final String NOT_FOUND = "Activity log not found";

    private final ActivityLogRepository repository;
    private final HealthDataAccess access;
    private final Clock clock;

    public ActivityLogService(ActivityLogRepository repository, HealthDataAccess access, Clock clock) {
        this.repository = repository;
        this.access = access;
        this.clock = clock;
    }

    @Transactional
    public CreateResult<ActivityLogResponse> create(long viewerId, long patientId, ActivityLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        LogRules.requireLogTime(request.startedAt(), "startedAt", clock);

        Optional<ActivityLog> existing = LogRules.existing(repository, patientId, request.clientUuid());
        if (existing.isPresent()) {
            return CreateResult.existing(ActivityLogResponse.from(existing.get()));
        }

        ActivityLog log = new ActivityLog(patientId, request.clientUuid(),
                LogRules.source(request.source(), ActivitySource.class));
        apply(log, request);
        return CreateResult.created(ActivityLogResponse.from(LogRules.saveNew(repository, log)));
    }

    // Not @Transactional: the access check may write an audit row in its own transaction (see HealthDataAccess);
    // the repository query has its own read-only transaction.
    public PageResponse<ActivityLogResponse> list(long viewerId, long patientId, Instant from, Instant to, int page,
            int size) {
        access.checkCanRead(viewerId, patientId, PatientDataType.ACTIVITY_LOGS);
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        return PageResponse.from(repository.findInRange(patientId, window.from(), window.to(), window.pageable()),
                ActivityLogResponse::from);
    }

    // Not @Transactional, like list().
    public ActivityLogResponse get(long viewerId, long patientId, long logId) {
        access.checkCanRead(viewerId, patientId, PatientDataType.ACTIVITY_LOGS);
        return ActivityLogResponse.from(find(patientId, logId));
    }

    @Transactional
    public ActivityLogResponse update(long viewerId, long patientId, long logId, ActivityLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        ActivityLog log = find(patientId, logId);
        LogRules.requireLogTime(request.startedAt(), "startedAt", clock);
        apply(log, request);
        return ActivityLogResponse.from(repository.saveAndFlush(log));
    }

    @Transactional
    public void delete(long viewerId, long patientId, long logId) {
        access.checkCanWrite(viewerId, patientId);
        find(patientId, logId).markDeleted(clock.instant());
    }

    private ActivityLog find(long patientId, long logId) {
        return repository.findByIdAndPatientId(logId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    private static void apply(ActivityLog log, ActivityLogRequest request) {
        Short heartRate = request.avgHeartRate() == null ? null : request.avgHeartRate().shortValue();
        log.update(request.activityType().trim(), request.startedAt(), request.durationMinutes(), request.steps(),
                heartRate, request.caloriesKcal(), request.intensity(), LogRules.text(request.notes()));
    }
}
