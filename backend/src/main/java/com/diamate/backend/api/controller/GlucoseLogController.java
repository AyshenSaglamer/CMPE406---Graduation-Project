package com.diamate.backend.api.controller;

import java.net.URI;
import java.time.Instant;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.CreateResult;
import com.diamate.backend.service.GlucoseLogService;

import jakarta.validation.Valid;

/**
 * Glucose readings of a patient (mg/dL). A new reading outside the patient's thresholds also creates an alert.
 * Reading: the patient, or a clinician / caregiver with an ACTIVE relationship (checked in the service, 404 otherwise).
 * Writing: only the patient (PATIENT role here, own id in the service).
 */
@RestController
@RequestMapping("/api/v1/patients/{patientId}/glucose-logs")
public class GlucoseLogController {

    private final GlucoseLogService glucoseLogService;

    public GlucoseLogController(GlucoseLogService glucoseLogService) {
        this.glucoseLogService = glucoseLogService;
    }

    /** 201 + Location for a new log; 200 with the existing log when the same clientUuid was already saved. */
    @PostMapping
    @PreAuthorize("hasRole('PATIENT')")
    public ResponseEntity<GlucoseLogResponse> create(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @Valid @RequestBody GlucoseLogRequest request) {
        CreateResult<GlucoseLogResponse> result = glucoseLogService.create(CurrentUser.id(jwt), patientId, request);
        if (!result.created()) {
            return ResponseEntity.ok(result.log());
        }
        URI location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}")
                .buildAndExpand(result.log().id()).toUri();
        return ResponseEntity.created(location).body(result.log());
    }

    /** Newest first. Without from/to: the last 14 days. Times in ISO-8601 UTC, e.g. 2026-10-01T00:00:00Z. */
    @GetMapping
    public PageResponse<GlucoseLogResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) Instant from, @RequestParam(required = false) Instant to,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return glucoseLogService.list(CurrentUser.id(jwt), patientId, from, to, page, size);
    }

    @GetMapping("/{logId}")
    public GlucoseLogResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long logId) {
        return glucoseLogService.get(CurrentUser.id(jwt), patientId, logId);
    }

    /** Replaces all editable fields (send the whole log, not only the changed fields). */
    @PutMapping("/{logId}")
    @PreAuthorize("hasRole('PATIENT')")
    public GlucoseLogResponse update(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long logId, @Valid @RequestBody GlucoseLogRequest request) {
        return glucoseLogService.update(CurrentUser.id(jwt), patientId, logId, request);
    }

    /** Soft delete: 204, and the log no longer appears in any list. */
    @DeleteMapping("/{logId}")
    @PreAuthorize("hasRole('PATIENT')")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long logId) {
        glucoseLogService.delete(CurrentUser.id(jwt), patientId, logId);
        return ResponseEntity.noContent().build();
    }
}
