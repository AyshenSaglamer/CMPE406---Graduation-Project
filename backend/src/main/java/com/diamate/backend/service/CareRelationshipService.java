package com.diamate.backend.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.CareInvitationRequest;
import com.diamate.backend.api.dto.request.CarePermissionsRequest;
import com.diamate.backend.api.dto.response.CareRelationshipResponse;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.exception.TooManyRequestsException;
import com.diamate.backend.repository.CareRelationshipRepository;
import com.diamate.backend.repository.CareRelationshipRepository.CareRelationshipRow;
import com.diamate.backend.repository.CareRelationshipRepository.Permissions;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.service.AuditService.CareChange;

/**
 * Patient-controlled sharing: the patient invites a clinician or caregiver, the member accepts or declines, the
 * patient changes what is shared, and either side can end it. Only an ACTIVE relationship gives access
 * (fn_can_access), so nothing is shared before the member accepts, and nothing after it is revoked.
 *
 * Status flow: PENDING -> ACTIVE | DECLINED, and PENDING | ACTIVE -> REVOKED. DECLINED and REVOKED are final; a new
 * invitation creates a new row (the old one stays as history).
 *
 * Who may do what (the role level is in CareRelationshipController, the rest is checked here):
 * - invite, change permissions: the patient of the relationship (role PATIENT)
 * - accept, decline: the invited member (role CLINICIAN or CAREGIVER)
 * - list, revoke: either side
 * A relationship the caller is not part of answers 404, the same as one that does not exist.
 *
 * Asking for the state a relationship is already in (accepting an ACTIVE one, revoking a REVOKED one) returns it
 * unchanged, so a retried request from the app is not an error. Every change is written to the audit log.
 *
 * Time-limited sharing: expires_at (optional) ends the access by itself at that moment; fn_can_access checks it on
 * every read. The status stays ACTIVE, so the response says hasAccess. The patient can move the end date or remove
 * it while the relationship is open, also after it has passed (a new invitation would be a 409 then).
 * Not @Transactional: each repository call has its own transaction, like AlertService.
 */
@Service
public class CareRelationshipService {

    private static final String NOT_FOUND = "Care relationship not found";
    private static final String ALREADY_OPEN = "This person already has a pending invitation or access";
    private static final String PENDING = "PENDING";
    private static final String ACTIVE = "ACTIVE";
    private static final String DECLINED = "DECLINED";
    private static final String REVOKED = "REVOKED";
    private static final Set<String> STATUSES = Set.of(PENDING, ACTIVE, DECLINED, REVOKED);

    /** The care_relationships column defaults: everything shared, recommendations only when the patient allows them. */
    static final Permissions DEFAULT_PERMISSIONS = new Permissions(true, true, true, true, true, true, false);

    /** Longest end date a patient can set; longer sharing simply has no end date. Also keeps the year in range. */
    static final Duration MAX_EXPIRY = Duration.ofDays(2 * 365);

    /** Invitation attempts a patient may make per day: enough for a care team, too few to probe emails or spam. */
    static final int MAX_INVITATION_ATTEMPTS_PER_DAY = 10;
    static final Duration INVITATION_WINDOW = Duration.ofDays(1);

    /** After a member declines, the same patient cannot invite them again for this long. */
    static final Duration DECLINE_COOLDOWN = Duration.ofDays(30);

    private final CareRelationshipRepository repository;
    private final UserRepository userRepository;
    private final AuditService auditService;
    private final Clock clock;

    public CareRelationshipService(CareRelationshipRepository repository, UserRepository userRepository,
            AuditService auditService, Clock clock) {
        this.repository = repository;
        this.userRepository = userRepository;
        this.auditService = auditService;
        this.clock = clock;
    }

