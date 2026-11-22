package com.diamate.backend.ai;

import java.util.Map;
import java.util.function.Supplier;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import com.diamate.backend.exception.AiServiceException;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Calls the team's FastAPI AI service (ai-service/main.py). The AI service keeps no data: the backend sends it
 * what it needs and decides what to save. Errors are turned into AiServiceException, so the app gets a clear problem
 * response instead of a 500: 503 when the service cannot be reached (or says it is unavailable), 422 when it
 * understood the request but cannot work with it (e.g. too few readings for an analysis), 502 for anything else.
 *
 * Voice uploads use their own RestClient with a longer read timeout (speech-to-text takes a while).
 */
@Component
public class AiClient {

    /** The AI service's own explanation is passed on only if it is short, plain text. */
    static final int MAX_DETAIL_LENGTH = 300;

    private static final ParameterizedTypeReference<Map<String, Object>> JSON_OBJECT =
            new ParameterizedTypeReference<>() {
            };
    private static final JsonMapper JSON = JsonMapper.builder().build();

    private final RestClient restClient;
    private final RestClient voiceClient;

    @Autowired
    public AiClient(@Qualifier("aiRestClient") RestClient aiRestClient,
            @Qualifier("aiVoiceRestClient") RestClient aiVoiceRestClient) {
        this.restClient = aiRestClient;
        this.voiceClient = aiVoiceRestClient;
    }

    /** One client for everything (tests). */
    public AiClient(RestClient aiRestClient) {
        this(aiRestClient, aiRestClient);
    }

    public FastApiParseResult parseMultiple(String text) {
        FastApiParseResult result = call(() -> restClient.post()
                .uri("/api/v1/nlp/parse-multiple")
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("text", text))
                .retrieve()
                .body(FastApiParseResult.class));
        if (result == null || result.status() == null) {
            throw AiServiceException.badResponse(null);
        }
        return result;
    }

    /**
     * Sends a recording to Whisper + the NLP parser (POST /api/v1/voice/parse, multipart field "audio"). The file has
     * already been checked by AiService (type, size); the AI service checks it again.
     */
    public FastApiVoiceResult parseVoice(byte[] audio, String filename, MediaType contentType) {
        // A plain MultiValueMap (FormHttpMessageConverter), not MultipartBodyBuilder: that one needs the reactive
        // libraries, which this servlet application does not have.
        HttpHeaders partHeaders = new HttpHeaders();
        partHeaders.setContentType(contentType);
        MultiValueMap<String, Object> parts = new LinkedMultiValueMap<>();
        parts.add("audio", new HttpEntity<>(new ByteArrayResource(audio) {
            @Override
            public String getFilename() {
                return filename;
            }
        }, partHeaders));
        FastApiVoiceResult result = call(() -> voiceClient.post()
                .uri("/api/v1/voice/parse")
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(parts)
                .retrieve()
                .body(FastApiVoiceResult.class));
        if (result == null || result.status() == null) {
            throw AiServiceException.badResponse(null);
        }
        return result;
    }

    /** Kept for the summary's callers; same as patientAnalysis(SUMMARY, request). */
    public Map<String, Object> patientSummary(FastApiPatientSummaryRequest request) {
        return patientAnalysis(AiAnalysis.SUMMARY, request);
    }

    /** One of the patient-history analyses; the JSON object of the AI service is returned unchanged. */
    public Map<String, Object> patientAnalysis(AiAnalysis analysis, FastApiPatientSummaryRequest request) {
        Map<String, Object> result = call(() -> restClient.post()
                .uri(analysis.path())
                .contentType(MediaType.APPLICATION_JSON)
                .body(request)
                .retrieve()
                .body(JSON_OBJECT));
        if (result == null || result.isEmpty()) {
            throw AiServiceException.badResponse(null);
        }
        return result;
    }

    private static <T> T call(Supplier<T> request) {
        try {
            return request.get();
        } catch (ResourceAccessException e) {
            // Connection refused, timeout, unknown host: the service is not reachable.
            throw AiServiceException.unavailable(e);
        } catch (RestClientResponseException e) {
            throw translate(e);
        } catch (RestClientException e) {
            // A body that is not the expected JSON.
            throw AiServiceException.badResponse(e);
        }
    }

    /** 422 -> 422 with the service's explanation, 503 -> 503, everything else (other 4xx, 500) -> 502. */
    static AiServiceException translate(RestClientResponseException e) {
        int status = e.getStatusCode().value();
        if (status == 422) {
            return AiServiceException.unprocessable(detail(e.getResponseBodyAsString()), e);
        }
        if (status == 503) {
            return AiServiceException.unavailable(e);
        }
        return AiServiceException.badResponse(e);
    }

    /**
     * The AI service's explanation of an error, if it is a short single-line text: its own error format
     * {"status":"ERROR","error":{"code":"INVALID_INPUT","message":"..."}} (ai-service models/error_schemas.py), or
     * FastAPI's plain {"detail": "..."}. Pydantic's list of errors, long texts or anything with control characters give
     * null (a general message): the app should not show internals of the AI service.
     */
    static String detail(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        try {
            JsonNode root = JSON.readTree(body);
            JsonNode detail = root.path("error").get("message");
            if (detail == null) {
                detail = root.get("detail");
            }
            if (detail == null || !detail.isString()) {
                return null;
            }
            String text = detail.asString().strip();
            boolean plain = !text.isEmpty() && text.length() <= MAX_DETAIL_LENGTH
                    && text.chars().noneMatch(Character::isISOControl);
            return plain ? text : null;
        } catch (RuntimeException notJson) {
            return null;
        }
    }
}
