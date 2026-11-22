package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.diamate.backend.ai.AiClient;
import com.diamate.backend.ai.FastApiParseResult;
import com.diamate.backend.ai.FastApiPatientSummaryRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.AiParseResponse;
import com.diamate.backend.api.dto.response.GlucoseLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;

@ExtendWith(MockitoExtension.class)
class AiServiceTest {

    @Mock
    private AiClient aiClient;

    @Mock
    private GlucoseLogService glucoseLogService;

    @Mock
    private MealLogService mealLogService;

    @Mock
    private ActivityLogService activityLogService;

    @InjectMocks
    private AiService service;

    @Test
    void entriesOfTheAiServiceArePassedOnAndTheTextIsTrimmed() {

        when(aiClient.parseMultiple(
                "glucose 130 and 6 units of insulin"))
                .thenReturn(
                        new FastApiParseResult(
                                "SUCCESS",
                                List.of(
                                        new FastApiParseResult.Entry(
                                                "LOG_GLUCOSE",
                                                "SUCCESS",
                                                130.0,
                                                "mg/dL",
                                                null,
                                                null),
                                        new FastApiParseResult.Entry(
                                                "LOG_INSULIN",
                                                "SUCCESS",
                                                6.0,
                                                "units",
                                                null,
                                                null)),
                                null));

        AiParseResponse response =
                service.parse(
                        "  glucose 130 and 6 units of insulin ");

        assertThat(response.status())
                .isEqualTo("SUCCESS");

        assertThat(response.resultCount())
                .isEqualTo(2);

        assertThat(response.results())
                .extracting(
                        AiParseResponse.Entry::intent)
                .containsExactly(
                        "LOG_GLUCOSE",
                        "LOG_INSULIN");
    }

    @Test
    void nothingUnderstoodIsAnEmptyList() {

        when(aiClient.parseMultiple("hello"))
                .thenReturn(
                        new FastApiParseResult(
                                "UNKNOWN",
                                null,
                                "I could not understand the input."));

        AiParseResponse response =
                service.parse("hello");

        assertThat(response.status())
                .isEqualTo("UNKNOWN");

        assertThat(response.results())
                .isEmpty();

        assertThat(response.message())
                .isEqualTo(
                        "I could not understand the input.");
    }

    @Test
    void patientPredictionUsesAuthorizedPatientHistory() {

        long viewerId = 1L;
        long patientId = 1L;

        Instant from =
                Instant.parse(
                        "2026-11-14T00:00:00Z");

        Instant to =
                Instant.parse(
                        "2026-11-15T00:00:00Z");

        GlucoseLogResponse glucose =
                new GlucoseLogResponse(
                        14L,
                        patientId,
                        250,
                        Instant.parse(
                                "2026-11-14T08:00:00Z"),
                        null,
                        null,
                        null,
                        null,
                        Instant.parse(
                                "2026-11-22T09:00:00Z"),
                        Instant.parse(
                                "2026-11-22T09:00:00Z"));

        MealLogResponse meal =
                new MealLogResponse(
                        5L,
                        patientId,
                        null,
                        Instant.parse(
                                "2026-11-14T07:30:00Z"),
                        "Test breakfast",
                        BigDecimal.valueOf(45),
                        BigDecimal.valueOf(350),
                        BigDecimal.valueOf(15),
                        BigDecimal.valueOf(10),
                        null,
                        "AI integration test",
                        null,
                        Instant.parse(
                                "2026-11-22T09:42:39Z"),
                        Instant.parse(
                                "2026-11-22T09:42:39Z"));

        ActivityLogResponse activity =
                new ActivityLogResponse(
                        5L,
                        patientId,
                        "WALKING",
                        Instant.parse(
                                "2026-11-14T07:45:00Z"),
                        BigDecimal.valueOf(30),
                        3000,
                        105,
                        BigDecimal.valueOf(120),
                        null,
                        null,
                        "AI integration test",
                        null,
                        Instant.parse(
                                "2026-11-22T09:43:43Z"),
                        Instant.parse(
                                "2026-11-22T09:43:43Z"));

        when(glucoseLogService.list(
                viewerId,
                patientId,
                from,
                to,
                0,
                200))
                .thenReturn(
                        new PageResponse<>(
                                List.of(glucose),
                                0,
                                200,
                                1,
                                1));

        when(mealLogService.list(
                viewerId,
                patientId,
                from,
                to,
                0,
                200))
                .thenReturn(
                        new PageResponse<>(
                                List.of(meal),
                                0,
                                200,
                                1,
                                1));

        when(activityLogService.list(
                viewerId,
                patientId,
                from,
                to,
                0,
                200))
                .thenReturn(
                        new PageResponse<>(
                                List.of(activity),
                                0,
                                200,
                                1,
                                1));

        when(aiClient.patientPrediction(any()))
                .thenReturn(
                        Map.of(
                                "prediction",
                                "STABLE",
                                "model_type",
                                "XGBoost"));

        Map<String, Object> response =
                service.patientPrediction(
                        viewerId,
                        patientId,
                        from,
                        to,
                        70.0,
                        180.0);

        assertThat(response)
                .containsEntry(
                        "prediction",
                        "STABLE");

        assertThat(response)
                .containsEntry(
                        "model_type",
                        "XGBoost");

        ArgumentCaptor<FastApiPatientSummaryRequest> captor =
                ArgumentCaptor.forClass(
                        FastApiPatientSummaryRequest.class);

        verify(aiClient)
                .patientPrediction(
                        captor.capture());

        FastApiPatientSummaryRequest request =
                captor.getValue();

        assertThat(request.glucoseLogs())
                .hasSize(1);

        assertThat(request.mealLogs())
                .hasSize(1);

        assertThat(request.activityLogs())
                .hasSize(1);

        assertThat(
                request.glucoseLogs()
                        .get(0)
                        .glucoseValue())
                .isEqualTo(250);

        assertThat(
                request.mealLogs()
                        .get(0)
                        .carbsG())
                .isEqualByComparingTo(
                        BigDecimal.valueOf(45));

        assertThat(
                request.activityLogs()
                        .get(0)
                        .durationMinutes())
                .isEqualByComparingTo(
                        BigDecimal.valueOf(30));

        assertThat(request.rangeLow())
                .isEqualTo(70.0);

        assertThat(request.rangeHigh())
                .isEqualTo(180.0);

        verify(glucoseLogService)
                .list(
                        viewerId,
                        patientId,
                        from,
                        to,
                        0,
                        200);

        verify(mealLogService)
                .list(
                        viewerId,
                        patientId,
                        from,
                        to,
                        0,
                        200);

        verify(activityLogService)
                .list(
                        viewerId,
                        patientId,
                        from,
                        to,
                        0,
                        200);
    }
}
