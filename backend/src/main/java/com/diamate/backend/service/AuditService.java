package com.diamate.backend.service;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.repository.AuditLogRepository;
import com.diamate.backend.security.RoleAccessDeniedEvent;

import jakarta.servlet.http.HttpServletRequest;
import tools.jackson.databind.ObjectMapper;

/**
 * Security audit trail in audit_logs: registrations, logins (successful, failed, account locked), reads of a
 * patient's data by someone other than the patient, corrections and deletions of health logs, alert status changes,
 * care relationship changes (invited, accepted, declined, permissions changed, revoked), account (de)activations by an
 * ADMIN, requests refused because of the role (403) and an ADMIN reading the audit trail itself.
 * Every row also gets the client's IP address and User-Agent.
 * Never written: passwords, tokens or the health data itself (a corrected glucose log is recorded as "log 42 was
 * changed", not with its old or new value).
 *
 * The audit_logs table is append-only: a database trigger (audit_logs_immutable) refuses UPDATE, DELETE and TRUNCATE.
 * A method called inside a transaction joins it, so a change and its audit row are committed (or rolled back) together.
 */
@Service
public class AuditService {

    static final String LOGIN = "LOGIN";
    static final String LOGIN_FAILED = "LOGIN_FAILED";
    static final String ACCOUNT_LOCKED = "ACCOUNT_LOCKED";
    static final String VIEW_PATIENT_DATA = "VIEW_PATIENT_DATA";
    static final String ALERT_STATUS_CHANGED = "ALERT_STATUS_CHANGED";
    static final String ACCOUNT_STATUS_CHANGED = "ACCOUNT_STATUS_CHANGED";
    static final String REGISTER = "REGISTER";
    static final String ACCESS_DENIED = "ACCESS_DENIED";
    static final String AUDIT_LOG_VIEWED = "AUDIT_LOG_VIEWED";
    static final String CARE_INVITE_REFUSED = "CARE_INVITE_REFUSED";
    static final String LOGOUT = "LOGOUT";
    static final String REFRESH_TOKEN_REUSED = "REFRESH_TOKEN_REUSED";

    /** Longest request path stored for ACCESS_DENIED; a path is short in practice, an attacker's may not be. */
    static final int PATH_MAX_LENGTH = 200;

    private static final int USER_AGENT_MAX_LENGTH = 255; // audit_logs.user_agent is varchar(255)

    /** Why a login failed (stored in details.reason). */
    public enum LoginFailure {
        UNKNOWN_EMAIL,
        WRONG_PASSWORD,
        ACCOUNT_LOCKED,
        ACCOUNT_DISABLED
    }

    private final AuditLogRepository repository;
    private final ObjectMapper objectMapper;

