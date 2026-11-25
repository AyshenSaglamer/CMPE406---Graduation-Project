package com.diamate.backend.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** POST /api/v1/auth/refresh: the refresh token from the login (or from the previous refresh). */
public record RefreshRequest(

        @NotBlank(message = "Refresh token is required")
        @Size(max = 100, message = "Refresh token is too long")
        String refreshToken) {
}
