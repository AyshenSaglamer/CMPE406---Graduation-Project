package com.diamate.backend.api.controller;

import java.time.Instant;
import java.util.Map;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.request.AiParseRequest;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AiService;

import jakarta.validation.Valid;

/** AI assistant (Dia). The app talks only to the backend; the backend calls the FastAPI AI service. */
@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final AiService aiService;

    public AiController(AiService aiService) {
        this.aiService = aiService;
    }

    /**
     * "My glucose is 125 and I took 5 units of insulin" -> two entries. Nothing is saved; the app asks the patient
     * to confirm and then calls the log endpoints. 503 when the AI service is not reachable.
     */
    @PostMapping("/parse")
    @PreAuthorize("hasRole('PATIENT')")
    public AiParseResponse parse(@Valid @RequestBody AiParseRequest request) {
        return aiService.parse(request.text());
    }

    /**
     * Descriptive AI summary (statistics, patterns, insights) of a patient's logs, for the patient and for a clinician
     * or caregiver who may see the patient's glucose (fn_can_access, 404 otherwise; like the log lists, no role
     * check). rangeLow / rangeHigh are the target range chosen by the app: the AI service does not choose medical
     * ranges. 400 for a range over 31 days or fewer than 2 glucose readings, 502 / 503 when the AI service fails.
     */
    @GetMapping("/patients/{patientId}/summary")
    public Map<String, Object> patientSummary(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "70") double rangeLow,
            @RequestParam(defaultValue = "180") double rangeHigh) {
        return aiService.patientSummary(CurrentUser.id(jwt), patientId, from, to, rangeLow, rangeHigh);
    }
}
