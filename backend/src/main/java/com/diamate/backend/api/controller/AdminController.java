package com.diamate.backend.api.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.request.AccountStatusRequest;
import com.diamate.backend.api.dto.response.AdminUserResponse;
import com.diamate.backend.security.CurrentUser;
import com.diamate.backend.service.UserService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('ADMIN')") // every endpoint in this controller: ADMIN only, others get 403
public class AdminController {

    private final UserService userService;

    public AdminController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/users")
    public List<AdminUserResponse> users() {
        return userService.listUsers();
    }

    /**
     * {"active": false} stops an account at once: no login (403) and every token it already has gets 401.
     * {"active": true} turns it on again, e.g. approves a newly registered clinician.
     */
    @PatchMapping("/users/{userId}/status")
    public AdminUserResponse changeStatus(@AuthenticationPrincipal Jwt jwt, @PathVariable long userId,
            @Valid @RequestBody AccountStatusRequest request) {
        return userService.changeStatus(CurrentUser.id(jwt), userId, request.active());
    }
    
}