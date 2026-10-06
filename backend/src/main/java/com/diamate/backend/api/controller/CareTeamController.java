package com.diamate.backend.api.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.response.CareTeamPatientResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.PatientService;

@RestController
@RequestMapping("/api/v1/care-team")
public class CareTeamController {

    private final PatientService patientService;

    public CareTeamController(PatientService patientService) {
        this.patientService = patientService;
    }

    // Clinicians and caregivers: the patients who granted them access (ACTIVE relationships only).
    @GetMapping("/patients")
    @PreAuthorize("hasAnyRole('CLINICIAN', 'CAREGIVER')")
    public List<CareTeamPatientResponse> patients(@AuthenticationPrincipal Jwt jwt) {
        return patientService.getCareTeamPatients(CurrentUser.id(jwt));
    }
}
