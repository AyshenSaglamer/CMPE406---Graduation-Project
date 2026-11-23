package com.diamate.backend.exception;

/**
 * The request body is bigger than the backend accepts (413). Thrown by RequestSizeLimitFilter while the body is
 * being read, for requests that do not say their size in advance (no Content-Length header).
 */
public class RequestTooLargeException extends RuntimeException {

    public RequestTooLargeException(String message) {
        super(message);
    }
}
