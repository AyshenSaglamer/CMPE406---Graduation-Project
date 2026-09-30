package com.diamate.backend.exception;

/**
 * Thrown for an unknown email AND for a wrong password, with the same message,
 * so a caller cannot find out which emails are registered.
 */
public class InvalidCredentialsException extends RuntimeException {

    public InvalidCredentialsException() {
        super("Invalid email or password");
    }
}
