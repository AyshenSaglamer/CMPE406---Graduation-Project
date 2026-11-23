package com.diamate.backend.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Body of POST /api/v1/ai/parse. Same limit as the AI service (500 characters). */
public record AiParseRequest(

        @NotBlank(message = "Text is required")
        @Size(max = 500, message = "Text must be at most 500 characters")
        String text) { // e.g. "My glucose is 125 and I took 5 units of insulin"
}
