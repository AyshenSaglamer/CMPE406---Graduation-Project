package com.diamate.backend.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// No format or length rules beyond the basics: a login must not reveal the password policy.
public record LoginRequest(

        @NotBlank(message = "Email is required")
        @Size(max = 150, message = "Email must be at most 150 characters")
        String email,

        @NotBlank(message = "Password is required")
        @Size(max = 200, message = "Password is too long")
        String password) {
	
}