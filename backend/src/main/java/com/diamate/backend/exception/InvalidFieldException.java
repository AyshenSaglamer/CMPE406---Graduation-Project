package com.diamate.backend.exception;

/**
 * A field value that passed the annotations on the request but breaks a rule checked in the service
 * (for example a time in the future). Returned as 400 in the same shape as @Valid failures, with
 * "errors": {field: message}, so the app shows both kinds the same way.
 */
public class InvalidFieldException extends RuntimeException {

    private final String field;

    public InvalidFieldException(String field, String message) {
        super(message);
        this.field = field;
    }

    public String getField() {
        return field;
    }
}
