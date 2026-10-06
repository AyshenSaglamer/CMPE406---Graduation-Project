package com.diamate.backend.service;

import java.time.Instant;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.diamate.backend.repository.AuditLogRepository;

import jakarta.servlet.http.HttpServletRequest;
import tools.jackson.databind.ObjectMapper;

/**
 * Security audit trail in audit_logs: logins (successful, failed, account locked) and reads of a patient's data by
 * someone other than the patient. Every row also gets the client's IP address and User-Agent.
 * Never written: passwords, tokens or the health data itself.
 */
@Service
public class AuditService {

    static final String LOGIN = "LOGIN";
    static final String LOGIN_FAILED = "LOGIN_FAILED";
    static final String ACCOUNT_LOCKED = "ACCOUNT_LOCKED";
    static final String VIEW_PATIENT_DATA = "VIEW_PATIENT_DATA";

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

    @Transactional
    public void loginSucceeded(long userId) {
        write(userId, null, LOGIN, null, true, null);
    }

    /**
     * userId is null for an unknown email. The typed email itself is not stored: people sometimes type their
     * password into the email field by mistake.
     */
    @Transactional
    public void loginFailed(Long userId, LoginFailure reason) {
        write(userId, null, LOGIN_FAILED, null, false, Map.of("reason", reason.name()));
    }

    @Transactional
    public void accountLocked(long userId, Instant lockedUntil) {
        write(userId, null, ACCOUNT_LOCKED, null, true, Map.of("lockedUntil", lockedUntil.toString()));
    }

    /**
     * A clinician, caregiver (or anyone else) asked for a patient's data. allowed = false records a refused
     * attempt (no care relationship or permission), which is worth knowing too.
     */
    @Transactional
    public void patientDataViewed(long viewerId, long patientId, PatientDataType data, boolean allowed) {
        write(viewerId, patientId, VIEW_PATIENT_DATA, data.name(), allowed, null);
    }

    private void write(Long userId, Long patientId, String action, String entityType, boolean success,
            Map<String, String> details) {
        HttpServletRequest request = currentRequest();
        String ip = request != null ? request.getRemoteAddr() : null;
        String userAgent = request != null ? truncate(request.getHeader("User-Agent")) : null;
        String detailsJson = details != null ? objectMapper.writeValueAsString(details) : null;
        repository.insert(new AuditLogRepository.Entry(userId, patientId, action, entityType, success, detailsJson,
                ip, userAgent));
    }

    /** The HTTP request being handled on this thread, or null outside a request (e.g. in unit tests). */
    private static HttpServletRequest currentRequest() {
        return RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attributes
                ? attributes.getRequest()
                : null;
    }

    private static String truncate(String value) {
        return value != null && value.length() > USER_AGENT_MAX_LENGTH ? value.substring(0, USER_AGENT_MAX_LENGTH)
                : value;
    }
}
