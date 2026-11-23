package com.diamate.backend.api.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.response.PatientOverviewResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.PatientService;

@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {

    private final PatientService patientService;

    public PatientController(PatientService patientService) {
        this.patientService = patientService;
    }

    // No role annotation on purpose: who may see THIS patient depends on the data (self or care relationship),
    // which PatientService checks. A role check alone would let every clinician read every patient.
    @GetMapping("/{patientId}/overview")
    public PatientOverviewResponse overview(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId) {
        return patientService.getOverview(CurrentUser.id(jwt), patientId);
    }
}
