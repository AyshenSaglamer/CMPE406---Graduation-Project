package com.diamate.backend.ai;

import java.io.IOException;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.multipart.MultipartFile;

import com.diamate.backend.exception.AiServiceException;

/**
 * Client responsible for communication with the DiaMate
 * FastAPI AI service.
 *
 * Spring Boot remains responsible for authorization and
 * database access.
 *
 * FastAPI receives only the information required for
 * AI-related processing.
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
     * Sends natural-language health logging text to
     * FastAPI's multi-intent NLP parser.
     *
     * Example:
     *
     * "My glucose is 145 and I walked for 30 minutes."
     *
     * may produce:
     *
     * LOG_GLUCOSE -> 145 mg/dL
     * LOG_ACTIVITY -> 30 minutes
     */
    public FastApiParseResult parseMultiple(
            String text) {

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

        if (result == null
                || result.status() == null) {

            throw AiServiceException.badResponse(null);
        }

        return result;
    }

    /**
     * Sends a voice recording to FastAPI.
     *
     * FastAPI performs:
     *
     * audio
     *   ->
     * speech-to-text
     *   ->
     * transcript
     *   ->
     * NLP parser
     *   ->
     * structured health-log intents
     *
     * Example transcript:
     *
     * "My glucose is 145 and I walked for 30 minutes."
     *
     * Example structured result:
     *
     * LOG_GLUCOSE -> 145 mg/dL
     * LOG_ACTIVITY -> 30 minutes
     */
    public Map<String, Object> parseVoice(
            MultipartFile audio) {

        if (audio == null || audio.isEmpty()) {

            throw AiServiceException.unprocessable(
                    "Audio file is required.",
                    null);
        }

        Map<String, Object> result;

        try {

            MultipartBodyBuilder builder =
                    new MultipartBodyBuilder();

            ByteArrayResource audioResource =
                    new ByteArrayResource(
                            audio.getBytes()) {

                        @Override
                        public String getFilename() {

                            String filename =
                                    audio.getOriginalFilename();

                            if (filename == null
                                    || filename.isBlank()) {

                                return "audio.m4a";
                            }

                            return filename;
                        }
                    };

            MediaType audioMediaType =
                    resolveAudioMediaType(
                            audio.getOriginalFilename(),
                            audio.getContentType());

            builder.part(
                            "audio",
                            audioResource)
                    .contentType(audioMediaType);

            result = restClient.post()
                    .uri("/api/v1/voice/parse")
                    .contentType(
                            MediaType.MULTIPART_FORM_DATA)
                    .body(builder.build())
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
             * FastAPI returned an HTTP error.
             */
            throw translateFastApiError(e);

        } catch (IOException e) {

            /*
             * Spring could not read the uploaded audio file.
             */
            throw AiServiceException.badResponse(e);

        } catch (RestClientException e) {

            /*
             * Unexpected communication/response problem.
             */
            throw AiServiceException.badResponse(e);
        }

        if (result == null || result.isEmpty()) {

            throw AiServiceException.badResponse(null);
        }

        return result;
    }

    /**
     * Sends authorized patient health history to FastAPI
     * for summary generation.
     */
    public Map<String, Object> patientSummary(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-summary",
                request);
    }

    /**
     * Sends authorized patient health history to FastAPI
     * for personalized anomaly analysis.
     *
     * The result describes statistical unusualness relative
     * to the patient's own historical pattern.
     *
     * It does not represent diagnosis or medical advice.
     */
    public Map<String, Object> patientAnomaly(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-anomaly",
                request);
    }

    /**
     * Sends authorized patient health history to FastAPI
     * for engineering data-quality analysis.
     */
    public Map<String, Object> patientDataQuality(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-data-quality",
                request);
    }

    /**
     * Sends authorized patient health history to FastAPI
     * for model-input drift monitoring.
     *
     * Drift is an engineering model-monitoring signal.
     *
     * It does not represent clinical deterioration,
     * diagnosis, treatment advice, or medication guidance.
     */
    public Map<String, Object> patientDrift(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-drift",
                request);
    }

    /**
     * Sends authorized patient health history to FastAPI
     * for the experimental XGBoost glucose-trend
     * classification pipeline.
     *
     * The response may include:
     *
     * - predicted trend
     * - class probabilities
     * - confidence
     * - uncertainty
     * - feature importance
     * - SHAP explanation
     *
     * These outputs describe experimental model behaviour.
     *
     * They do not represent clinical probability,
     * diagnosis, treatment advice, or medication guidance.
     */
    public Map<String, Object> patientPrediction(
            FastApiPatientSummaryRequest request) {

        return postForMap(
                "/api/v1/integration/patient-prediction",
                request);
    }

    /**
     * Shared helper for FastAPI endpoints that accept
     * JSON requests and return JSON objects.
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
             * FastAPI returned an HTTP error.
             */
            throw translateFastApiError(e);

        } catch (RestClientException e) {

            /*
             * Unexpected communication/response problem.
             */
            throw AiServiceException.badResponse(e);
        }

        if (result == null || result.isEmpty()) {

            throw AiServiceException.badResponse(null);
        }

        return result;
    }

    /**
     * Determines the audio MIME type that should be sent
     * to FastAPI.
     *
     * Why this exists:
     *
     * Some browsers/mobile clients upload an M4A recording
     * as application/octet-stream.
     *
     * FastAPI expects an actual supported audio MIME type.
     *
     * Therefore we normalize common formats here.
     */
    private MediaType resolveAudioMediaType(
            String filename,
            String contentType) {

        String normalizedFilename =
                filename == null
                        ? ""
                        : filename.toLowerCase();

        /*
         * Prefer the filename for known formats because
         * mobile clients sometimes report an incorrect
         * generic content type.
         */

        if (normalizedFilename.endsWith(".m4a")) {

            return MediaType.parseMediaType(
                    "audio/mp4");
        }

        if (normalizedFilename.endsWith(".mp3")) {

            return MediaType.parseMediaType(
                    "audio/mpeg");
        }

        if (normalizedFilename.endsWith(".wav")) {

            return MediaType.parseMediaType(
                    "audio/wav");
        }

        if (normalizedFilename.endsWith(".webm")) {

            return MediaType.parseMediaType(
                    "audio/webm");
        }

        if (normalizedFilename.endsWith(".ogg")) {

            return MediaType.parseMediaType(
                    "audio/ogg");
        }

        /*
         * If the client already supplied a real audio MIME
         * type, preserve it.
         */
        if (contentType != null
                && !contentType.isBlank()
                && contentType.startsWith("audio/")) {

            try {

                return MediaType.parseMediaType(
                        contentType);

            } catch (IllegalArgumentException ignored) {

                /*
                 * Fall through to the safe default below.
                 */
            }
        }

        /*
         * Safe fallback for the M4A format used by our
         * current DiaMate mobile voice test.
         */
        return MediaType.parseMediaType(
                "audio/mp4");
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
         * 422 means FastAPI understood the request but
         * could not process the supplied data.
         *
         * Examples:
         *
         * - insufficient glucose history
         * - invalid AI request
         * - invalid/unsupported audio input
         */
        if (status.value() == 422) {

            String detail =
                    extractFastApiDetail(
                            exception
                                    .getResponseBodyAsString());

            return AiServiceException.unprocessable(
                    detail,
                    exception);
        }

        /*
         * 503 means FastAPI or a required AI component
         * is temporarily unavailable.
         */
        if (status.value() == 503) {

            return AiServiceException.unavailable(
                    exception);
        }

        /*
         * Any other FastAPI HTTP error is considered an
         * unexpected AI-service response.
         */
        return AiServiceException.badResponse(
                exception);
    }

    /**
     * Extracts FastAPI's normal textual error detail.
     *
     * Example:
     *
     * {
     *   "detail":
     *   "At least 10 records are required."
     * }
     *
     * If FastAPI returns another structure, Spring uses
     * the generic safe error message instead.
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
     * Decodes common JSON escape sequences from FastAPI's
     * textual detail message.
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
