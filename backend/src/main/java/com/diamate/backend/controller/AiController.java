package com.diamate.backend.controller;

import com.diamate.backend.dto.AiParseRequest;
import com.diamate.backend.service.AiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/ai")
public class AiController {

    private final AiService aiService;

    public AiController(AiService aiService) {
        this.aiService = aiService;
    }

    @PostMapping("/parse")
    public ResponseEntity<Map<String, Object>> parseText(
            @RequestBody AiParseRequest request
    ) {
        Map<String, Object> result =
                aiService.parseText(request.getText());

        return ResponseEntity.ok(result);
    }
}
