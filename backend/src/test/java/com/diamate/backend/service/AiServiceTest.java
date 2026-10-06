package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.diamate.backend.ai.AiClient;
import com.diamate.backend.ai.FastApiParseResult;
import com.diamate.backend.api.dto.response.AiParseResponse;

@ExtendWith(MockitoExtension.class)
class AiServiceTest {

    @Mock
    private AiClient aiClient;

    @InjectMocks
    private AiService service;

    @Test
    void entriesOfTheAiServiceArePassedOnAndTheTextIsTrimmed() {
        when(aiClient.parseMultiple("glucose 130 and 6 units of insulin")).thenReturn(new FastApiParseResult("SUCCESS",
                List.of(new FastApiParseResult.Entry("LOG_GLUCOSE", "SUCCESS", 130.0, "mg/dL", null, null),
                        new FastApiParseResult.Entry("LOG_INSULIN", "SUCCESS", 6.0, "units", null, null)),
                null));

        AiParseResponse response = service.parse("  glucose 130 and 6 units of insulin ");

        assertThat(response.status()).isEqualTo("SUCCESS");
        assertThat(response.resultCount()).isEqualTo(2);
        assertThat(response.results()).extracting(AiParseResponse.Entry::intent)
                .containsExactly("LOG_GLUCOSE", "LOG_INSULIN");
    }

    @Test
    void nothingUnderstoodIsAnEmptyList() {
        when(aiClient.parseMultiple("hello")).thenReturn(
                new FastApiParseResult("UNKNOWN", null, "I could not understand the input."));

        AiParseResponse response = service.parse("hello");

        assertThat(response.status()).isEqualTo("UNKNOWN");
        assertThat(response.results()).isEmpty();
        assertThat(response.message()).isEqualTo("I could not understand the input.");
    }
}
