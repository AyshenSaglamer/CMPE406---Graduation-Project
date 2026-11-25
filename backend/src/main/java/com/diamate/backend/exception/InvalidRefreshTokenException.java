package com.diamate.backend.exception;

/**
 * POST /auth/refresh with a token that is unknown, expired, already used or from a session that was logged out.
 * One message for all of them; the app's answer is the same in every case: log in again.
 */
public class InvalidRefreshTokenException extends RuntimeException {

    public InvalidRefreshTokenException() {
        super("The refresh token is invalid or has expired; log in again");
    }
}
