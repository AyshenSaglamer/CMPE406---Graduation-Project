package com.diamate.backend.api.controller;

import java.net.URI;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import com.diamate.backend.api.dto.request.CareInvitationRequest;
import com.diamate.backend.api.dto.request.CarePermissionsRequest;
import com.diamate.backend.api.dto.response.CareRelationshipResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.CareRelationshipService;

import jakarta.validation.Valid;

/**
 * Links a patient with a clinician or caregiver (care_relationships). The patient invites, the member accepts or
 * declines, the patient changes what is shared, either side ends it. Which relationship the caller may touch is
 * checked in CareRelationshipService (404 otherwise); the roles here only stop the wrong side early.
 */
@RestController
@RequestMapping("/api/v1/care-relationships")
public class CareRelationshipController {

    private final CareRelationshipService service;

    public CareRelationshipController(CareRelationshipService service) {
        this.service = service;
    }

    /** Body: {"memberEmail":"dr@example.com"} plus optional can_* flags. 201 with the PENDING invitation. */
    @PostMapping
    @PreAuthorize("hasRole('PATIENT')")
    public ResponseEntity<CareRelationshipResponse> invite(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CareInvitationRequest request) {
        CareRelationshipResponse created = service.invite(CurrentUser.id(jwt), request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}").buildAndExpand(created.id())
                .toUri();
        return ResponseEntity.created(location).body(created);
    }

    /** The caller's relationships (as patient or as member), newest first. ?status=PENDING shows open invitations. */
    @GetMapping
    public List<CareRelationshipResponse> list(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) String status) {
        return service.list(CurrentUser.id(jwt), status);
    }

    @PostMapping("/{id}/accept")
    @PreAuthorize("hasAnyRole('CLINICIAN', 'CAREGIVER')")
    public CareRelationshipResponse accept(@AuthenticationPrincipal Jwt jwt, @PathVariable long id) {
        return service.accept(CurrentUser.id(jwt), id);
    }

    @PostMapping("/{id}/decline")
    @PreAuthorize("hasAnyRole('CLINICIAN', 'CAREGIVER')")
    public CareRelationshipResponse decline(@AuthenticationPrincipal Jwt jwt, @PathVariable long id) {
        return service.decline(CurrentUser.id(jwt), id);
    }

    /** Body: only the flags to change, e.g. {"canViewMeals":false}. */
    @PatchMapping("/{id}")
    @PreAuthorize("hasRole('PATIENT')")
    public CareRelationshipResponse updatePermissions(@AuthenticationPrincipal Jwt jwt, @PathVariable long id,
            @RequestBody CarePermissionsRequest request) {
        return service.updatePermissions(CurrentUser.id(jwt), id, request);
    }

    /** Ends the relationship (REVOKED). The row stays as history; 204. */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> revoke(@AuthenticationPrincipal Jwt jwt, @PathVariable long id) {
        service.revoke(CurrentUser.id(jwt), id);
        return ResponseEntity.noContent().build();
    }
}
