package com.diamate.backend.exception;

/**
 * 404. Also used when a record exists but the caller may not see it (e.g. another patient's data),
 * so the response does not reveal whether the record exists.
 */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}
