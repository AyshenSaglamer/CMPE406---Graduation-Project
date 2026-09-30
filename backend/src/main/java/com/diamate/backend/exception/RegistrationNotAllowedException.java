package com.diamate.backend.exception;

public class RegistrationNotAllowedException extends RuntimeException {

    public RegistrationNotAllowedException(String message) {
        super(message);
    }
}
