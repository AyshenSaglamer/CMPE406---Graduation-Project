package com.diamate.backend.api.dto.response;

import java.util.List;

/**
 * Answer of POST /api/v1/ai/voice: what the speech-to-text heard (transcript) and what the assistant understood
 * from it, in the same form as /ai/parse (results). Nothing is saved; the app sends the confirmed results to
 * /patients/{id}/ai-entries.
 */
public record AiVoiceResponse(String status, String transcript, int resultCount, List<AiParseResponse.Entry> results,
        String message) {
}
