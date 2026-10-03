package com.diamate.backend.api.controller;

import java.time.Instant;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.response.HealthResponse;

@RestController // It tells Spring, "This class is an API controller.
@RequestMapping("/api/v1/health") // The common address prefix for all endpoints in this class.
public class HealthController {

    @GetMapping // This binds the method to an HTTP GET request. Since no address is specified, it uses the class's address exactly as is: GET /api/health.
    public HealthResponse health() {
        return new HealthResponse("UP", "diamate-backend", Instant.now());
    }
    
}