    /**
     * The member must have an active CLINICIAN or CAREGIVER account. Any other case (no account, a patient's or an
     * admin's account, an inactive one, the patient's own email) is the same 404, so the endpoint does not say which
     * emails belong to patients. A second invitation while one is PENDING or ACTIVE is 409.
     *
     * Limits: every answer after the email lookup tells the patient something about that email (404: no clinician or
     * caregiver, 400 for recommendations: a caregiver, 201/409: a clinician or caregiver), so every attempt counts,
     * not only the invitations that were saved. At most MAX_INVITATION_ATTEMPTS_PER_DAY attempts per patient per day
     * (429, checked before the email is looked up). A refused attempt is written to the audit trail
     * (CARE_INVITE_REFUSED), which is also where the attempts are counted. No invitation to a member who declined
     * this patient in the last DECLINE_COOLDOWN (409).
     *
     * One transaction that starts by locking the patient's row: parallel invitations of one patient wait for each
     * other, so they cannot all pass the limit at once. noRollbackFor: the refused attempt's audit row must stay.
     */
    @Transactional(noRollbackFor = { ResourceNotFoundException.class, ResourceConflictException.class,
            InvalidFieldException.class, TooManyRequestsException.class })
    public CareRelationshipResponse invite(long patientId, CareInvitationRequest request) {
        Instant now = clock.instant();
        repository.lockPatientForInvitation(patientId);
        repository.nthLatestInvitationAttemptAt(patientId, MAX_INVITATION_ATTEMPTS_PER_DAY)
                .filter(at -> at.isAfter(now.minus(INVITATION_WINDOW)))
                .ifPresent(at -> {
                    throw new TooManyRequestsException("You can send at most " + MAX_INVITATION_ATTEMPTS_PER_DAY
                            + " invitations a day. Try again later.", Duration.between(now, at.plus(INVITATION_WINDOW)));
                });
        try {
            return createInvitation(patientId, request, now);
        } catch (ResourceNotFoundException | ResourceConflictException | InvalidFieldException refused) {
            auditService.careInvitationRefused(patientId, refused.getClass().getSimpleName());
            throw refused;
        }
    }

    private CareRelationshipResponse createInvitation(long patientId, CareInvitationRequest request, Instant now) {
        User member = userRepository.findByEmail(request.memberEmail().trim())
                .filter(User::isActive)
                .filter(user -> user.getRole() == Role.CLINICIAN || user.getRole() == Role.CAREGIVER)
                .filter(user -> user.getId() != patientId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "No active clinician or caregiver account with this email"));
        Permissions permissions = merge(DEFAULT_PERMISSIONS, request.canViewGlucose(), request.canViewMeals(),
                request.canViewMedications(), request.canViewActivity(), request.canViewReports(),
                request.canReceiveAlerts(), request.canAddRecommendations());
        checkRecommendations(member.getRole().name(), permissions);
        Instant expiresAt = request.expiresAt();
        checkExpiry(expiresAt);
        // Checked before the insert: a unique violation would abort this transaction, and the refused attempt
        // could then not be written to the audit trail.
        if (repository.hasOpenRelationship(patientId, member.getId())) {
            throw new ResourceConflictException(ALREADY_OPEN);
        }
        if (repository.declinedSince(patientId, member.getId(), now.minus(DECLINE_COOLDOWN))) {
            throw new ResourceConflictException("This person declined your invitation recently. Try again later.");
        }

