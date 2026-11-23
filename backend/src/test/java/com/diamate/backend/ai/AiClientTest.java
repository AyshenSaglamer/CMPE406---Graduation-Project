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

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import com.diamate.backend.exception.AiServiceException;

/**
 * The FastAPI service is not running in tests: MockRestServiceServer answers instead of it. The JSON below is
 * the real shape of ai-service's /api/v1/nlp/parse-multiple answer (snake_case, extra fields included).
 */
class AiClientTest {

    private static final String BASE_URL = "http://ai-service.test";

    @Test
    void parsesTheAiServiceAnswer() {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + "/api/v1/nlp/parse-multiple"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(content().json("{\"text\":\"glucose 130 and 30 minutes walking\"}"))
                .andRespond(withSuccess("""
                        {"status":"SUCCESS","input_type":"TEXT","original_text":"glucose 130 and 30 minutes walking",
                         "result_count":2,"results":[
                          {"intent":"LOG_GLUCOSE","value":130.0,"unit":"mg/dL","status":"SUCCESS",
                           "original_text":"glucose 130","input_type":"TEXT"},
                          {"intent":"LOG_ACTIVITY","value":30.0,"unit":"minutes","status":"SUCCESS",
                           "original_text":"30 minutes walking","input_type":"TEXT","activity":"walking"}]}
                        """, MediaType.APPLICATION_JSON));

        FastApiParseResult result = new AiClient(builder.build()).parseMultiple("glucose 130 and 30 minutes walking");

        assertThat(result.status()).isEqualTo("SUCCESS");
        assertThat(result.results()).hasSize(2);
        assertThat(result.results().get(1).activity()).isEqualTo("walking");
        assertThat(result.results().get(1).value()).isEqualTo(30.0);
        server.verify();
    }

