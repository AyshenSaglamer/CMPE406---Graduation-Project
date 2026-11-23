package com.diamate.backend.service;

import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;

import com.diamate.backend.api.dto.response.AccessLogEntryResponse;
import com.diamate.backend.api.dto.response.AuditLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.AuditLogRepository;
import com.diamate.backend.repository.AuditLogRepository.Filter;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/**
 * Reading the audit trail (writing is AuditService):
 * - the patient's access log: who else read or changed their data, including refused attempts, so the patient can
 *   check what their care team does with the sharing they granted;
 * - the ADMIN's search over every row, for security reviews. Reading it is itself written to the audit log.
 *
 * Both use the list rules of the log endpoints: from / to optional (default: the last 14 days), size at most 200.
 * Not @Transactional: the ADMIN's AUDIT_LOG_VIEWED row is written even if reading fails afterwards.
 */
@Service
public class AuditLogService {

    /** Action names are upper-case words joined by "_" (LOGIN_FAILED, VIEW_PATIENT_DATA ...). */
    private static final Pattern ACTION = Pattern.compile("[A-Z][A-Z_]{0,59}");
    private static final TypeReference<Map<String, Object>> DETAILS = new TypeReference<>() {
    };

    private final AuditLogRepository repository;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public AuditLogService(AuditLogRepository repository, AuditService auditService, ObjectMapper objectMapper,
            Clock clock) {
        this.repository = repository;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    /**
     * Only the patient sees their own access log: a clinician, caregiver, another patient or an ADMIN gets 404, the
     * same as an unknown patient (the ADMIN has the full search instead).
     */
    public PageResponse<AccessLogEntryResponse> patientAccessLog(long viewerId, long patientId,
            Instant from, Instant to, int page, int size) {
        if (viewerId != patientId) {
            throw new ResourceNotFoundException("Patient not found");
        }
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        long total = repository.countForPatient(patientId, window.from(), window.to());
        List<AccessLogEntryResponse> items = repository.findForPatient(patientId, window.from(), window.to(),
                window.pageable().getOffset(), size).stream()
                .map(row -> new AccessLogEntryResponse(row.createdAt(), row.actorId(), row.actorFirstName(),
                        row.actorLastName(), row.actorRole(), row.action(), row.entityType(), row.entityId(),
                        row.success(), details(row.detailsJson())))
                .toList();
        return page(items, page, size, total);
    }

    /** Every filter is optional. action must look like an action name (400 otherwise, before any query). */
    public PageResponse<AuditLogResponse> search(long adminId, Long userId, Long patientId, String action,
            Boolean success, Instant from, Instant to, int page, int size) {
        String normalizedAction = null;
        if (action != null && !action.isBlank()) {
            normalizedAction = action.trim();
            if (!ACTION.matcher(normalizedAction).matches()) {
                throw new InvalidFieldException("action", "Action must be an action name such as LOGIN_FAILED");
            }
        }
        LogRules.Window window = LogRules.window(from, to, page, size, clock);
        Filter filter = new Filter(window.from(), window.to(), userId, patientId, normalizedAction, success);

        Map<String, String> used = new LinkedHashMap<>();
        used.put("from", window.from().toString());
        used.put("to", window.to().toString());
        if (userId != null) {
            used.put("userId", userId.toString());
        }
        if (patientId != null) {
            used.put("patientId", patientId.toString());
        }
        if (normalizedAction != null) {
            used.put("action", normalizedAction);
        }
        if (success != null) {
            used.put("success", success.toString());
        }
        auditService.auditLogViewed(adminId, used);

        long total = repository.countMatching(filter);
        List<AuditLogResponse> items = repository.findMatching(filter, window.pageable().getOffset(), size).stream()
                .map(row -> new AuditLogResponse(row.id(), row.createdAt(), row.userId(), row.patientId(),
                        row.action(), row.entityType(), row.entityId(), row.success(), details(row.detailsJson()),
                        row.ipAddress(), row.userAgent()))
                .toList();
        return page(items, page, size, total);
    }

    private Map<String, Object> details(String json) {
        return json == null ? null : objectMapper.readValue(json, DETAILS);
    }

    private static <T> PageResponse<T> page(List<T> items, int page, int size, long total) {
        return new PageResponse<>(items, page, size, total, (int) ((total + size - 1) / size));
    }
}
