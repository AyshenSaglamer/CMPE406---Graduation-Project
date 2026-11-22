package com.diamate.backend.exception;

import org.springframework.http.HttpStatus;

/**
 * Represents errors that occur while communicating with
 * the FastAPI AI service.
 *
 * 422:
 * FastAPI successfully received the request but could not
 * perform the requested analysis because the supplied
 * patient data was insufficient or invalid.
 *
 * 503:
 * FastAPI cannot be reached or the AI model/service is
 * temporarily unavailable.
 *
 * 502:
 * FastAPI returned an unexpected error or an unreadable
 * response.
 */
public class AiServiceException extends RuntimeException {

    private final HttpStatus status;

    private AiServiceException(
            HttpStatus status,
            String message,
            Throwable cause) {

        super(message, cause);
        this.status = status;
    }

    /**
     * The AI service could not be reached or is temporarily
     * unavailable.
     */
    public static AiServiceException unavailable(
            Throwable cause) {

        return new AiServiceException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "The AI service is currently unavailable",
                cause);
    }

    /**
     * FastAPI rejected the supplied patient data because
     * the requested analysis could not be performed.
     *
     * Example:
     * insufficient glucose history for prediction.
     */
    public static AiServiceException unprocessable(
            String detail,
            Throwable cause) {

        String message =
                detail == null || detail.isBlank()
                        ? "The supplied patient data is insufficient or invalid for this AI analysis"
                        : detail;

        return new AiServiceException(
                HttpStatus.UNPROCESSABLE_ENTITY,
                message,
                cause);
    }

    /**
     * FastAPI returned an unexpected response.
     */
    public static AiServiceException badResponse(
            Throwable cause) {

        return new AiServiceException(
                HttpStatus.BAD_GATEWAY,
                "The AI service returned an invalid response",
                cause);
    }

    public HttpStatus getStatus() {
        return status;
    }
}