    @Test
    void errorAnswerOfTheAiServiceIsA502() {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + "/api/v1/nlp/parse-multiple")).andRespond(withServerError());

        assertThatThrownBy(() -> new AiClient(builder.build()).parseMultiple("glucose 130"))
                .isInstanceOf(AiServiceException.class)
                .satisfies(e -> assertThat(((AiServiceException) e).getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY));
    }

    /** Field names and formats of ai-service's BackendHistoryRequest (models/integration_schemas.py). */
    @Test
    void patientSummarySendsTheFieldsTheAiServiceExpects() {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + "/api/v1/integration/patient-summary"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(content().json("""
                        {"glucoseLogs":[{"id":1,"patientId":5,"glucoseValue":140,
                                         "measurementTime":"2026-10-05T08:00:00Z",
                                         "clientUuid":"8a6e0804-2bd0-4672-b79d-d97027f9071a"}],
                         "mealLogs":[{"id":10,"patientId":5,"eatenAt":"2026-10-05T07:30:00Z","carbsG":45.5,
                                      "clientUuid":null}],
                         "activityLogs":[{"id":20,"patientId":5,"startedAt":"2026-10-05T09:00:00Z",
                                          "durationMinutes":30,"clientUuid":null}],
                         "rangeLow":70.0,"rangeHigh":180.0}
                        """, true))
                .andRespond(withSuccess("""
                        {"status":"SUCCESS","summary":{"average_glucose":140.0}}
                        """, MediaType.APPLICATION_JSON));

        Map<String, Object> summary = new AiClient(builder.build()).patientSummary(new FastApiPatientSummaryRequest(
                List.of(new FastApiPatientSummaryRequest.Glucose(1, 5, 140, Instant.parse("2026-10-05T08:00:00Z"),
                        UUID.fromString("8a6e0804-2bd0-4672-b79d-d97027f9071a"))),
                List.of(new FastApiPatientSummaryRequest.Meal(10, 5, Instant.parse("2026-10-05T07:30:00Z"),
                        new BigDecimal("45.5"), null)),
                List.of(new FastApiPatientSummaryRequest.Activity(20, 5, Instant.parse("2026-10-05T09:00:00Z"),
                        new BigDecimal("30"), null)),
                70, 180));

        assertThat(summary).containsEntry("status", "SUCCESS");
        server.verify();
    }

    @Test
    void patientSummaryRejectedByTheAiServiceWithoutDetailIsA422WithAGeneralText() {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + "/api/v1/integration/patient-summary"))
                .andRespond(withStatus(HttpStatus.valueOf(422)));

        assertThatThrownBy(() -> new AiClient(builder.build())
                .patientSummary(new FastApiPatientSummaryRequest(List.of(), List.of(), List.of(), 70, 180)))
                .isInstanceOfSatisfying(AiServiceException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
                    assertThat(e.getMessage()).isEqualTo("The AI service could not process this request");
                });
    }

    @Test
    void unreachableAiServiceIsA503() {
        // Port 9 ("discard") is closed on normal machines: the connection is refused at once.
        RestClient client = new AiClientConfig().aiRestClient(
                new AiProperties("http://127.0.0.1:9", Duration.ofSeconds(1), Duration.ofSeconds(1), Duration.ofSeconds(1)));

        assertThatThrownBy(() -> new AiClient(client).parseMultiple("glucose 130"))
                .isInstanceOf(AiServiceException.class)
                .hasMessage("The AI service is currently unavailable")
                .satisfies(e -> assertThat(((AiServiceException) e).getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE));
    }

    // ---------- analyses ----------

    @ParameterizedTest
    @EnumSource(AiAnalysis.class)
    void eachAnalysisIsPostedToItsOwnAddressAndAnsweredUnchanged(AiAnalysis analysis) {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + analysis.path()))
                .andExpect(method(HttpMethod.POST))
                .andExpect(content().json("{\"rangeLow\":70.0,\"rangeHigh\":180.0}"))
                .andRespond(withSuccess("{\"status\":\"SUCCESS\",\"trend\":\"STABLE\",\"confidence\":0.7}",
                        MediaType.APPLICATION_JSON));

        Map<String, Object> answer = new AiClient(builder.build()).patientAnalysis(analysis,
                new FastApiPatientSummaryRequest(List.of(), List.of(), List.of(), 70, 180));

        assertThat(answer).containsEntry("trend", "STABLE").containsEntry("confidence", 0.7);
        server.verify();
    }

    @Test
    void aShortExplanationOfThe422IsPassedOn() {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + AiAnalysis.ANOMALY.path()))
                .andRespond(withStatus(HttpStatus.valueOf(422)).contentType(MediaType.APPLICATION_JSON)
                        .body("""
                                {"status":"ERROR","error":{"code":"INVALID_INPUT","message":"At least seven glucose \
                                readings are required to generate six aggregated patient-history records for \
                                personalized anomaly detection."}}"""));

        assertThatThrownBy(() -> new AiClient(builder.build()).patientAnalysis(AiAnalysis.ANOMALY,
                new FastApiPatientSummaryRequest(List.of(), List.of(), List.of(), 70, 180)))
                .isInstanceOfSatisfying(AiServiceException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
                    assertThat(e.getMessage()).isEqualTo("At least seven glucose readings are required to generate six "
                            + "aggregated patient-history records for personalized anomaly detection.");
                });
    }

    @Test
    void onlyAShortPlainDetailIsPassedOn() {
        assertThat(AiClient.detail("{\"status\":\"ERROR\",\"error\":{\"code\":\"INVALID_INPUT\",\"message\":\"Too few.\"}}"))
                .isEqualTo("Too few.");
        assertThat(AiClient.detail("{\"detail\":\"Too few readings.\"}")).isEqualTo("Too few readings.");
        // Pydantic's error list, long texts, control characters, other JSON or no JSON: the general text instead.
        assertThat(AiClient.detail("{\"detail\":[{\"loc\":[\"body\",\"glucoseLogs\"],\"msg\":\"x\"}]}")).isNull();
        assertThat(AiClient.detail("{\"detail\":\"" + "x".repeat(AiClient.MAX_DETAIL_LENGTH + 1) + "\"}")).isNull();
        assertThat(AiClient.detail("{\"detail\":\"line1\\nTraceback ...\"}")).isNull();
        assertThat(AiClient.detail("{\"detail\":\"  \"}")).isNull();
        assertThat(AiClient.detail("{\"message\":\"x\"}")).isNull();
        assertThat(AiClient.detail("<html>Bad Gateway</html>")).isNull();
        assertThat(AiClient.detail(null)).isNull();
    }

    @Test
    void unavailableAnswerIsA503AndOtherErrorsA502() {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + AiAnalysis.PREDICTION.path()))
                .andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE));
        server.expect(requestTo(BASE_URL + AiAnalysis.PREDICTION.path()))
                .andRespond(withServerError().body("{\"detail\":\"Patient-history prediction failed.\"}"));
        AiClient client = new AiClient(builder.build());
        FastApiPatientSummaryRequest request = new FastApiPatientSummaryRequest(List.of(), List.of(), List.of(), 70, 180);

        assertThatThrownBy(() -> client.patientAnalysis(AiAnalysis.PREDICTION, request))
                .isInstanceOfSatisfying(AiServiceException.class,
                        e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE));
        assertThatThrownBy(() -> client.patientAnalysis(AiAnalysis.PREDICTION, request))
                .isInstanceOfSatisfying(AiServiceException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(e.getMessage()).isEqualTo("The AI service returned an invalid response");
                });
    }

    // ---------- voice ----------

    @Test
    void voiceIsSentAsMultipartThroughTheVoiceClient() {
        RestClient.Builder general = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer generalServer = MockRestServiceServer.bindTo(general).build();
        RestClient.Builder voice = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer voiceServer = MockRestServiceServer.bindTo(voice).build();
        voiceServer.expect(requestTo(BASE_URL + "/api/v1/voice/parse"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header("Content-Type", startsWith("multipart/form-data")))
                .andExpect(content().string(containsString("name=\"audio\"; filename=\"recording.m4a\"")))
                .andExpect(content().string(containsString("Content-Type: audio/mp4")))
                .andRespond(withSuccess("""
                        {"status":"SUCCESS","input_type":"VOICE","transcript":"my glucose is 145","result_count":1,
                         "results":[{"intent":"LOG_GLUCOSE","value":145.0,"unit":"mg/dL","status":"SUCCESS"}]}
                        """, MediaType.APPLICATION_JSON));

        FastApiVoiceResult result = new AiClient(general.build(), voice.build())
                .parseVoice(new byte[] { 1, 2, 3 }, "recording.m4a", MediaType.parseMediaType("audio/mp4"));

        assertThat(result.transcript()).isEqualTo("my glucose is 145");
        assertThat(result.results()).singleElement().satisfies(e -> assertThat(e.value()).isEqualTo(145.0));
        voiceServer.verify();
        generalServer.verify(); // nothing went through the client with the short timeout
    }

    @Test
    void speechThatCouldNotBeRecognisedIsA422WithTheReason() {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE_URL);
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo(BASE_URL + "/api/v1/voice/parse"))
                .andRespond(withStatus(HttpStatus.valueOf(422)).contentType(MediaType.APPLICATION_JSON)
                        .body("{\"status\":\"ERROR\",\"error\":{\"code\":\"INVALID_INPUT\",\"message\":\"Transcript cannot be empty.\"}}"));

        assertThatThrownBy(() -> new AiClient(builder.build())
                .parseVoice(new byte[] { 1 }, "recording.wav", MediaType.parseMediaType("audio/wav")))
                .isInstanceOfSatisfying(AiServiceException.class,
                        e -> assertThat(e.getMessage()).isEqualTo("Transcript cannot be empty."));
    }
}
