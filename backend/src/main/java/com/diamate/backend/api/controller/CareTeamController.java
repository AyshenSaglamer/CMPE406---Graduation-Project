package com.diamate.backend.api.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.response.CareTeamAlertResponse;
import com.diamate.backend.api.dto.response.CareTeamPatientResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AlertService;
import com.diamate.backend.service.PatientService;

@RestController
@RequestMapping("/api/v1/care-team")
public class CareTeamController {

    private final PatientService patientService;
    private final AlertService alertService;

    public CareTeamController(PatientService patientService, AlertService alertService) {
        this.patientService = patientService;
        this.alertService = alertService;
    }

    // Clinicians and caregivers: the patients who granted them access (ACTIVE relationships only).
    @GetMapping("/patients")
    @PreAuthorize("hasAnyRole('CLINICIAN', 'CAREGIVER')")
    public List<CareTeamPatientResponse> patients(@AuthenticationPrincipal Jwt jwt) {
        return patientService.getCareTeamPatients(CurrentUser.id(jwt));
    }

    /**
     * The alerts of all those patients who share alerts, newest first, in one request. status is optional
     * (?status=OPEN for the dashboard; with size=1, totalElements is the number of open alerts).
     */
    @GetMapping("/alerts")
    @PreAuthorize("hasAnyRole('CLINICIAN', 'CAREGIVER')")
    public PageResponse<CareTeamAlertResponse> alerts(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) AlertStatus status, @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return alertService.careTeamAlerts(CurrentUser.id(jwt), status, page, size);
    }
}
