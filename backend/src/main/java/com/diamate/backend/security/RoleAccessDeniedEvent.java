package com.diamate.backend.security;

/**
 * A logged-in user was refused because of their role (403). Published by ProblemDetailSecurityHandler and written to
 * the audit log by AuditService; an event, so the security handler does not depend on the database layer.
 *
 * @param path the request path without the query string
 */
public record RoleAccessDeniedEvent(long userId, String method, String path) {
}
