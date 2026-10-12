package com.diamate.backend.ai;

import java.util.Map;

import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.diamate.backend.exception.AiServiceException;

/**
 * Calls the team's FastAPI AI service (ai-service/main.py).
 *
 * The AI service keeps no data: the backend sends it what it needs
 * and decides what to save.
 *
 * Errors are turned into AiServiceException (503 / 502), so the app
 * gets a clear problem response instead of a 500 when the AI service
 * is down.
 */
@Component
public class AiClient {

    private final RestClient restClient;

    public AiClient(RestClient aiRestClient) {
        this.restClient = aiRestClient;
    }

    /**
     * Splits a sentence into health log entries.
     *
     * Example:
     * "glucose 130 and 6 units of insulin"
     * -> two structured entries.
     */
    public FastApiParseResult parseMultiple(String text) {
        FastApiParseResult result;

        try {
            result = restClient.post()
                    .uri("/api/v1/nlp/parse-multiple")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("text", text))
                    .retrieve()
                    .body(FastApiParseResult.class);

        } catch (ResourceAccessException e) {
            throw AiServiceException.unavailable(e);

        } catch (RestClientException e) {
            throw AiServiceException.badResponse(e);
        }

        if (result == null || result.status() == null) {
            throw AiServiceException.badResponse(null);
        }

        return result;
    }

    /**
     * Sends authorized patient health-log data to the
     * FastAPI patient-summary integration endpoint.
     *
     * Spring Boot remains responsible for database access
     * and authorization. FastAPI only analyzes the supplied data.
     */
    public Map<String, Object> patientSummary(
            FastApiPatientSummaryRequest request) {

        Map<String, Object> result;

        try {
            result = restClient.post()
                    .uri("/api/v1/integration/patient-summary")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(request)
                    .retrieve()
                    .body(
                            new ParameterizedTypeReference<
                                    Map<String, Object>>() {
                            });

        } catch (ResourceAccessException e) {
            throw AiServiceException.unavailable(e);

        } catch (RestClientException e) {
            throw AiServiceException.badResponse(e);
        }

        if (result == null || result.isEmpty()) {
            throw AiServiceException.badResponse(null);
        }

        return result;
    }
}
