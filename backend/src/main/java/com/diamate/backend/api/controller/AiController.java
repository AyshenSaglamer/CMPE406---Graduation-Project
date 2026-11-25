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

import com.diamate.backend.ai.AiAnalysis;
import com.diamate.backend.api.dto.request.AiParseRequest;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.api.dto.response.AiVoiceResponse;
import com.diamate.backend.api.dto.response.FoodRecognitionResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AiService;
import com.diamate.backend.service.FoodRecognitionService;

import jakarta.validation.Valid;

/**
 * AI assistant (Dia), meal photo recognition and the patient-history analyses. The app talks only to the backend; the
 * backend calls the FastAPI AI service and the food photo service. Nothing here saves data.
 *
 * The analyses (summary, anomaly, data-quality, drift, prediction) share their rules (AiService.patientAnalysis):
 * the patient, or a care team member with the "reports" and "glucose" permissions; from / to optional (default: last
 * 14 days, at most 31 days); rangeLow / rangeHigh the target range in mg/dL. Anomaly, drift and prediction describe
 * the patient's own data and an experimental model; they are not a diagnosis or treatment advice.
 */
@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final AiService aiService;
    private final FoodRecognitionService foodRecognitionService;

    public AiController(AiService aiService, FoodRecognitionService foodRecognitionService) {
        this.aiService = aiService;
        this.foodRecognitionService = foodRecognitionService;
    }

    /**
     * Body: {"text": "..."}. What the assistant understood; nothing is saved. Open to caregivers too, for the family
     * member they manage: saving goes through /patients/{id}/ai-entries, where checkCanWrite decides the patient.
     */
    @PostMapping("/parse")
    @PreAuthorize("hasAnyRole('PATIENT', 'CAREGIVER')")
    public AiParseResponse parse(@Valid @RequestBody AiParseRequest request) {
        return aiService.parse(request.text());
    }

    /**
     * multipart/form-data with a field "audio": a WAV, MP3, M4A, WEBM or OGG recording of at most 10 MB. Answers what
     * the speech-to-text heard and what the assistant understood; nothing is saved. Open to caregivers like parse.
     */
    @PostMapping(value = "/voice", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('PATIENT', 'CAREGIVER')")
    public AiVoiceResponse voice(@RequestPart("audio") MultipartFile audio) {
        return aiService.parseVoice(audio);
    }

    /**
     * multipart/form-data with a field "image": a JPG, PNG or WEBP meal photo of at most 5 MB. Answers the photo
     * model's best guesses with approximate nutrition; nothing is saved and the photo is not stored. The app lets the
     * patient confirm or correct the food and saves the meal with the meal log endpoint.
     */
    @PostMapping(value = "/food", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('PATIENT')")
    public FoodRecognitionResponse food(@RequestPart("image") MultipartFile image) {
        return foodRecognitionService.recognize(image);
    }

    @GetMapping("/patients/{patientId}/summary")
    public Map<String, Object> patientSummary(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "70") double rangeLow,
            @RequestParam(defaultValue = "180") double rangeHigh) {
        return analysis(AiAnalysis.SUMMARY, jwt, patientId, from, to, rangeLow, rangeHigh);
    }

    /** Glucose values that are unusual compared with the patient's own pattern. */
    @GetMapping("/patients/{patientId}/anomaly")
    public Map<String, Object> patientAnomaly(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "70") double rangeLow,
            @RequestParam(defaultValue = "180") double rangeHigh) {
        return analysis(AiAnalysis.ANOMALY, jwt, patientId, from, to, rangeLow, rangeHigh);
    }

    /** Technical quality of the logs: missing values, duplicates, invalid times, long gaps. */
    @GetMapping("/patients/{patientId}/data-quality")
    public Map<String, Object> patientDataQuality(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "70") double rangeLow,
            @RequestParam(defaultValue = "180") double rangeHigh) {
        return analysis(AiAnalysis.DATA_QUALITY, jwt, patientId, from, to, rangeLow, rangeHigh);
    }

    /** Whether the newer data differs from an older reference period (model monitoring). */
    @GetMapping("/patients/{patientId}/drift")
    public Map<String, Object> patientDrift(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "70") double rangeLow,
            @RequestParam(defaultValue = "180") double rangeHigh) {
        return analysis(AiAnalysis.DRIFT, jwt, patientId, from, to, rangeLow, rangeHigh);
    }

    /** Experimental glucose-trend prediction (XGBoost) with probabilities, confidence and explanation. */
    @GetMapping("/patients/{patientId}/prediction")
    public Map<String, Object> patientPrediction(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "70") double rangeLow,
            @RequestParam(defaultValue = "180") double rangeHigh) {
        return analysis(AiAnalysis.PREDICTION, jwt, patientId, from, to, rangeLow, rangeHigh);
    }

    private Map<String, Object> analysis(AiAnalysis analysis, Jwt jwt, long patientId, Instant from, Instant to,
            double rangeLow, double rangeHigh) {
        return aiService.patientAnalysis(analysis, CurrentUser.id(jwt), patientId, from, to, rangeLow, rangeHigh);
    }
}
