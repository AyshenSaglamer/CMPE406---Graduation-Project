package com.diamate.backend.ai;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/**
 * Answer of the AI service's POST /api/v1/nlp/parse-multiple (Python, snake_case JSON). Only used between the
 * backend and the AI service; the app gets AiParseResponse. Unknown fields (input_type, original_text, result_count)
 * are ignored, so new fields on the Python side do not break the backend.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record FastApiParseResult(
        String status,
        List<Entry> results,
        String message) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Entry(String intent, String status, Double value, String unit, String activity, String message) {
    }
}
