package com.diamate.backend.api.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.request.AiEntriesRequest;
import com.diamate.backend.api.dto.response.AiEntriesResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.AiEntryService;

import jakarta.validation.Valid;

/**
 * Step 2 of the AI assistant: POST /api/v1/ai/parse shows the patient what Dia understood (nothing saved); after the
 * patient confirms, the app sends those entries here and they are saved as logs with source AI_ASSISTANT.
 * Writing: only the patient (PATIENT role here, own id in the service), like the log endpoints.
 */
@RestController
@RequestMapping("/api/v1/patients/{patientId}/ai-entries")
public class AiEntryController {

    private final AiEntryService aiEntryService;

    public AiEntryController(AiEntryService aiEntryService) {
        this.aiEntryService = aiEntryService;
    }

    /** 201 when at least one log was saved; 200 when every entry had been saved before (same clientUuid). */
    @PostMapping
    @PreAuthorize("hasRole('PATIENT')")
    public ResponseEntity<AiEntriesResponse> save(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @Valid @RequestBody AiEntriesRequest request) {
        AiEntriesResponse response = aiEntryService.save(CurrentUser.id(jwt), patientId, request);
        boolean anyCreated = response.saved().stream().anyMatch(AiEntriesResponse.Saved::created);
        return ResponseEntity.status(anyCreated ? HttpStatus.CREATED : HttpStatus.OK).body(response);
    }
}