    public AuditService(AuditLogRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    /** A new account (role, and whether it starts active). */
    @Transactional
    public void registered(long userId, String role, boolean active) {
        write(userId, null, REGISTER, "USER", String.valueOf(userId), true,
                ordered("role", role, "active", String.valueOf(active)));
    }

    @Transactional
    public void loginSucceeded(long userId) {
        write(userId, null, LOGIN, null, null, true, null);
    }

    /**
     * userId is null for an unknown email. The typed email itself is not stored: people sometimes type their
     * password into the email field by mistake.
     */
    @Transactional
    public void loginFailed(Long userId, LoginFailure reason) {
        write(userId, null, LOGIN_FAILED, null, null, false, Map.of("reason", reason.name()));
    }

    @Transactional
    public void loggedOut(long userId, java.util.UUID sessionId) {
        write(userId, null, LOGOUT, "AUTH_SESSION", sessionId.toString(), true, null);
    }

    /**
     * A refresh token that had already been replaced came back: someone else has a copy of it. The session has been
     * closed; success = false marks it as a security event next to LOGIN_FAILED and ACCESS_DENIED.
     */
    @Transactional
    public void refreshTokenReused(long userId, java.util.UUID sessionId) {
        write(userId, null, REFRESH_TOKEN_REUSED, "AUTH_SESSION", sessionId.toString(), false, null);
    }

    @Transactional
    public void accountLocked(long userId, Instant lockedUntil) {
        write(userId, null, ACCOUNT_LOCKED, null, null, true, Map.of("lockedUntil", lockedUntil.toString()));
    }

    /**
     * A clinician, caregiver (or anyone else) asked for a patient's data. allowed = false records a refused
     * attempt (no care relationship or permission), which is worth knowing too.
     */
    @Transactional
    public void patientDataViewed(long viewerId, long patientId, PatientDataType data, boolean allowed) {
        write(viewerId, patientId, VIEW_PATIENT_DATA, data.name(), null, allowed, null);
    }

    /** Someone acknowledged or resolved a patient's alert (who, whose, which alert, from which status to which). */
    @Transactional
    public void alertStatusChanged(long userId, long patientId, long alertId, AlertStatus from, AlertStatus to) {
        write(userId, patientId, ALERT_STATUS_CHANGED, "ALERT", String.valueOf(alertId), true,
                Map.of("from", from.name(), "to", to.name()));
    }

    /** An ADMIN activated or deactivated an account (e.g. stopped a compromised account). */
    @Transactional
    public void accountStatusChanged(long adminId, long userId, boolean active) {
        write(adminId, null, ACCOUNT_STATUS_CHANGED, "USER", String.valueOf(userId), true,
                Map.of("active", String.valueOf(active)));
    }

    /** What happened to a health log (the action). Creating one is recorded in the row itself (entered_by). */
    public enum HealthLogChange {
        HEALTH_LOG_UPDATED,
        HEALTH_LOG_DELETED
    }

    /**
     * A glucose, insulin, meal or activity log was corrected or deleted. Without this row a soft-deleted log only
     * says when it was deleted, not by whom. entity_type is the data type (GLUCOSE_LOGS, ...), the same names as
     * VIEW_PATIENT_DATA uses; the values themselves are not stored.
     */
    @Transactional
    public void healthLogChanged(long userId, long patientId, PatientDataType data, long logId,
            HealthLogChange change) {
        write(userId, patientId, change.name(), data.name(), String.valueOf(logId), true, null);
    }

    /**
     * A logged-in user called an endpoint their role may not use (403). Worth seeing: a patient token probing admin
     * endpoints is a sign of a stolen or tampered token. Only method and path are kept (no query string, no body).
     */
    @Transactional
    public void accessDenied(long userId, String method, String path) {
        String shortPath = path != null && path.length() > PATH_MAX_LENGTH ? path.substring(0, PATH_MAX_LENGTH) : path;
        write(userId, null, ACCESS_DENIED, null, null, false,
                ordered("method", String.valueOf(method), "path", String.valueOf(shortPath)));
    }

    @EventListener
    @Transactional
    public void onAccessDenied(RoleAccessDeniedEvent event) {
        accessDenied(event.userId(), event.method(), event.path());
    }

    /** An ADMIN listed audit rows; the filters used are kept, so reading the trail leaves a trace as well. */
    @Transactional
    public void auditLogViewed(long adminId, Map<String, String> filters) {
        write(adminId, null, AUDIT_LOG_VIEWED, null, null, true, filters);
    }

    /** What happened to a care relationship (stored as the action, e.g. CARE_INVITED). */
    public enum CareChange {
        CARE_INVITED,
        CARE_ACCEPTED,
        CARE_DECLINED,
        CARE_PERMISSIONS_CHANGED,
        CARE_REVOKED
    }

    /**
     * Who shares a patient's data with whom changed. details: the member and, for an invitation or a permission
     * change, the new permissions (can_* = true/false). Same table as data reads, so "who could see this patient,
     * since when" can be answered from audit_logs alone.
     */
    @Transactional
    public void careRelationshipChanged(long userId, long patientId, long relationshipId, CareChange change,
            Map<String, String> details) {
        write(userId, patientId, change.name(), "CARE_RELATIONSHIP", String.valueOf(relationshipId), true, details);
    }

    /**
     * A patient's invitation was refused (no such member, already invited or declined recently, invalid flags).
     * Counted for the daily invitation limit. The email is not stored: only why it was refused.
     */
    @Transactional
    public void careInvitationRefused(long patientId, String reason) {
        write(patientId, null, CARE_INVITE_REFUSED, "CARE_RELATIONSHIP", null, false, Map.of("reason", reason));
    }

    private void write(Long userId, Long patientId, String action, String entityType, String entityId,
            boolean success, Map<String, String> details) {
        HttpServletRequest request = currentRequest();
        String ip = request != null ? request.getRemoteAddr() : null;
        String userAgent = request != null ? truncate(request.getHeader("User-Agent")) : null;
        String detailsJson = details != null ? objectMapper.writeValueAsString(details) : null;
        repository.insert(new AuditLogRepository.Entry(userId, patientId, action, entityType, entityId, success,
                detailsJson, ip, userAgent));
    }

    /** The HTTP request being handled on this thread, or null outside a request (e.g. in unit tests). */
    private static HttpServletRequest currentRequest() {
        return RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attributes
                ? attributes.getRequest()
                : null;
    }

    /** Two keys in this order (Map.of has no order, and a stable JSON is easier to read and search). */
    private static Map<String, String> ordered(String key1, String value1, String key2, String value2) {
        Map<String, String> map = new LinkedHashMap<>();
        map.put(key1, value1);
        map.put(key2, value2);
        return map;
    }

    private static String truncate(String value) {
        return value != null && value.length() > USER_AGENT_MAX_LENGTH ? value.substring(0, USER_AGENT_MAX_LENGTH)
                : value;
    }
}
