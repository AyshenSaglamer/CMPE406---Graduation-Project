package com.diamate.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import com.diamate.backend.exception.AiServiceException;

/**
 * Tests communication between Spring Boot and FastAPI.
 *
 * FastAPI itself is not started during these tests.
 * MockRestServiceServer simulates FastAPI responses.
 */
class AiClientTest {

    private static final String BASE_URL = "http://ai-service.test";

    @Test
    void parsesTheAiServiceAnswer() {

        RestClient.Builder builder =
                RestClient.builder().baseUrl(BASE_URL);

        MockRestServiceServer server =
                MockRestServiceServer.bindTo(builder).build();

        server.expect(
                        requestTo(
                                BASE_URL
                                        + "/api/v1/nlp/parse-multiple"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(
                        content().json(
                                "{\"text\":\"glucose 130 and 30 minutes walking\"}"))
                .andRespond(
                        withSuccess(
                                """
                                {
                                  "status":"SUCCESS",
                                  "input_type":"TEXT",
                                  "original_text":"glucose 130 and 30 minutes walking",
                                  "result_count":2,
                                  "results":[
                                    {
                                      "intent":"LOG_GLUCOSE",
                                      "value":130.0,
                                      "unit":"mg/dL",
                                      "status":"SUCCESS",
                                      "original_text":"glucose 130",
                                      "input_type":"TEXT"
                                    },
                                    {
                                      "intent":"LOG_ACTIVITY",
                                      "value":30.0,
                                      "unit":"minutes",
                                      "status":"SUCCESS",
                                      "original_text":"30 minutes walking",
                                      "input_type":"TEXT",
                                      "activity":"walking"
                                    }
                                  ]
                                }
                                """,
                                MediaType.APPLICATION_JSON));

        FastApiParseResult result =
                new AiClient(builder.build())
                        .parseMultiple(
                                "glucose 130 and 30 minutes walking");

        assertThat(result.status())
                .isEqualTo("SUCCESS");

        assertThat(result.results())
                .hasSize(2);

        assertThat(result.results().get(1).activity())
                .isEqualTo("walking");

        assertThat(result.results().get(1).value())
                .isEqualTo(30.0);

        server.verify();
    }

    @Test
    void predictionUsesCorrectFastApiEndpoint() {

        RestClient.Builder builder =
                RestClient.builder().baseUrl(BASE_URL);

        MockRestServiceServer server =
                MockRestServiceServer.bindTo(builder).build();

        FastApiPatientSummaryRequest request =
                new FastApiPatientSummaryRequest(
                        List.of(),
                        List.of(),
                        List.of(),
                        70.0,
                        180.0);

        server.expect(
                        requestTo(
                                BASE_URL
                                        + "/api/v1/integration/patient-prediction"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(
                        withSuccess(
                                """
                                {
                                  "prediction":"STABLE",
                                  "confidence":{
                                    "score":0.92,
                                    "level":"HIGH"
                                  },
                                  "uncertainty":{
                                    "score":0.08
                                  },
                                  "model_type":"XGBoost"
                                }
                                """,
                                MediaType.APPLICATION_JSON));

        Map<String, Object> response =
                new AiClient(builder.build())
                        .patientPrediction(request);

        assertThat(response)
                .containsEntry(
                        "prediction",
                        "STABLE");

        assertThat(response)
                .containsEntry(
                        "model_type",
                        "XGBoost");

        server.verify();
    }

    @Test
    void insufficientPredictionHistoryIsA422() {

        RestClient.Builder builder =
                RestClient.builder().baseUrl(BASE_URL);

        MockRestServiceServer server =
                MockRestServiceServer.bindTo(builder).build();

        FastApiPatientSummaryRequest request =
                new FastApiPatientSummaryRequest(
                        List.of(),
                        List.of(),
                        List.of(),
                        70.0,
                        180.0);

        server.expect(
                        requestTo(
                                BASE_URL
                                        + "/api/v1/integration/patient-prediction"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(
                        withStatus(
                                HttpStatus.UNPROCESSABLE_ENTITY)
                                .contentType(
                                        MediaType.APPLICATION_JSON)
                                .body(
                                        """
                                        {
                                          "detail":"At least three glucose readings are required for glucose-trend prediction."
                                        }
                                        """));

        assertThatThrownBy(
                        () ->
                                new AiClient(builder.build())
                                        .patientPrediction(request))
                .isInstanceOf(
                        AiServiceException.class)
                .hasMessage(
                        "At least three glucose readings are required for glucose-trend prediction.")
                .satisfies(
                        e ->
                                assertThat(
                                                ((AiServiceException) e)
                                                        .getStatus())
                                        .isEqualTo(
                                                HttpStatus.UNPROCESSABLE_ENTITY));

        server.verify();
    }

    @Test
    void aiService503RemainsA503() {

        RestClient.Builder builder =
                RestClient.builder().baseUrl(BASE_URL);

        MockRestServiceServer server =
                MockRestServiceServer.bindTo(builder).build();

        FastApiPatientSummaryRequest request =
                new FastApiPatientSummaryRequest(
                        List.of(),
                        List.of(),
                        List.of(),
                        70.0,
                        180.0);

        server.expect(
                        requestTo(
                                BASE_URL
                                        + "/api/v1/integration/patient-prediction"))
                .andRespond(
                        withStatus(
                                HttpStatus.SERVICE_UNAVAILABLE));

        assertThatThrownBy(
                        () ->
                                new AiClient(builder.build())
                                        .patientPrediction(request))
                .isInstanceOf(
                        AiServiceException.class)
                .hasMessage(
                        "The AI service is currently unavailable")
                .satisfies(
                        e ->
                                assertThat(
                                                ((AiServiceException) e)
                                                        .getStatus())
                                        .isEqualTo(
                                                HttpStatus.SERVICE_UNAVAILABLE));

        server.verify();
    }

    @Test
    void unexpectedAiServiceErrorIsA502() {

        RestClient.Builder builder =
                RestClient.builder().baseUrl(BASE_URL);

        MockRestServiceServer server =
                MockRestServiceServer.bindTo(builder).build();

        server.expect(
                        requestTo(
                                BASE_URL
                                        + "/api/v1/nlp/parse-multiple"))
                .andRespond(
                        withServerError());

        assertThatThrownBy(
                        () ->
                                new AiClient(builder.build())
                                        .parseMultiple(
                                                "glucose 130"))
                .isInstanceOf(
                        AiServiceException.class)
                .satisfies(
                        e ->
                                assertThat(
                                                ((AiServiceException) e)
                                                        .getStatus())
                                        .isEqualTo(
                                                HttpStatus.BAD_GATEWAY));

        server.verify();
    }

    @Test
    void unreachableAiServiceIsA503() {

        /*
         * Port 9 is normally closed, so the connection
         * should be refused immediately.
         */
        RestClient client =
                new AiClientConfig().aiRestClient(
                        new AiProperties(
                                "http://127.0.0.1:9",
                                Duration.ofSeconds(1),
                                Duration.ofSeconds(1)));

        assertThatThrownBy(
                        () ->
                                new AiClient(client)
                                        .parseMultiple(
                                                "glucose 130"))
                .isInstanceOf(
                        AiServiceException.class)
                .hasMessage(
                        "The AI service is currently unavailable")
                .satisfies(
                        e ->
                                assertThat(
                                                ((AiServiceException) e)
                                                        .getStatus())
                                        .isEqualTo(
                                                HttpStatus.SERVICE_UNAVAILABLE));
    }
}