        long id;
        try {
            id = repository.insertInvitation(patientId, member.getId(), member.getRole().name(), permissions,
                    patientId, expiresAt);
        } catch (DataIntegrityViolationException exception) {
            // Not reachable while the patient row is locked (the member side never inserts), kept as a safety net.
            if (DatabaseErrors.isUniqueViolation(exception)) {
                throw new ResourceConflictException(ALREADY_OPEN);
            }
            throw exception;
        }
        auditService.careRelationshipChanged(patientId, patientId, id, CareChange.CARE_INVITED,
                details(member.getId(), permissions, expiresAt));
        return response(find(id));
    }

    /** The caller's relationships, as patient and as member. status (PENDING, ACTIVE, DECLINED, REVOKED) is optional. */
    public List<CareRelationshipResponse> list(long userId, String status) {
        String normalized = null;
        if (status != null && !status.isBlank()) {
            normalized = status.trim().toUpperCase(Locale.ROOT);
            if (!STATUSES.contains(normalized)) {
                throw new InvalidFieldException("status", "Status must be PENDING, ACTIVE, DECLINED or REVOKED");
            }
        }
        Instant now = clock.instant();
        return repository.findForUser(userId, normalized).stream()
                .map(row -> CareRelationshipResponse.from(row, now)).toList();
    }

    public CareRelationshipResponse accept(long memberId, long id) {
        return answer(memberId, id, ACTIVE);
    }

    public CareRelationshipResponse decline(long memberId, long id) {
        return answer(memberId, id, DECLINED);
    }

    /**
     * Only the patient changes permissions and the end date, on a PENDING or ACTIVE relationship. Takes effect at
     * once.
     */
    public CareRelationshipResponse updatePermissions(long patientId, long id, CarePermissionsRequest request) {
        CareRelationshipRow current = repository.findById(id)
                .filter(row -> row.patientId() == patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
        if (!isOpen(current.status())) {
            throw closed(current.status());
        }
        Permissions permissions = merge(current.permissions(), request.canViewGlucose(), request.canViewMeals(),
                request.canViewMedications(), request.canViewActivity(), request.canViewReports(),
                request.canReceiveAlerts(), request.canAddRecommendations());
        checkRecommendations(current.memberRole(), permissions);
        Instant expiresAt = newExpiry(current.expiresAt(), request.expiresAt(), request.removeExpiry());
        if (permissions.equals(current.permissions()) && Objects.equals(expiresAt, current.expiresAt())) {
            return response(current);
        }
        if (repository.updatePermissionsIfOpen(id, patientId, permissions, expiresAt) == 0) {
            throw closed(find(id).status()); // revoked or declined a moment ago
        }
        auditService.careRelationshipChanged(patientId, patientId, id, CareChange.CARE_PERMISSIONS_CHANGED,
                details(current.memberId(), permissions, expiresAt));
        return response(find(id));
    }

    /**
     * The patient withdraws access or cancels an invitation, or the member leaves. Revoking a REVOKED relationship
     * is a no-op; a DECLINED one is 409 (it never started).
     */
    public void revoke(long userId, long id) {
        CareRelationshipRow current = findVisible(userId, id);
        if (REVOKED.equals(current.status())) {
            return;
        }
        if (!isOpen(current.status())) {
            throw closed(current.status());
        }
        if (repository.revokeIfOpen(id) == 0) {
            String now = find(id).status();
            if (REVOKED.equals(now)) {
                return;
            }
            throw closed(now);
        }
        auditService.careRelationshipChanged(userId, current.patientId(), id, CareChange.CARE_REVOKED,
                Map.of("memberId", String.valueOf(current.memberId()), "by",
                        userId == current.patientId() ? "PATIENT" : "MEMBER"));
    }

    /** Accept or decline: only the invited member, only while PENDING. */
    private CareRelationshipResponse answer(long memberId, long id, String newStatus) {
        CareRelationshipRow current = repository.findById(id)
                .filter(row -> row.memberId() == memberId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
        if (newStatus.equals(current.status())) {
            return response(current);
        }
        if (!PENDING.equals(current.status())) {
            throw closed(current.status());
        }
        int changed = ACTIVE.equals(newStatus) ? repository.acceptIfPending(id, memberId)
                : repository.declineIfPending(id, memberId);
        CareRelationshipRow after = find(id);
        if (changed == 0) {
            if (newStatus.equals(after.status())) {
                return response(after);
            }
            throw closed(after.status()); // e.g. the patient cancelled the invitation a moment ago
        }
        auditService.careRelationshipChanged(memberId, current.patientId(), id,
                ACTIVE.equals(newStatus) ? CareChange.CARE_ACCEPTED : CareChange.CARE_DECLINED,
                Map.of("memberId", String.valueOf(memberId)));
        return response(after);
    }

    private CareRelationshipResponse response(CareRelationshipRow row) {
        return CareRelationshipResponse.from(row, clock.instant());
    }

    /** null is fine (no end date); otherwise in the future and at most MAX_EXPIRY ahead. */
    private void checkExpiry(Instant expiresAt) {
        if (expiresAt == null) {
            return;
        }
        Instant now = clock.instant();
        if (!expiresAt.isAfter(now)) {
            throw new InvalidFieldException("expiresAt", "Must be in the future");
        }
        if (expiresAt.isAfter(now.plus(MAX_EXPIRY))) {
            throw new InvalidFieldException("expiresAt",
                    "Must be at most 2 years from now; leave it out for sharing without an end date");
        }
    }

    /** PATCH: a new end date, none (removeExpiry), or the current one when neither is sent. */
    private Instant newExpiry(Instant current, Instant requested, Boolean removeExpiry) {
        boolean remove = Boolean.TRUE.equals(removeExpiry);
        if (remove && requested != null) {
            throw new InvalidFieldException("expiresAt", "Send either expiresAt or removeExpiry, not both");
        }
        if (remove) {
            return null;
        }
        if (requested == null) {
            return current;
        }
        checkExpiry(requested);
        return requested;
    }

    private CareRelationshipRow findVisible(long userId, long id) {
        return repository.findById(id)
                .filter(row -> row.patientId() == userId || row.memberId() == userId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    private CareRelationshipRow find(long id) {
        return repository.findById(id).orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    private static boolean isOpen(String status) {
        return PENDING.equals(status) || ACTIVE.equals(status);
    }

    private static ResourceConflictException closed(String status) {
        // Locale.ROOT: with a Turkish default locale "DECLINED" would become "declıned".
        return new ResourceConflictException("Care relationship is already " + status.toLowerCase(Locale.ROOT));
    }

    /** Recommendations are a clinician's job (care_relationships comment: "clinicians only in practice"). */
    private static void checkRecommendations(String memberRole, Permissions permissions) {
        if (permissions.addRecommendations() && !Role.CLINICIAN.name().equals(memberRole)) {
            throw new InvalidFieldException("canAddRecommendations", "Only a clinician can add recommendations");
        }
    }

    private static Permissions merge(Permissions base, Boolean glucose, Boolean meals, Boolean medications,
            Boolean activity, Boolean reports, Boolean alerts, Boolean recommendations) {
        return new Permissions(
                glucose != null ? glucose : base.viewGlucose(),
                meals != null ? meals : base.viewMeals(),
                medications != null ? medications : base.viewMedications(),
                activity != null ? activity : base.viewActivity(),
                reports != null ? reports : base.viewReports(),
                alerts != null ? alerts : base.receiveAlerts(),
                recommendations != null ? recommendations : base.addRecommendations());
    }

    private static Map<String, String> details(long memberId, Permissions p, Instant expiresAt) {
        Map<String, String> details = new LinkedHashMap<>();
        details.put("memberId", String.valueOf(memberId));
        details.put("canViewGlucose", String.valueOf(p.viewGlucose()));
        details.put("canViewMeals", String.valueOf(p.viewMeals()));
        details.put("canViewMedications", String.valueOf(p.viewMedications()));
        details.put("canViewActivity", String.valueOf(p.viewActivity()));
        details.put("canViewReports", String.valueOf(p.viewReports()));
        details.put("canReceiveAlerts", String.valueOf(p.receiveAlerts()));
        details.put("canAddRecommendations", String.valueOf(p.addRecommendations()));
        details.put("expiresAt", expiresAt != null ? expiresAt.toString() : "none");
        return details;
    }
}
