package com.diamate.backend.api.controller;

import java.time.Instant;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.response.AccessLogEntryResponse;
import com.diamate.backend.api.dto.response.AuditLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AuditLogService;

/**
 * Reading the audit trail: the patient's own access log and the ADMIN's search. Both newest first and paged; from and
 * to are optional (default: the last 14 days).
 */
@RestController
public class AuditLogController {

    private final AuditLogService service;

    public AuditLogController(AuditLogService service) {
        this.service = service;
    }

    /** Who else read or changed this patient's data (also refused attempts). Only the patient (404 for anyone else). */
    @GetMapping("/api/v1/patients/{patientId}/access-log")
    @PreAuthorize("hasRole('PATIENT')")
    public PageResponse<AccessLogEntryResponse> accessLog(@AuthenticationPrincipal Jwt jwt,
            @PathVariable long patientId, @RequestParam(required = false) Instant from,
            @RequestParam(required = false) Instant to, @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return service.patientAccessLog(CurrentUser.id(jwt), patientId, from, to, page, size);
    }

    /** Every audit row, filtered by userId, patientId, action (e.g. LOGIN_FAILED) and success. ADMIN only. */
    @GetMapping("/api/v1/admin/audit-logs")
    @PreAuthorize("hasRole('ADMIN')")
    public PageResponse<AuditLogResponse> search(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) Long userId, @RequestParam(required = false) Long patientId,
            @RequestParam(required = false) String action, @RequestParam(required = false) Boolean success,
            @RequestParam(required = false) Instant from, @RequestParam(required = false) Instant to,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return service.search(CurrentUser.id(jwt), userId, patientId, action, success, from, to, page, size);
    }
}
