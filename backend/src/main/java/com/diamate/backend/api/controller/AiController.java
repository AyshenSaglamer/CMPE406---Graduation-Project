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

/**
 * AI assistant (Dia).
 *
 * The mobile app talks only to the Spring Boot backend.
 * Spring Boot performs authorization and database access,
 * then calls the FastAPI AI service when AI processing is needed.
 */
@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final AiService aiService;

    public AiController(AiService aiService) {
        this.aiService = aiService;
    }

    /**
     * Parses natural-language health logging text.
     *
     * Nothing is saved automatically. The patient must confirm
     * the extracted information before the normal log endpoints
     * are used.
     */
    @PostMapping("/parse")
    @PreAuthorize("hasRole('PATIENT')")
    public AiParseResponse parse(
            @Valid @RequestBody AiParseRequest request) {

        return aiService.parse(request.text());
    }

    /**
     * Generates a descriptive AI/analytics summary from
     * an authorized patient's glucose, meal and activity history.
     *
     * The configured glucose range is supplied by the application.
     * The AI service does not select medical target ranges.
     */
    @GetMapping("/patients/{patientId}/summary")
    public Map<String, Object> patientSummary(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable long patientId,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
            Instant from,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
            Instant to,
            @RequestParam(defaultValue = "70")
            double rangeLow,
            @RequestParam(defaultValue = "180")
            double rangeHigh) {

        return aiService.patientSummary(
                CurrentUser.id(jwt),
                patientId,
                from,
                to,
                rangeLow,
                rangeHigh);
    }
}
