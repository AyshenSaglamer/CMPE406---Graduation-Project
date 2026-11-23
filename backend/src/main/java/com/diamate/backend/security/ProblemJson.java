package com.diamate.backend.security;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import tools.jackson.databind.ObjectMapper;

/**
 * Writes an RFC 9457 problem detail from a filter, in the same JSON shape as GlobalExceptionHandler.
 * Filters run before any controller, so @RestControllerAdvice cannot handle their errors.
 */
final class ProblemJson {

    private ProblemJson() {
    }

    static void write(ObjectMapper objectMapper, HttpServletRequest request, HttpServletResponse response,
            HttpStatus status, String detail) throws IOException {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("detail", detail);
        body.put("instance", request.getRequestURI());
        body.put("status", status.value());
        body.put("title", status.getReasonPhrase());
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        objectMapper.writeValue(response.getOutputStream(), body);
    }
}
