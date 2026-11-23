package com.diamate.backend.api.controller;

import java.net.URI;

import org.springframework.boot.webmvc.error.ErrorController;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.http.HttpServletRequest;

/**
 * The server's /error page, for errors raised before any controller runs: e.g. Spring Security's firewall refusing
 * "/patients/1;DROP" or "/patients/.." (400). Spring Boot's own BasicErrorController answered them with
 * {"timestamp", "status", "error", "path"}; this one uses the same problem+json shape as every other error
 * (GlobalExceptionHandler), so the app has only one error format to read (Week 2 Day 6).
 */
@RestController
public class ProblemErrorController implements ErrorController {

    @RequestMapping("/error")
    public ResponseEntity<ProblemDetail> error(HttpServletRequest request) {
        // No status: /error was opened directly. It is not an API address.
        HttpStatusCode status = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE) instanceof Integer code
                ? HttpStatusCode.valueOf(code)
                : HttpStatus.NOT_FOUND;
        ProblemDetail body = ProblemDetail.forStatusAndDetail(status, detail(status));
        body.setInstance(originalUri(request));
        // Set here, not negotiated: the answer is problem+json even for a client that asked for text/html.
        return ResponseEntity.status(status).contentType(MediaType.APPLICATION_PROBLEM_JSON).body(body);
    }

    /** Fixed texts, like GlobalExceptionHandler: nothing about the server's internals. */
    private static String detail(HttpStatusCode status) {
        if (status.value() == HttpStatus.NOT_FOUND.value()) {
            return "Resource not found";
        }
        if (status.value() == HttpStatus.BAD_REQUEST.value()) {
            return "The request is not valid";
        }
        if (status.is5xxServerError()) {
            return "An unexpected error occurred";
        }
        HttpStatus known = HttpStatus.resolve(status.value());
        return known != null ? known.getReasonPhrase() : "The request could not be completed";
    }

    /** The address the client called (the request itself now points at /error), if it is a valid URI. */
    private static URI originalUri(HttpServletRequest request) {
        if (request.getAttribute(RequestDispatcher.ERROR_REQUEST_URI) instanceof String uri) {
            try {
                return URI.create(uri);
            } catch (IllegalArgumentException e) {
                return null;
            }
        }
        return null;
    }
}
