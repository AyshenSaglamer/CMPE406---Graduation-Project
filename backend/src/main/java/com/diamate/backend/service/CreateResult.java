package com.diamate.backend.service;

/**
 * Result of a create request. created = false when the same clientUuid was already saved: the existing log is
 * returned (200) instead of a new one (201), so a request resent after a network error is not saved twice.
 */
public record CreateResult<T>(T log, boolean created) {

    public static <T> CreateResult<T> created(T log) {
        return new CreateResult<>(log, true);
    }

    public static <T> CreateResult<T> existing(T log) {
        return new CreateResult<>(log, false);
    }
}
