package com.diamate.backend.exception;

import java.time.Duration;

/**
 * Too many failed logins: the account is locked for a while (429 Too Many Requests + Retry-After header).
 * Thrown on the attempt that locks the account and on every attempt while the lock lasts.
 */
public class AccountLockedException extends RuntimeException {

    private final Duration retryAfter;

    public AccountLockedException(Duration retryAfter) {
        super("Too many failed login attempts. Try again in " + minutesText(retryAfter) + ".");
        this.retryAfter = retryAfter;
    }

    /** Time until the lock ends (at least one second). */
    public Duration getRetryAfter() {
        return retryAfter.isNegative() || retryAfter.isZero() ? Duration.ofSeconds(1) : retryAfter;
    }

    // Rounded up: 14 min 10 s left is shown as "15 minutes".
    private static String minutesText(Duration retryAfter) {
        long minutes = Math.max(1, (retryAfter.toSeconds() + 59) / 60);
        return minutes == 1 ? "1 minute" : minutes + " minutes";
    }
}
