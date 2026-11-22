package com.diamate.backend.ai;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/**
 * Answer of ai-service's POST /api/v1/voice/parse: Whisper's transcript and the same multi-intent NLP result as
 * /api/v1/nlp/parse-multiple. Fields not needed here (input_type, result_count) are ignored.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record FastApiVoiceResult(String status, String transcript, List<FastApiParseResult.Entry> results,
        String message) {
}
