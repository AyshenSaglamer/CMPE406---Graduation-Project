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
 * Only /predict-food is used; the service keeps the photo in memory and never writes it to disk.
 *
 * Errors become FoodVisionException: 503 when the service cannot be reached (or says it is unavailable), 422 when it
 * refuses the image (its 400 / 413 / 422, e.g. a file Pillow cannot open), 502 for anything else, including an
 * answer that does not look like the expected JSON.
 */
@Component
public class FoodVisionClient {

    /** Class names of the model: lower case with underscores ("apple_pie", "cig_kofte"). */
    private static final Pattern FOOD_NAME = Pattern.compile("[a-z0-9_]{1,100}");

    /** Detector labels: COCO names such as "bowl" or "hot dog". */
    private static final Pattern DETECTOR_LABEL = Pattern.compile("[a-z0-9 _]{1,50}");

    /** The service sends at most 5 food regions; more is not an answer of ours. */
    static final int MAX_ITEMS = 10;

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
        if (!validPredictions(result.topPredictions())) {
            return false;
        }
        List<FastApiFoodResult.Item> items = result.items();
        return items == null || items.size() <= MAX_ITEMS && items.stream().allMatch(FoodVisionClient::isValid);
    }

    private static boolean isValid(FastApiFoodResult.Item item) {
        return item != null && validBox(item.box()) && validPredictions(item.topPredictions())
                && (item.detectorLabel() == null || DETECTOR_LABEL.matcher(item.detectorLabel()).matches());
    }

    private static boolean validBox(List<Double> box) {
        return box != null && box.size() == 4 && box.stream().allMatch(v -> v != null && v >= 0 && v <= 1)
                && box.get(0) < box.get(2) && box.get(1) < box.get(3);
    }

    private static boolean validPredictions(List<FastApiFoodResult.Prediction> predictions) {
        if (predictions == null || predictions.isEmpty()) {
            return false;
        }
        return predictions.stream().allMatch(p -> p != null && p.food() != null
                && FOOD_NAME.matcher(p.food()).matches() && p.confidence() != null
                && p.confidence() >= 0 && p.confidence() <= 1);
    }
}
