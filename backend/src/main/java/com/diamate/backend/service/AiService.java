package com.diamate.backend.service;

import com.diamate.backend.dto.AiParseRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.HashMap;
import java.util.Map;

@Service
public class AiService {

    private final RestClient restClient;

    public AiService(
            @Value(
                "${AI_SERVICE_BASE_URL:http://localhost:8000}"
            )
            String aiServiceBaseUrl
    ) {
        this.restClient = RestClient.builder()
                .baseUrl(aiServiceBaseUrl)
                .build();
    }

    public Map<String, Object> parseText(String text) {

        // Reject empty or blank input
        if (text == null || text.trim().isEmpty()) {
            return createErrorResponse(
                    "INVALID_INPUT",
                    "Text cannot be empty."
            );
        }

        // Reject excessively long input
        if (text.length() > 500) {
            return createErrorResponse(
                    "INPUT_TOO_LONG",
                    "Text cannot exceed 500 characters."
            );
        }

        AiParseRequest request = new AiParseRequest(text);

        try {
            Map<String, Object> response = restClient.post()
                    .uri("/api/v1/nlp/parse")
                    .body(request)
                    .retrieve()
                    .body(Map.class);

            // Handle unexpected empty response from FastAPI
            if (response == null) {
                return createErrorResponse(
                        "EMPTY_RESPONSE",
                        "The AI service returned an empty response."
                );
            }

            return response;

        } catch (RestClientException exception) {
            return createErrorResponse(
                    "AI_SERVICE_UNAVAILABLE",
                    "The AI service is currently unavailable."
            );
        }
    }

    private Map<String, Object> createErrorResponse(
            String status,
            String message
    ) {
        Map<String, Object> response = new HashMap<>();

        response.put("intent", "UNKNOWN");
        response.put("value", null);
        response.put("unit", null);
        response.put("status", status);
        response.put("message", message);

        return response;
    }
}
