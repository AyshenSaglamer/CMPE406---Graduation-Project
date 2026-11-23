package com.diamate.backend.ai;

import java.util.List;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Qualifier;
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

import com.diamate.backend.exception.FoodVisionException;

/**
 * Calls Ayşenur's food photo service (food-vision-service, POST /predict-food). Like the AI service it is reachable
 * only from the backend (Docker network, no port on the host) and has no login of its own: the backend checks the
 * user and the file first.
 *
 * Only /predict-food is used. The service's older /upload-image (YOLO) writes every photo to its disk; this one keeps
 * the photo in memory.
 *
 * Errors become FoodVisionException: 503 when the service cannot be reached (or says it is unavailable), 422 when it
 * refuses the image (its 400 / 413 / 422, e.g. a file Pillow cannot open), 502 for anything else, including an
 * answer that does not look like the expected JSON.
 */
@Component
public class FoodVisionClient {

    /** Class names of the model: lower case with underscores ("apple_pie", "cig_kofte"). */
    private static final Pattern FOOD_NAME = Pattern.compile("[a-z0-9_]{1,100}");

    private final RestClient restClient;

    public FoodVisionClient(@Qualifier("foodVisionRestClient") RestClient foodVisionRestClient) {
        this.restClient = foodVisionRestClient;
    }

    /**
     * The model's best guesses for a photo that ImageFile has already checked (type, size). The answer is checked
     * too: at least one prediction, each with a class name and a confidence between 0 and 1.
     */
    public FastApiFoodResult predict(byte[] image, String filename, MediaType contentType) {
        // A plain MultiValueMap (FormHttpMessageConverter), as in AiClient.parseVoice.
        HttpHeaders partHeaders = new HttpHeaders();
        partHeaders.setContentType(contentType);
        MultiValueMap<String, Object> parts = new LinkedMultiValueMap<>();
        parts.add("file", new HttpEntity<>(new ByteArrayResource(image) {
            @Override
            public String getFilename() {
                return filename;
            }
        }, partHeaders));
        FastApiFoodResult result;
        try {
            result = restClient.post()
                    .uri("/predict-food")
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(parts)
                    .retrieve()
                    .body(FastApiFoodResult.class);
        } catch (ResourceAccessException e) {
            throw FoodVisionException.unavailable(e);
        } catch (RestClientResponseException e) {
            throw translate(e);
        } catch (RestClientException e) {
            throw FoodVisionException.badResponse(e);
        }
        if (!isValid(result)) {
            throw FoodVisionException.badResponse(null);
        }
        return result;
    }

    static FoodVisionException translate(RestClientResponseException e) {
        int status = e.getStatusCode().value();
        if (status == 400 || status == 413 || status == 422) {
            return FoodVisionException.unusableImage(AiClient.detail(e.getResponseBodyAsString()), e);
        }
        if (status == 503) {
            return FoodVisionException.unavailable(e);
        }
        return FoodVisionException.badResponse(e);
    }

    private static boolean isValid(FastApiFoodResult result) {
        if (result == null || Boolean.FALSE.equals(result.success())) {
            return false;
        }
        List<FastApiFoodResult.Prediction> predictions = result.topPredictions();
        if (predictions == null || predictions.isEmpty()) {
            return false;
        }
        return predictions.stream().allMatch(p -> p != null && p.food() != null
                && FOOD_NAME.matcher(p.food()).matches() && p.confidence() != null
                && p.confidence() >= 0 && p.confidence() <= 1);
    }
}
