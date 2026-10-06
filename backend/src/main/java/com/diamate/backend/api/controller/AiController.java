package com.diamate.backend.api.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.request.AiParseRequest;
import com.diamate.backend.api.dto.response.AiParseResponse;
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
}
