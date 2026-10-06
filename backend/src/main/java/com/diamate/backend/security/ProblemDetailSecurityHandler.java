package com.diamate.backend.security;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.server.resource.web.BearerTokenAuthenticationEntryPoint;
import org.springframework.security.oauth2.server.resource.web.access.BearerTokenAccessDeniedHandler;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import tools.jackson.databind.ObjectMapper;

/**
 * Writes 401 (no or invalid token) and 403 (wrong role) as RFC 9457 problem details, in the same JSON shape
 * as GlobalExceptionHandler. These errors happen in the security filter chain, before any controller,
 * so @RestControllerAdvice cannot handle them.
 */
@Component
public class ProblemDetailSecurityHandler implements AuthenticationEntryPoint, AccessDeniedHandler {

    // Spring's defaults set the status and the standard "WWW-Authenticate: Bearer ..." header; we only add a body.
    private final BearerTokenAuthenticationEntryPoint bearerEntryPoint = new BearerTokenAuthenticationEntryPoint();
    private final BearerTokenAccessDeniedHandler bearerAccessDeniedHandler = new BearerTokenAccessDeniedHandler();
    private final ObjectMapper objectMapper;

    public ProblemDetailSecurityHandler(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /** 401: no token, or a token that is malformed, expired or signed with another key. */
    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
            AuthenticationException exception) throws IOException {
        bearerEntryPoint.commence(request, response, exception);
        // The exception message is not echoed: it can describe why a token was rejected.
        String detail = exception instanceof OAuth2AuthenticationException
                ? "Invalid or expired access token"
                : "Authentication required";
        write(request, response, HttpStatus.UNAUTHORIZED, detail);
    }

    /** 403: a valid token, but the user's role is not allowed to call this endpoint. */
    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
            AccessDeniedException exception) throws IOException {
        bearerAccessDeniedHandler.handle(request, response, exception);
        write(request, response, HttpStatus.FORBIDDEN, "You do not have permission to access this resource");
    }

    private void write(HttpServletRequest request, HttpServletResponse response, HttpStatus status, String detail)
            throws IOException {
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
