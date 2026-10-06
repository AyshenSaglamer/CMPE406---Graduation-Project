package com.diamate.backend.service;

import java.sql.SQLException;

import org.springframework.dao.DataIntegrityViolationException;

/** Tells database errors apart, so a 409 "already exists" is only answered when something really exists. */
final class DatabaseErrors {

    private static final String UNIQUE_VIOLATION = "23505"; // PostgreSQL SQLSTATE: duplicate key in a unique index

    private DatabaseErrors() {
    }

    /**
     * True only for a duplicate in a unique index. Other integrity errors (a broken CHECK, a missing foreign key
     * row, invalid text) are bugs and must not be reported to the client as "already exists".
     */
    static boolean isUniqueViolation(DataIntegrityViolationException exception) {
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof SQLException sql && UNIQUE_VIOLATION.equals(sql.getSQLState())) {
                return true;
            }
        }
        return false;
    }
}
