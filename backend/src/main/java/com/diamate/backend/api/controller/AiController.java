package com.diamate.backend.api.controller;

import java.time.Instant;
import java.util.Map;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.diamate.backend.api.dto.request.AiParseRequest;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AiService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final AiService aiService;

    public AiController(AiService aiService) {
        this.aiService = aiService;
    }

    /**
     * Parses natural-language patient health logging text.
     */
    @PostMapping("/parse")
    @PreAuthorize("hasRole('PATIENT')")
    public AiParseResponse parse(
            @Valid @RequestBody AiParseRequest request) {

        return aiService.parse(request.text());
    }

    /**
     * Parses a patient voice health-log entry.
     *
     * The authenticated patient uploads an audio recording
     * to Spring Boot as multipart/form-data.
     *
     * Spring forwards the audio to the FastAPI AI service,
     * where speech-to-text converts the recording into a
     * transcript. The transcript is then processed by the
     * existing NLP pipeline.
     *
     * Example:
     *
     * "My glucose is 145 and I walked for 30 minutes."
     *
     * may produce structured LOG_GLUCOSE and LOG_ACTIVITY
     * results.
     */
    @PostMapping(
            value = "/voice",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('PATIENT')")
    public Map<String, Object> parseVoice(
            @RequestPart("audio") MultipartFile audio) {

        return aiService.parseVoice(audio);
    }

    /**
     * Returns a descriptive AI summary built from the
     * authorized patient's health-log history.
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

    /**
     * Returns personalized statistical anomaly analysis
     * based on the authorized patient's health-log history.
     */
    @GetMapping("/patients/{patientId}/anomaly")
    public Map<String, Object> patientAnomaly(
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

        return aiService.patientAnomaly(
                CurrentUser.id(jwt),
                patientId,
                from,
                to,
                rangeLow,
                rangeHigh);
    }

    /**
     * Returns a technical data-quality report for the
     * authorized patient's health-log history.
     */
    @GetMapping("/patients/{patientId}/data-quality")
    public Map<String, Object> patientDataQuality(
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

        return aiService.patientDataQuality(
                CurrentUser.id(jwt),
                patientId,
                from,
                to,
                rangeLow,
                rangeHigh);
    }

    /**
     * Returns a model-input drift report based on the
     * authorized patient's health-log history.
     *
     * Drift compares an older reference period with newer
     * patient-history records to identify statistical changes
     * in model-input features.
     *
     * Drift is an engineering model-monitoring signal only
     * and does not represent diagnosis, clinical deterioration,
     * medical risk, treatment advice, or medication guidance.
     */
    @GetMapping("/patients/{patientId}/drift")
    public Map<String, Object> patientDrift(
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

        return aiService.patientDrift(
                CurrentUser.id(jwt),
                patientId,
                from,
                to,
                rangeLow,
                rangeHigh);
    }

    /**
     * Returns an experimental XGBoost glucose-trend
     * prediction based on the authorized patient's
     * health-log history.
     *
     * The prediction may include class probabilities,
     * confidence, uncertainty, and explainable-AI
     * information.
     *
     * These outputs describe experimental model behaviour
     * only. They do not represent clinical probability,
     * diagnosis, medical risk, treatment advice, or
     * medication guidance.
     */
    @GetMapping("/patients/{patientId}/prediction")
    public Map<String, Object> patientPrediction(
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

        return aiService.patientPrediction(
                CurrentUser.id(jwt),
                patientId,
                from,
                to,
                rangeLow,
                rangeHigh);
    }
}
