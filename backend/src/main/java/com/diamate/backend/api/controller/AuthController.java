package com.diamate.backend.api.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.request.LoginRequest;
import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.api.dto.response.AuthResponse;
import com.diamate.backend.api.dto.response.UserResponse;
import com.diamate.backend.service.AuthService;

import jakarta.validation.Valid;

@RestController // It tells Spring, "This class is an API controller.
@RequestMapping("/api/v1/auth") // The common address prefix for all endpoints in this class.
public class AuthController {

    private final AuthService authService;

    // Constructor (dependency injection)
    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register") // This method responds only to POST requests. The full address is /api/v1/auth/register.
    @ResponseStatus(HttpStatus.CREATED) // returns 201 instead of 200 on success
    public UserResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login") // The full address is /api/v1/auth/login.
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }
    
}