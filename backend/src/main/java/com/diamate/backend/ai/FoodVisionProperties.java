package com.diamate.backend.ai;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Binds the diamate.food-vision.* settings from application.yml (Ayşenur's FastAPI food photo service,
 * food-vision-service).
 *
 * @param baseUrl        where the service runs, e.g. http://localhost:8001 (http://food-vision:8001 inside Docker)
 * @param connectTimeout how long to wait for a connection; a stopped service fails fast instead of hanging requests
 * @param readTimeout    how long to wait for the answer (one ResNet50 pass on the CPU)
 */
@Validated
@ConfigurationProperties(prefix = "diamate.food-vision")
public record FoodVisionProperties(
        @NotBlank String baseUrl,
        @NotNull Duration connectTimeout,
        @NotNull Duration readTimeout) {
}
