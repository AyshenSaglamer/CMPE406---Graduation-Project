package com.diamate.backend.ai;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Binds the diamate.ai.* settings from application.yml (the FastAPI AI service of the team).
 *
 * @param baseUrl        where the AI service runs, e.g. http://localhost:8000 (http://ai-service:8000 inside Docker)
 * @param connectTimeout how long to wait for a connection; a stopped service fails fast instead of hanging requests
 * @param readTimeout    how long to wait for the answer
 */
@Validated
@ConfigurationProperties(prefix = "diamate.ai")
public record AiProperties(
        @NotBlank String baseUrl,
        @NotNull Duration connectTimeout,
        @NotNull Duration readTimeout) {
}
