package com.diamate.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.time.Duration;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import com.diamate.backend.exception.FoodVisionException;

/**
 * The food photo service is not running in tests: MockRestServiceServer answers instead of it. The JSON below is the
 * real shape of food-vision-service's /predict-food answer (team repo, feature/food-vision 9742f8f).
 */
class FoodVisionClientTest {

    private static final String BASE_URL = "http://food-vision.test";
    private static final byte[] IMAGE = { (byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1, 2 };

    private final RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
    private final MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();

    @Test
    void sendsThePhotoAsMultipartFieldFileAndReadsTheGuesses() {
        server.expect(requestTo(BASE_URL + "/predict-food"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header("Content-Type", startsWith("multipart/form-data")))
                .andExpect(content().string(containsString("name=\"file\"; filename=\"meal.jpg\"")))
                .andExpect(content().string(containsString("Content-Type: image/jpeg")))
                .andRespond(withSuccess("""
                        {"success":true,"model":"ResNet50","predicted_food":"pizza","confidence":0.9123,
                         "top_predictions":[{"food":"pizza","confidence":0.9123},
                                            {"food":"lahmacun","confidence":0.05},
                                            {"food":"garlic_bread","confidence":0.01}],
                         "requires_user_confirmation":true}
                        """, MediaType.APPLICATION_JSON));

        FastApiFoodResult result = client().predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG);

        assertThat(result.model()).isEqualTo("ResNet50");
        assertThat(result.topPredictions()).extracting(FastApiFoodResult.Prediction::food)
                .containsExactly("pizza", "lahmacun", "garlic_bread");
        assertThat(result.topPredictions().getFirst().confidence()).isEqualTo(0.9123);
        assertThat(result.items()).isNull(); // an answer without food regions
        server.verify();
    }

    @Test
    void readsTheFoodRegions() {
        server.expect(requestTo(BASE_URL + "/predict-food"))
                .andRespond(withSuccess("""
                        {"success":true,"model":"ResNet50","top_predictions":[{"food":"pizza","confidence":0.52}],
                         "items":[{"box":[0.0504,0.1754,0.2733,0.8135],"detector_label":"sandwich",
                                   "detector_confidence":0.88,
                                   "top_predictions":[{"food":"hamburger","confidence":0.9999}]},
                                  {"box":[0.36,0.16,0.65,0.76],"detector_label":"hot dog",
                                   "top_predictions":[{"food":"pizza","confidence":0.99}]}],
                         "multiple_foods":true,"requires_user_confirmation":true}
                        """, MediaType.APPLICATION_JSON));

        FastApiFoodResult result = client().predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG);

        assertThat(result.items()).hasSize(2);
        assertThat(result.items().getFirst().box()).containsExactly(0.0504, 0.1754, 0.2733, 0.8135);
        assertThat(result.items().getFirst().detectorLabel()).isEqualTo("sandwich");
        assertThat(result.items().getFirst().topPredictions().getFirst().food()).isEqualTo("hamburger");
        assertThat(result.items().get(1).detectorLabel()).isEqualTo("hot dog");
    }

    @Test
    void anImageTheServiceRefusesIsA422WithItsReason() {
        server.expect(requestTo(BASE_URL + "/predict-food"))
                .andRespond(withStatus(HttpStatus.BAD_REQUEST).contentType(MediaType.APPLICATION_JSON)
                        .body("{\"detail\":\"Invalid or corrupted image file.\"}"));

        assertThatThrownBy(() -> client().predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG))
                .isInstanceOfSatisfying(FoodVisionException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
                    assertThat(e.getMessage()).isEqualTo("Invalid or corrupted image file.");
                });
    }

    @Test
    void anOversizedImageAnswerIsA422Too() {
        server.expect(requestTo(BASE_URL + "/predict-food"))
                .andRespond(withStatus(HttpStatus.CONTENT_TOO_LARGE).contentType(MediaType.APPLICATION_JSON)
                        .body("{\"detail\":\"Image must be 5 MB or smaller.\"}"));

        assertThatThrownBy(() -> client().predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG))
                .isInstanceOfSatisfying(FoodVisionException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT));
    }

    @Test
    void aModelErrorIs502WithoutTheServiceText() {
        server.expect(requestTo(BASE_URL + "/predict-food"))
                .andRespond(withServerError().contentType(MediaType.APPLICATION_JSON)
                        .body("{\"detail\":\"Food classification failed.\"}"));

        assertThatThrownBy(() -> client().predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG))
                .isInstanceOfSatisfying(FoodVisionException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(e.getMessage()).isEqualTo("The food recognition service returned an invalid response");
                });
    }

    @Test
    void aServiceThatSaysItIsUnavailableIs503() {
        server.expect(requestTo(BASE_URL + "/predict-food")).andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE));

        assertThatThrownBy(() -> client().predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG))
                .isInstanceOfSatisfying(FoodVisionException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE));
    }

    @Test
    void aStoppedServiceIs503() {
        // Nothing listens on port 9 (discard); the connection is refused at once.
        FoodVisionProperties properties = new FoodVisionProperties("http://127.0.0.1:9", Duration.ofSeconds(1),
                Duration.ofSeconds(1));
        FoodVisionClient client = new FoodVisionClient(new AiClientConfig()
                .foodVisionRestClient(properties));

        assertThatThrownBy(() -> client.predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG))
                .isInstanceOfSatisfying(FoodVisionException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(e.getMessage()).isEqualTo("The food recognition service is currently unavailable");
                });
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "{\"success\":true,\"model\":\"ResNet50\",\"top_predictions\":[]}",
            "{\"success\":true,\"model\":\"ResNet50\"}",
            "{\"success\":false,\"model\":\"ResNet50\",\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":1.5}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":-0.1}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\"}]}",
            "{\"success\":true,\"top_predictions\":[{\"confidence\":0.9}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"<script>alert(1)</script>\",\"confidence\":0.9}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"Pizza Margherita\",\"confidence\":0.9}]}",
            "{\"success\":true,\"top_predictions\":[null]}",
            // Food regions: box outside the photo, upside down, wrong length; bad guesses; odd label; a null item.
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}],\"items\":[{\"box\":[0,0,1.2,1],\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}]}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}],\"items\":[{\"box\":[0.5,0,0.2,1],\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}]}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}],\"items\":[{\"box\":[0,0,1],\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}]}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}],\"items\":[{\"box\":[0,0,1,1],\"top_predictions\":[]}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}],\"items\":[{\"box\":[0,0,1,1],\"detector_label\":\"<b>\",\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}]}]}",
            "{\"success\":true,\"top_predictions\":[{\"food\":\"pizza\",\"confidence\":0.9}],\"items\":[null]}",
            "[]",
            "not json"
    })
    void anAnswerThatIsNotTheExpectedShapeIs502(String body) {
        server.expect(requestTo(BASE_URL + "/predict-food"))
                .andRespond(withSuccess(body, MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client().predict(IMAGE, "meal.jpg", MediaType.IMAGE_JPEG))
                .isInstanceOfSatisfying(FoodVisionException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY));
    }

    private FoodVisionClient client() {
        return new FoodVisionClient(builder.build());
    }
}
