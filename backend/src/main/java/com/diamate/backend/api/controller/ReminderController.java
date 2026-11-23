package com.diamate.backend.api.controller;

import java.net.URI;
import java.time.Instant;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import com.diamate.backend.api.dto.request.ReminderEventRequest;
import com.diamate.backend.api.dto.request.ReminderRequest;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.api.dto.response.ReminderEventResponse;
import com.diamate.backend.api.dto.response.ReminderResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.CreateResult;
import com.diamate.backend.service.ReminderService;

import jakarta.validation.Valid;

/**
 * Medication (and other) reminders of a patient, and the Taken / Skipped / Missed answer for each occurrence.
 * Reading: the patient, or a clinician / caregiver whose ACTIVE relationship shares "medications" (checked in the
 * service, 404 otherwise). Writing: only the patient (PATIENT role here, own id in the service).
 */
@RestController
@RequestMapping("/api/v1/patients/{patientId}")
public class ReminderController {

    private final ReminderService reminderService;

    public ReminderController(ReminderService reminderService) {
        this.reminderService = reminderService;
    }

    /** In the order of the day (earliest time first). */
    @GetMapping("/reminders")
    public List<ReminderResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId) {
        return reminderService.list(CurrentUser.id(jwt), patientId);
    }

    /** 201 + Location. */
    @PostMapping("/reminders")
    @PreAuthorize("hasRole('PATIENT')")
    public ResponseEntity<ReminderResponse> create(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @Valid @RequestBody ReminderRequest request) {
        ReminderResponse created = reminderService.create(CurrentUser.id(jwt), patientId, request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}")
                .buildAndExpand(created.id()).toUri();
        return ResponseEntity.created(location).body(created);
    }

    @GetMapping("/reminders/{reminderId}")
    public ReminderResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long reminderId) {
        return reminderService.get(CurrentUser.id(jwt), patientId, reminderId);
    }

    /** Replaces all fields (send the whole reminder). active=false pauses it without losing its history. */
    @PutMapping("/reminders/{reminderId}")
    @PreAuthorize("hasRole('PATIENT')")
    public ReminderResponse update(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long reminderId, @Valid @RequestBody ReminderRequest request) {
        return reminderService.update(CurrentUser.id(jwt), patientId, reminderId, request);
    }

    /** 204; the reminder's occurrences are deleted with it. */
    @DeleteMapping("/reminders/{reminderId}")
    @PreAuthorize("hasRole('PATIENT')")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @PathVariable long reminderId) {
        reminderService.delete(CurrentUser.id(jwt), patientId, reminderId);
        return ResponseEntity.noContent().build();
    }

    /** 201 for a new occurrence; 200 when that scheduledFor was already reported (its status is changed). */
    @PostMapping("/reminders/{reminderId}/events")
    @PreAuthorize("hasRole('PATIENT')")
    public ResponseEntity<ReminderEventResponse> reportEvent(@AuthenticationPrincipal Jwt jwt,
            @PathVariable long patientId, @PathVariable long reminderId,
            @Valid @RequestBody ReminderEventRequest request) {
        CreateResult<ReminderEventResponse> result = reminderService.reportEvent(CurrentUser.id(jwt), patientId,
                reminderId, request);
        return result.created() ? ResponseEntity.status(201).body(result.log()) : ResponseEntity.ok(result.log());
    }

    /** Occurrences of all reminders, newest first. Without from/to: the last 14 days. */
    @GetMapping("/reminder-events")
    public PageResponse<ReminderEventResponse> events(@AuthenticationPrincipal Jwt jwt, @PathVariable long patientId,
            @RequestParam(required = false) Instant from, @RequestParam(required = false) Instant to,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return reminderService.events(CurrentUser.id(jwt), patientId, from, to, page, size);
    }
}
