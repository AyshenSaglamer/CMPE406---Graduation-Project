package com.diamate.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.diamate.backend.ai.AiClient;
import com.diamate.backend.ai.FastApiParseResult;
import com.diamate.backend.api.dto.response.AiParseResponse;

/**
 * AI assistant features that use the FastAPI service. Nothing is saved here on purpose: text recognition can be
 * wrong, so health data is only saved after the patient confirms it in the app (log endpoints, source AI_ASSISTANT).
 */
@Service
public class AiService {

    private final AiClient aiClient;

    public AiService(AiClient aiClient) {
        this.aiClient = aiClient;
    }

    public AiParseResponse parse(String text) {
        FastApiParseResult result = aiClient.parseMultiple(text.trim());
        List<AiParseResponse.Entry> entries = result.results() == null ? List.of()
                : result.results().stream()
                        .map(e -> new AiParseResponse.Entry(e.intent(), e.status(), e.value(), e.unit(), e.activity(),
                                e.message()))
                        .toList();
        return new AiParseResponse(result.status(), entries.size(), entries, result.message());
    }
}
