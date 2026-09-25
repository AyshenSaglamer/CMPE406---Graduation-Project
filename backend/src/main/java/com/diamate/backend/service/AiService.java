package com.diamate.backend.service;

import com.diamate.backend.dto.AiParseRequest;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

@Service
public class AiService {

    private final RestClient restClient;

    public AiService() {
        this.restClient = RestClient.builder()
                .baseUrl("http://localhost:8000")
                .build();
    }

    public Map<String, Object> parseText(String text) {
        AiParseRequest request = new AiParseRequest(text);

        return restClient.post()
                .uri("/api/v1/nlp/parse")
                .body(request)
                .retrieve()
                .body(Map.class);
    }
}
