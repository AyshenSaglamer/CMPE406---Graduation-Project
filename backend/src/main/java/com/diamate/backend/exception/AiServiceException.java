package com.diamate.backend.exception;

import org.springframework.http.HttpStatus;

/**
 * The FastAPI AI service could not answer. 503 when it cannot be reached (down or too slow),
 * 502 when it answered with an error or an unreadable response.
 */
public class AiServiceException extends RuntimeException {

    private final HttpStatus status;

    private AiServiceException(HttpStatus status, String message, Throwable cause) {
        super(message, cause);
        this.status = status;
    }

    public static AiServiceException unavailable(Throwable cause) {
        return new AiServiceException(HttpStatus.SERVICE_UNAVAILABLE, "The AI service is currently unavailable", cause);
    }

    public static AiServiceException badResponse(Throwable cause) {
        return new AiServiceException(HttpStatus.BAD_GATEWAY, "The AI service returned an invalid response", cause);
    }

    public HttpStatus getStatus() {
        return status;
    }
}
