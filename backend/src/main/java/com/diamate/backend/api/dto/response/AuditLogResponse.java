package com.diamate.backend.api.dto.response;

import java.time.Instant;
import java.util.Map;

/** A full audit_logs row for the ADMIN (GET /admin/audit-logs). Never contains passwords, tokens or health values. */
public record AuditLogResponse(long id, Instant at, Long userId, Long patientId, String action, String entityType,
        String entityId, boolean success, Map<String, Object> details, String ipAddress, String userAgent) {
}
