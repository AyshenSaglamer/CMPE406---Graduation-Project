package com.diamate.backend.api.controller;

import java.net.URI;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import com.diamate.backend.api.dto.request.DependentRequest;
import com.diamate.backend.api.dto.response.CareTeamAlertResponse;
import com.diamate.backend.api.dto.response.CareTeamPatientResponse;
import com.diamate.backend.api.dto.response.DependentResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AlertService;
import com.diamate.backend.service.DependentService;
import com.diamate.backend.service.PatientService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/care-team")
public class CareTeamController {

    private final PatientService patientService;
    private final AlertService alertService;
    private final DependentService dependentService;

    public CareTeamController(PatientService patientService, AlertService alertService,
            DependentService dependentService) {
        this.patientService = patientService;
        this.alertService = alertService;
        this.dependentService = dependentService;
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

    /**
     * "Add family member": a caregiver adds someone without an account (e.g. a child) and keeps their diary. 201 with
     * the new patientId, which works with every /patients/{patientId}/... endpoint for this caregiver. The dependent
     * also appears in GET /care-team/patients with managed = true. Nobody can log in as a dependent.
     */
    @PostMapping("/dependents")
    @PreAuthorize("hasRole('CAREGIVER')")
    public ResponseEntity<DependentResponse> addDependent(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody DependentRequest request) {
        DependentResponse created = dependentService.create(CurrentUser.id(jwt), request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}")
                .buildAndExpand(created.patientId()).toUri();
        return ResponseEntity.created(location).body(created);
    }

    /** Corrects a dependent's details (send every field). Only their managing caregiver; 404 for anyone else. */
    @PutMapping("/dependents/{patientId}")
    @PreAuthorize("hasRole('CAREGIVER')")
    public DependentResponse updateDependent(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @Valid @RequestBody DependentRequest request) {
        return dependentService.update(CurrentUser.id(jwt), patientId, request);
    }
}
