package com.diamate.backend.service;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.MealLogRequest;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.MealLog;
import com.diamate.backend.entity.MealSource;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.InsulinLogRepository;
import com.diamate.backend.repository.MealLogRepository;

/** Meal logs of one patient (same pattern as GlucoseLogService). Shared with the care team under "meals". */
@Service
public class MealLogService {

    private static final String NOT_FOUND = "Meal log not found";

    private final MealLogRepository repository;
    private final InsulinLogRepository insulinLogRepository;
    private final HealthDataAccess access;
    private final Clock clock;

    public MealLogService(MealLogRepository repository, InsulinLogRepository insulinLogRepository,
            HealthDataAccess access, Clock clock) {
        this.repository = repository;
        this.insulinLogRepository = insulinLogRepository;
        this.access = access;
        this.clock = clock;
    }

    @Transactional
    public CreateResult<MealLogResponse> create(long viewerId, long patientId, MealLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        LogRules.requireLogTime(request.eatenAt(), "eatenAt", clock);

        Optional<MealLog> existing = LogRules.existing(repository, patientId, request.clientUuid());
        if (existing.isPresent()) {
            return CreateResult.existing(MealLogResponse.from(existing.get()));
        }

        MealLog log = new MealLog(patientId, request.clientUuid(), LogRules.source(request.source(), MealSource.class));
        apply(log, request);
        return CreateResult.created(MealLogResponse.from(LogRules.saveNew(repository, log)));
    }

    // Not @Transactional: the access check may write an audit row in its own transaction (see HealthDataAccess);
    // the repository query has its own read-only transaction.
    public PageResponse<MealLogResponse> list(long viewerId, long patientId, Instant from, Instant to, int page,
            int size) {
        access.checkCanRead(viewerId, patientId, PatientDataType.MEAL_LOGS);
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        return PageResponse.from(repository.findInRange(patientId, window.from(), window.to(), window.pageable()),
                MealLogResponse::from);
    }

    // Not @Transactional, like list().
    public MealLogResponse get(long viewerId, long patientId, long logId) {
        access.checkCanRead(viewerId, patientId, PatientDataType.MEAL_LOGS);
        return MealLogResponse.from(find(patientId, logId));
    }

    @Transactional
    public MealLogResponse update(long viewerId, long patientId, long logId, MealLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        MealLog log = find(patientId, logId);
        LogRules.requireLogTime(request.eatenAt(), "eatenAt", clock);
        apply(log, request);
        return MealLogResponse.from(repository.saveAndFlush(log));
    }

    @Transactional
    public void delete(long viewerId, long patientId, long logId) {
        access.checkCanWrite(viewerId, patientId);
        find(patientId, logId).markDeleted(clock.instant());
        // Doses linked to this meal would keep pointing to a meal that no longer exists (and could not be saved
        // again with that link): same transaction, so the meal and the links change together.
        insulinLogRepository.unlinkMeal(logId);
    }

    private MealLog find(long patientId, long logId) {
        return repository.findByIdAndPatientId(logId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    private static void apply(MealLog log, MealLogRequest request) {
        log.update(request.mealType(), request.eatenAt(), LogRules.text(request.description()), request.carbsG(),
                request.caloriesKcal(), request.proteinG(), request.fatG(), LogRules.text(request.notes()));
    }
}
