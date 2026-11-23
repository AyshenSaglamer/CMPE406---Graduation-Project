package com.diamate.backend.exception;

/** The request clashes with data that already exists (409). */
public class ResourceConflictException extends RuntimeException {

    public ResourceConflictException(String message) {
        super(message);
    }
}
