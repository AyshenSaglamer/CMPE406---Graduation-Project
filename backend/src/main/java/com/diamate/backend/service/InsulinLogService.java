package com.diamate.backend.service;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.InsulinLogRequest;
import com.diamate.backend.api.dto.response.InsulinLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.InsulinDeliveryMethod;
import com.diamate.backend.entity.InsulinLog;
import com.diamate.backend.entity.InsulinSource;
import com.diamate.backend.entity.InsulinType;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.InsulinLogRepository;
import com.diamate.backend.repository.MealLogRepository;
import com.diamate.backend.repository.PatientAccessRepository;

/** Insulin logs of one patient (same pattern as GlucoseLogService). Shared with the care team under "medications". */
@Service
public class InsulinLogService {

    private static final String NOT_FOUND = "Insulin log not found";

    private final InsulinLogRepository repository;
    private final MealLogRepository mealLogRepository;
    private final HealthDataAccess access;
    private final Clock clock;

    public InsulinLogService(InsulinLogRepository repository, MealLogRepository mealLogRepository,
            HealthDataAccess access, Clock clock) {
        this.repository = repository;
        this.mealLogRepository = mealLogRepository;
        this.access = access;
        this.clock = clock;
    }

    @Transactional
    public CreateResult<InsulinLogResponse> create(long viewerId, long patientId, InsulinLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        checkRules(patientId, request);

        if (request.clientUuid() != null) {
            Optional<InsulinLog> existing = repository.findByPatientIdAndClientUuid(patientId, request.clientUuid());
            if (existing.isPresent()) {
                return CreateResult.existing(InsulinLogResponse.from(existing.get()));
            }
        }

        InsulinLog log = new InsulinLog(patientId, request.clientUuid(),
                LogRules.source(request.source(), InsulinSource.class), viewerId);
        apply(log, request);
        return CreateResult.created(InsulinLogResponse.from(LogRules.saveNew(repository, log)));
    }

    @Transactional(readOnly = true)
    public PageResponse<InsulinLogResponse> list(long viewerId, long patientId, Instant from, Instant to, int page,
            int size) {
        access.checkCanRead(viewerId, patientId, PatientAccessRepository.PERMISSION_MEDICATIONS);
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        return PageResponse.from(repository.findInRange(patientId, window.from(), window.to(), window.pageable()),
                InsulinLogResponse::from);
    }

    @Transactional(readOnly = true)
    public InsulinLogResponse get(long viewerId, long patientId, long logId) {
        access.checkCanRead(viewerId, patientId, PatientAccessRepository.PERMISSION_MEDICATIONS);
        return InsulinLogResponse.from(find(patientId, logId));
    }

    @Transactional
    public InsulinLogResponse update(long viewerId, long patientId, long logId, InsulinLogRequest request) {
        access.checkCanWrite(viewerId, patientId);
        InsulinLog log = find(patientId, logId);
        checkRules(patientId, request);
        apply(log, request);
        return InsulinLogResponse.from(repository.saveAndFlush(log));
    }

    @Transactional
    public void delete(long viewerId, long patientId, long logId) {
        access.checkCanWrite(viewerId, patientId);
        find(patientId, logId).markDeleted(clock.instant());
    }

    private InsulinLog find(long patientId, long logId) {
        return repository.findByIdAndPatientId(logId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    private void checkRules(long patientId, InsulinLogRequest request) {
        LogRules.requireNotInFuture(request.administeredAt(), "administeredAt", clock);
        // A dose can only be linked to the same patient's (not deleted) meal.
        if (request.mealLogId() != null && !mealLogRepository.existsByIdAndPatientId(request.mealLogId(), patientId)) {
            throw new InvalidFieldException("mealLogId", "Meal log not found");
        }
    }

    private static void apply(InsulinLog log, InsulinLogRequest request) {
        log.update(request.doseUnits(),
                request.insulinType() != null ? request.insulinType() : InsulinType.OTHER,
                request.deliveryMethod() != null ? request.deliveryMethod() : InsulinDeliveryMethod.OTHER,
                LogRules.text(request.productName()), request.administeredAt(), request.mealLogId(),
                LogRules.text(request.notes()));
    }
}
