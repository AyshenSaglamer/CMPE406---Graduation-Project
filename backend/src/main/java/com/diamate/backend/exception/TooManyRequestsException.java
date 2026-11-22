package com.diamate.backend.exception;

import java.time.Duration;

/**
 * A limit on how often something may be done was reached (429 Too Many Requests + Retry-After header), e.g. the
 * number of care invitations a patient may send per day.
 */
public class TooManyRequestsException extends RuntimeException {

    private final Duration retryAfter;

    public TooManyRequestsException(String message, Duration retryAfter) {
        super(message);
        this.retryAfter = retryAfter;
    }

    /** Time until the next attempt is allowed (at least one second). */
    public Duration getRetryAfter() {
        return retryAfter.isNegative() || retryAfter.isZero() ? Duration.ofSeconds(1) : retryAfter;
    }
}
