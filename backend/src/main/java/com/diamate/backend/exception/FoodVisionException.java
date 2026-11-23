package com.diamate.backend.exception;

import org.springframework.http.HttpStatus;

/**
 * The food photo service (food-vision-service) could not answer. 503 when it cannot be reached (down or too slow),
 * 422 when it could not use the image, 502 when it answered with an error or an unreadable response.
 */
public class FoodVisionException extends RuntimeException {

    private final HttpStatus status;

    private FoodVisionException(HttpStatus status, String message, Throwable cause) {
        super(message, cause);
        this.status = status;
    }

    public static FoodVisionException unavailable(Throwable cause) {
        return new FoodVisionException(HttpStatus.SERVICE_UNAVAILABLE,
                "The food recognition service is currently unavailable", cause);
    }

    public static FoodVisionException badResponse(Throwable cause) {
        return new FoodVisionException(HttpStatus.BAD_GATEWAY,
                "The food recognition service returned an invalid response", cause);
    }

    /** detail: the service's own short explanation (checked by AiClient.detail), or null for a general text. */
    public static FoodVisionException unusableImage(String detail, Throwable cause) {
        return new FoodVisionException(HttpStatus.UNPROCESSABLE_CONTENT,
                detail != null ? detail : "The food recognition service could not use this image", cause);
    }

    public HttpStatus getStatus() {
        return status;
    }
}
