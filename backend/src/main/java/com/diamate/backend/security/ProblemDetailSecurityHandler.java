package com.diamate.backend.security;

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.jwt.Jwt;
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
    private static final Logger log = LoggerFactory.getLogger(ProblemDetailSecurityHandler.class);

    private final ObjectMapper objectMapper;
    private final ApplicationEventPublisher events;

    public ProblemDetailSecurityHandler(ObjectMapper objectMapper, ApplicationEventPublisher events) {
        this.objectMapper = objectMapper;
        this.events = events;
    }

    /** 401: no token, or a token that is malformed, expired, signed with another key or of a disabled account. */
    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
            AuthenticationException exception) throws IOException {
        bearerEntryPoint.commence(request, response, exception);
        // The exception message is not echoed: it can describe why a token was rejected.
        String detail = exception instanceof OAuth2AuthenticationException
                ? "Invalid or expired access token"
                : "Authentication required";
        ProblemJson.write(objectMapper, request, response, HttpStatus.UNAUTHORIZED, detail);
    }

    /** 403: a valid token, but the user's role is not allowed to call this endpoint. */
    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
            AccessDeniedException exception) throws IOException {
        bearerAccessDeniedHandler.handle(request, response, exception);
        auditRefusal(request);
        ProblemJson.write(objectMapper, request, response, HttpStatus.FORBIDDEN,
                "You do not have permission to access this resource");
    }

    /** Audit log (ACCESS_DENIED). A failed audit write is logged but must not turn the 403 into another answer. */
    private void auditRefusal(HttpServletRequest request) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof Jwt jwt)) {
            return;
        }
        try {
            events.publishEvent(new RoleAccessDeniedEvent(CurrentUser.id(jwt), request.getMethod(),
                    request.getRequestURI()));
        } catch (RuntimeException e) {
            log.error("Could not write the ACCESS_DENIED audit row", e);
        }
    }
}
