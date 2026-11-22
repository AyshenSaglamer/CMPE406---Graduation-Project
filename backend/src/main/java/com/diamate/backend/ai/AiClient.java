package com.diamate.backend.ai;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import com.diamate.backend.exception.AiServiceException;

/**
 * Calls the team's FastAPI AI service.
 *
 * Spring Boot remains responsible for authorization and
 * database access. FastAPI receives only the data required
 * for AI analysis.
 */
@Component
public class AiClient {

    private static final Pattern FASTAPI_DETAIL_PATTERN =
            Pattern.compile(
                    "\"detail\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"");

    private final RestClient restClient;

    public AiClient(RestClient aiRestClient) {
        this.restClient = aiRestClient;
    }

    /**
     * Splits a sentence into structured health-log entries.
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

        } catch (RestClientResponseException e) {

            throw translateFastApiError(e);

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
     */
    public Map<String, Object> patientSummary(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-summary",
                request);
    }

    /**
     * Sends authorized patient health-log data to the
     * FastAPI personalized anomaly integration endpoint.
     *
     * FastAPI evaluates the latest glucose observation
     * relative to the patient's own historical pattern.
     */
    public Map<String, Object> patientAnomaly(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-anomaly",
                request);
    }

    /**
     * Sends authorized patient health-log data to the
     * FastAPI data-quality integration endpoint.
     *
     * FastAPI evaluates the aggregated patient history
     * for missing values, duplicate records, invalid
     * timestamps, and large logging gaps.
     */
    public Map<String, Object> patientDataQuality(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-data-quality",
                request);
    }

    /**
     * Sends authorized patient health-log data to the
     * FastAPI model-input drift integration endpoint.
     *
     * FastAPI compares an older reference period with
     * newer patient-history records to identify statistical
     * changes in model-input features.
     *
     * Drift is an engineering model-monitoring signal only.
     * It does not represent diagnosis, clinical deterioration,
     * medical risk, treatment advice, or medication guidance.
     */
    public Map<String, Object> patientDrift(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-drift",
                request);
    }

    /**
     * Sends authorized patient health-log data to the
     * FastAPI XGBoost prediction integration endpoint.
     *
     * FastAPI converts the health logs into the shared
     * patient-history representation and applies the
     * experimental XGBoost model to classify the next
     * glucose trend.
     *
     * The response may include class probabilities,
     * confidence, uncertainty, and explainable-AI
     * information.
     *
     * These outputs describe experimental model behaviour
     * only. They do not represent clinical probability,
     * diagnosis, medical risk, treatment advice, or
     * medication guidance.
     */
    public Map<String, Object> patientPrediction(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-prediction",
                request);
    }

    /**
     * Shared helper for FastAPI endpoints that return
     * JSON objects.
     */
    private Map<String, Object> postForMap(
            String uri,
            Object request) {

        Map<String, Object> result;

        try {

            result = restClient.post()
                    .uri(uri)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(request)
                    .retrieve()
                    .body(
                            new ParameterizedTypeReference<
                                    Map<String, Object>>() {
                            });

        } catch (ResourceAccessException e) {

            /*
             * FastAPI could not be reached.
             */
            throw AiServiceException.unavailable(e);

        } catch (RestClientResponseException e) {

            /*
             * FastAPI was reached but returned an HTTP
             * error such as 422 or 503.
             */
            throw translateFastApiError(e);

        } catch (RestClientException e) {

            /*
             * Unexpected communication or response problem.
             */
            throw AiServiceException.badResponse(e);
        }

        if (result == null || result.isEmpty()) {
            throw AiServiceException.badResponse(null);
        }

        return result;
    }

    /**
     * Converts FastAPI HTTP errors into meaningful
     * Spring exceptions.
     */
    private AiServiceException translateFastApiError(
            RestClientResponseException exception) {

        HttpStatusCode status =
                exception.getStatusCode();

        /*
         * 422:
         * FastAPI understood the request, but the supplied
         * patient data is insufficient or invalid for the
         * requested analysis.
         */
        if (status.value() == 422) {

            String detail =
                    extractFastApiDetail(
                            exception.getResponseBodyAsString());

            return AiServiceException.unprocessable(
                    detail,
                    exception);
        }

        /*
         * 503:
         * FastAPI or a required AI component is temporarily
         * unavailable.
         */
        if (status.value() == 503) {

            return AiServiceException.unavailable(
                    exception);
        }

        /*
         * Any other FastAPI HTTP error is unexpected from
         * the integration perspective.
         */
        return AiServiceException.badResponse(
                exception);
    }

    /**
     * Extracts FastAPI's normal textual error detail:
     *
     * {"detail":"At least three glucose readings are required..."}
     *
     * This intentionally handles only textual detail messages.
     * If FastAPI returns a different structure, Spring falls
     * back to the generic safe 422 message.
     */
    private String extractFastApiDetail(
            String responseBody) {

        if (responseBody == null
                || responseBody.isBlank()) {

            return null;
        }

        Matcher matcher =
                FASTAPI_DETAIL_PATTERN.matcher(
                        responseBody);

        if (!matcher.find()) {
            return null;
        }

        return unescapeJsonString(
                matcher.group(1));
    }

    /**
     * Decodes the small set of JSON escape sequences that
     * may appear inside FastAPI's textual detail message.
     */
    private String unescapeJsonString(
            String value) {

        return value
                .replace("\\\"", "\"")
                .replace("\\\\", "\\")
                .replace("\\n", "\n")
                .replace("\\r", "\r")
                .replace("\\t", "\t");
    }
}
