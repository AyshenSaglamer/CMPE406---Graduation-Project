package com.diamate.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.time.Duration;

import org.junit.jupiter.api.Test;
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

    @Test
    void unreachableAiServiceIsA503() {
        // Port 9 ("discard") is closed on normal machines: the connection is refused at once.
        RestClient client = new AiClientConfig().aiRestClient(
                new AiProperties("http://127.0.0.1:9", Duration.ofSeconds(1), Duration.ofSeconds(1)));

        assertThatThrownBy(() -> new AiClient(client).parseMultiple("glucose 130"))
                .isInstanceOf(AiServiceException.class)
                .hasMessage("The AI service is currently unavailable")
                .satisfies(e -> assertThat(((AiServiceException) e).getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE));
    }
}
