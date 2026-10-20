package com.diamate.backend.api.controller;

import java.time.Instant;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.request.AlertStatusRequest;
import com.diamate.backend.api.dto.response.AlertResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AlertService;

import jakarta.validation.Valid;

/**
 * Glucose alerts of a patient (out-of-range readings). The backend creates them; this API lists them and lets the
 * patient or the care team acknowledge / resolve them.
 * No role annotation on purpose, like the overview: who may see THIS patient's alerts depends on the care
 * relationship (can_receive_alerts), which AlertService checks (404 otherwise).
 */
@RestController
@RequestMapping("/api/v1/patients/{patientId}/alerts")
public class AlertController {

    private final AlertService alertService;

    public AlertController(AlertService alertService) {
        this.alertService = alertService;
    }

    /** Newest first. status (OPEN, ACKNOWLEDGED, RESOLVED, DISMISSED), from and to are optional. */
    @GetMapping
    public PageResponse<AlertResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) AlertStatus status, @RequestParam(required = false) Instant from,
            @RequestParam(required = false) Instant to, @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return alertService.list(CurrentUser.id(jwt), patientId, status, from, to, page, size);
    }

    @GetMapping("/{alertId}")
    public AlertResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long alertId) {
        return alertService.get(CurrentUser.id(jwt), patientId, alertId);
    }

    /** Body: {"status":"ACKNOWLEDGED"} or {"status":"RESOLVED"}. */
    @PatchMapping("/{alertId}")
    public AlertResponse changeStatus(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long alertId, @Valid @RequestBody AlertStatusRequest request) {
        return alertService.changeStatus(CurrentUser.id(jwt), patientId, alertId, request.status());
    }
}
