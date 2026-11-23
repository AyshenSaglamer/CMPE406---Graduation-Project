package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

import java.sql.SQLException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.request.CareInvitationRequest;
import com.diamate.backend.api.dto.request.CarePermissionsRequest;
import com.diamate.backend.api.dto.response.CareRelationshipResponse;
import com.diamate.backend.entity.Gender;
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

@ExtendWith(MockitoExtension.class)
class CareRelationshipServiceTest {

    private static final long PATIENT = 5;
    private static final long CLINICIAN = 2;
    private static final long CAREGIVER = 4;
    private static final long OTHER = 9;
    private static final long ID = 70;
    private static final String DR_EMAIL = "dr@example.com";
    private static final Instant NOW = Instant.parse("2026-11-17T12:00:00Z");
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    @Mock
    private CareRelationshipRepository repository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private AuditService auditService;

    private CareRelationshipService service;

    @BeforeEach
    void setUp() {
        service = new CareRelationshipService(repository, userRepository, auditService, CLOCK);
    }

    // ---------- invite ----------

    @Test
    void patientInvitesClinicianWithDefaultPermissions() {
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));
        when(repository.insertInvitation(eq(PATIENT), eq(CLINICIAN), eq("CLINICIAN"), any(), eq(PATIENT), any()))
                .thenReturn(ID);
        when(repository.findById(ID)).thenReturn(Optional.of(row("PENDING", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        CareRelationshipResponse response = service.invite(PATIENT, invitation(" " + DR_EMAIL + " ", null, null));

        assertThat(response.status()).isEqualTo("PENDING");
        ArgumentCaptor<Permissions> saved = ArgumentCaptor.forClass(Permissions.class);
        verify(repository).insertInvitation(eq(PATIENT), eq(CLINICIAN), eq("CLINICIAN"), saved.capture(),
                eq(PATIENT), isNull());
        assertThat(saved.getValue()).isEqualTo(new Permissions(true, true, true, true, true, true, false));
        verify(auditService).careRelationshipChanged(eq(PATIENT), eq(PATIENT), eq(ID), eq(CareChange.CARE_INVITED),
                any());
    }

    @Test
    void theEleventhInvitationAttemptOfADayIs429BeforeTheEmailIsLookedUp() {
        // The 10th latest invitation was sent 2 hours ago: the limit frees up 22 hours from now.
        when(repository.nthLatestInvitationAttemptAt(PATIENT, CareRelationshipService.MAX_INVITATION_ATTEMPTS_PER_DAY))
                .thenReturn(Optional.of(NOW.minus(Duration.ofHours(2))));

        assertThatThrownBy(() -> service.invite(PATIENT, invitation(DR_EMAIL, null, null)))
                .isInstanceOf(TooManyRequestsException.class)
                .satisfies(e -> assertThat(((TooManyRequestsException) e).getRetryAfter())
                        .isEqualTo(Duration.ofHours(22)));
        verifyNoInteractions(userRepository);
        verify(repository, never()).insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any());
    }

    @Test
    void tenInvitationsSpreadOverMoreThanADayAreFine() {
        when(repository.nthLatestInvitationAttemptAt(PATIENT, CareRelationshipService.MAX_INVITATION_ATTEMPTS_PER_DAY))
                .thenReturn(Optional.of(NOW.minus(Duration.ofHours(25))));
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));
        when(repository.insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any())).thenReturn(ID);
        when(repository.findById(ID)).thenReturn(Optional.of(row("PENDING", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThat(service.invite(PATIENT, invitation(DR_EMAIL, null, null)).status()).isEqualTo("PENDING");
    }

    @Test
    void aMemberWhoDeclinedInTheLast30DaysCannotBeInvitedAgain() {
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));
        when(repository.declinedSince(PATIENT, CLINICIAN, NOW.minus(Duration.ofDays(30)))).thenReturn(true);

        assertThatThrownBy(() -> service.invite(PATIENT, invitation(DR_EMAIL, null, null)))
                .isInstanceOf(ResourceConflictException.class)
                .hasMessage("This person declined your invitation recently. Try again later.");
        verify(repository, never()).insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any());
    }

    @Test
    void aRefusedInvitationIsAuditedSoItCountsForTheDailyLimit() {
        when(userRepository.findByEmail("nobody@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.invite(PATIENT, invitation("nobody@example.com", null, null)))
                .isInstanceOf(ResourceNotFoundException.class);

        verify(repository).lockPatientForInvitation(PATIENT);
        verify(auditService).careInvitationRefused(PATIENT, "ResourceNotFoundException");
    }

    @Test
    void anInvitationToSomeoneAlreadyInvitedIs409WithoutTryingTheInsert() {
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));
        when(repository.hasOpenRelationship(PATIENT, CLINICIAN)).thenReturn(true);

        assertThatThrownBy(() -> service.invite(PATIENT, invitation(DR_EMAIL, null, null)))
                .isInstanceOf(ResourceConflictException.class)
                .hasMessage("This person already has a pending invitation or access");
        verify(repository, never()).insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any());
        verify(auditService).careInvitationRefused(PATIENT, "ResourceConflictException");
    }

    @Test
    void invitationKeepsTheFlagsThePatientChose() {
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));
        when(repository.insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any())).thenReturn(ID);
        when(repository.findById(ID)).thenReturn(Optional.of(row("PENDING", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        service.invite(PATIENT, invitation(DR_EMAIL, false, true));

        ArgumentCaptor<Permissions> saved = ArgumentCaptor.forClass(Permissions.class);
        verify(repository).insertInvitation(anyLong(), anyLong(), anyString(), saved.capture(), anyLong(), any());
        assertThat(saved.getValue().viewMeals()).isFalse();
        assertThat(saved.getValue().addRecommendations()).isTrue();
        assertThat(saved.getValue().viewGlucose()).isTrue();
    }

    @Test
    void unknownPatientAdminInactiveAndOwnEmailsAreAllTheSame404() {
        when(userRepository.findByEmail("nobody@example.com")).thenReturn(Optional.empty());
        when(userRepository.findByEmail("patient@example.com"))
                .thenReturn(Optional.of(user(OTHER, Role.PATIENT, true)));
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(user(1, Role.ADMIN, true)));
        when(userRepository.findByEmail("off@example.com")).thenReturn(Optional.of(user(OTHER, Role.CLINICIAN, false)));
        when(userRepository.findByEmail("me@example.com")).thenReturn(Optional.of(user(PATIENT, Role.CAREGIVER, true)));

        for (String email : List.of("nobody@example.com", "patient@example.com", "admin@example.com",
                "off@example.com", "me@example.com")) {
            assertThatThrownBy(() -> service.invite(PATIENT, invitation(email, null, null)))
                    .as(email).isInstanceOf(ResourceNotFoundException.class)
                    .hasMessage("No active clinician or caregiver account with this email");
        }
        verify(repository, never()).insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any());
        // Each refused attempt is audited (and so counted for the daily limit), with the same reason for all five.
        verify(auditService, times(5)).careInvitationRefused(PATIENT, "ResourceNotFoundException");
        verifyNoMoreInteractions(auditService);
    }

    @Test
    void caregiverCannotBeGivenRecommendations() {
        when(userRepository.findByEmail("care@example.com")).thenReturn(Optional.of(user(CAREGIVER, Role.CAREGIVER, true)));

        assertThatThrownBy(() -> service.invite(PATIENT, invitation("care@example.com", null, true)))
                .isInstanceOf(InvalidFieldException.class)
                .extracting(e -> ((InvalidFieldException) e).getField()).isEqualTo("canAddRecommendations");
    }

    @Test
    void secondOpenInvitationForTheSamePersonIs409() {
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));
        when(repository.insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any()))
                .thenThrow(new DataIntegrityViolationException("dup", new SQLException("dup", "23505")));

        assertThatThrownBy(() -> service.invite(PATIENT, invitation(DR_EMAIL, null, null)))
                .isInstanceOf(ResourceConflictException.class);
        verify(auditService).careInvitationRefused(PATIENT, "ResourceConflictException");
        verifyNoMoreInteractions(auditService);
    }

    // ---------- list ----------

    @Test
    void listNormalizesStatusAndRejectsUnknownOnes() {
        when(repository.findForUser(CLINICIAN, "PENDING")).thenReturn(List.of(row("PENDING", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThat(service.list(CLINICIAN, "pending")).hasSize(1);
        assertThatThrownBy(() -> service.list(CLINICIAN, "OPEN")).isInstanceOf(InvalidFieldException.class);
    }

    // ---------- accept / decline ----------

    @Test
    void invitedMemberAccepts() {
        when(repository.findById(ID)).thenReturn(
                Optional.of(row("PENDING", "CLINICIAN", CLINICIAN, CareRelationshipService.DEFAULT_PERMISSIONS)),
                Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN, CareRelationshipService.DEFAULT_PERMISSIONS)));
        when(repository.acceptIfPending(ID, CLINICIAN)).thenReturn(1);

        assertThat(service.accept(CLINICIAN, ID).status()).isEqualTo("ACTIVE");
        verify(auditService).careRelationshipChanged(eq(CLINICIAN), eq(PATIENT), eq(ID), eq(CareChange.CARE_ACCEPTED),
                any());
    }

    @Test
    void someoneElsesInvitationIs404AndThePatientCannotAcceptIt() {
        when(repository.findById(ID)).thenReturn(
                Optional.of(row("PENDING", "CLINICIAN", CLINICIAN, CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThatThrownBy(() -> service.accept(OTHER, ID)).isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.accept(PATIENT, ID)).isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).acceptIfPending(anyLong(), anyLong());
    }

    @Test
    void acceptingTwiceReturnsItUnchangedButACancelledInvitationIs409() {
        when(repository.findById(ID)).thenReturn(
                Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN, CareRelationshipService.DEFAULT_PERMISSIONS)));
        assertThat(service.accept(CLINICIAN, ID).status()).isEqualTo("ACTIVE");

        when(repository.findById(ID)).thenReturn(
                Optional.of(row("REVOKED", "CLINICIAN", CLINICIAN, CareRelationshipService.DEFAULT_PERMISSIONS)));
        assertThatThrownBy(() -> service.accept(CLINICIAN, ID)).isInstanceOf(ResourceConflictException.class)
                .hasMessage("Care relationship is already revoked");
        verify(repository, never()).acceptIfPending(anyLong(), anyLong());
        verifyNoInteractions(auditService);
    }

    @Test
    void patientCancelledWhileMemberWasAccepting() {
        when(repository.findById(ID)).thenReturn(
                Optional.of(row("PENDING", "CLINICIAN", CLINICIAN, CareRelationshipService.DEFAULT_PERMISSIONS)),
                Optional.of(row("REVOKED", "CLINICIAN", CLINICIAN, CareRelationshipService.DEFAULT_PERMISSIONS)));
        when(repository.acceptIfPending(ID, CLINICIAN)).thenReturn(0);

        assertThatThrownBy(() -> service.accept(CLINICIAN, ID)).isInstanceOf(ResourceConflictException.class);
        verifyNoInteractions(auditService);
    }

    @Test
    void invitedMemberDeclines() {
        when(repository.findById(ID)).thenReturn(
                Optional.of(row("PENDING", "CAREGIVER", CAREGIVER, CareRelationshipService.DEFAULT_PERMISSIONS)),
                Optional.of(row("DECLINED", "CAREGIVER", CAREGIVER, CareRelationshipService.DEFAULT_PERMISSIONS)));
        when(repository.declineIfPending(ID, CAREGIVER)).thenReturn(1);

        assertThat(service.decline(CAREGIVER, ID).status()).isEqualTo("DECLINED");
        verify(auditService).careRelationshipChanged(eq(CAREGIVER), eq(PATIENT), eq(ID),
                eq(CareChange.CARE_DECLINED), any());
    }

    // ---------- permissions ----------

    @Test
    void patientChangesOnlyTheFlagsSent() {
        Permissions before = CareRelationshipService.DEFAULT_PERMISSIONS;
        when(repository.findById(ID)).thenReturn(Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN, before)));
        when(repository.updatePermissionsIfOpen(eq(ID), eq(PATIENT), any(), any())).thenReturn(1);

        service.updatePermissions(PATIENT, ID,
                new CarePermissionsRequest(null, false, null, null, null, null, null, null, null));

        ArgumentCaptor<Permissions> saved = ArgumentCaptor.forClass(Permissions.class);
        verify(repository).updatePermissionsIfOpen(eq(ID), eq(PATIENT), saved.capture(), isNull());
        assertThat(saved.getValue()).isEqualTo(new Permissions(true, false, true, true, true, true, false));
        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, String>> details = ArgumentCaptor.forClass(Map.class);
        verify(auditService).careRelationshipChanged(eq(PATIENT), eq(PATIENT), eq(ID),
                eq(CareChange.CARE_PERMISSIONS_CHANGED), details.capture());
        assertThat(details.getValue()).containsEntry("canViewMeals", "false");
    }

    @Test
    void memberCannotChangePermissionsAndUnchangedFlagsWriteNothing() {
        when(repository.findById(ID)).thenReturn(Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));
        CarePermissionsRequest sameAsNow =
                new CarePermissionsRequest(true, null, null, null, null, null, null, null, null);

        assertThatThrownBy(() -> service.updatePermissions(CLINICIAN, ID, sameAsNow))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThat(service.updatePermissions(PATIENT, ID, sameAsNow).status()).isEqualTo("ACTIVE");
        verify(repository, never()).updatePermissionsIfOpen(anyLong(), anyLong(), any(), any());
        verifyNoInteractions(auditService);
    }

    @Test
    void permissionsOfAClosedRelationshipCannotChange() {
        when(repository.findById(ID)).thenReturn(Optional.of(row("REVOKED", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThatThrownBy(() -> service.updatePermissions(PATIENT, ID,
                new CarePermissionsRequest(false, null, null, null, null, null, null, null, null)))
                .isInstanceOf(ResourceConflictException.class);
    }

    // ---------- revoke ----------

    @Test
    void eitherSideCanRevokeAndTheAuditSaysWho() {
        when(repository.findById(ID)).thenReturn(Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));
        when(repository.revokeIfOpen(ID)).thenReturn(1);

        service.revoke(PATIENT, ID);
        service.revoke(CLINICIAN, ID);

        verify(auditService).careRelationshipChanged(PATIENT, PATIENT, ID, CareChange.CARE_REVOKED,
                Map.of("memberId", String.valueOf(CLINICIAN), "by", "PATIENT"));
        verify(auditService).careRelationshipChanged(CLINICIAN, PATIENT, ID, CareChange.CARE_REVOKED,
                Map.of("memberId", String.valueOf(CLINICIAN), "by", "MEMBER"));
    }

    @Test
    void strangerCannotRevokeAndRevokingTwiceIsANoOp() {
        when(repository.findById(ID)).thenReturn(Optional.of(row("REVOKED", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThatThrownBy(() -> service.revoke(OTHER, ID)).isInstanceOf(ResourceNotFoundException.class);
        service.revoke(PATIENT, ID);

        verify(repository, never()).revokeIfOpen(anyLong());
        verifyNoInteractions(auditService);
    }

    @Test
    void declinedInvitationCannotBeRevoked() {
        when(repository.findById(ID)).thenReturn(Optional.of(row("DECLINED", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThatThrownBy(() -> service.revoke(PATIENT, ID)).isInstanceOf(ResourceConflictException.class);
    }

    // ---------- time-limited sharing ----------

    @Test
    void invitationCanEndAtAGivenTime() {
        Instant inAWeek = NOW.plus(Duration.ofDays(7));
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CAREGIVER, Role.CAREGIVER, true)));
        when(repository.insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any())).thenReturn(ID);
        when(repository.findById(ID)).thenReturn(Optional.of(row("PENDING", "CAREGIVER", CAREGIVER,
                CareRelationshipService.DEFAULT_PERMISSIONS, inAWeek)));

        CareRelationshipResponse response = service.invite(PATIENT, invitationUntil(inAWeek));

        assertThat(response.expiresAt()).isEqualTo(inAWeek);
        assertThat(response.hasAccess()).isFalse(); // not accepted yet
        verify(repository).insertInvitation(PATIENT, CAREGIVER, "CAREGIVER",
                CareRelationshipService.DEFAULT_PERMISSIONS, PATIENT, inAWeek);
        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, String>> details = ArgumentCaptor.forClass(Map.class);
        verify(auditService).careRelationshipChanged(eq(PATIENT), eq(PATIENT), eq(ID), eq(CareChange.CARE_INVITED),
                details.capture());
        assertThat(details.getValue()).containsEntry("expiresAt", inAWeek.toString());
    }

    @Test
    void endDateMustBeInTheFuture() {
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));

        for (Instant wrong : List.of(NOW, NOW.minusSeconds(1), Instant.parse("1900-01-01T00:00:00Z"))) {
            assertThatThrownBy(() -> service.invite(PATIENT, invitationUntil(wrong)))
                    .isInstanceOfSatisfying(InvalidFieldException.class, e -> {
                        assertThat(e.getField()).isEqualTo("expiresAt");
                        assertThat(e.getMessage()).isEqualTo("Must be in the future");
                    });
        }
        verify(repository, never()).insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any());
    }

    @Test
    void endDateIsAtMostTwoYearsAhead() {
        when(userRepository.findByEmail(DR_EMAIL)).thenReturn(Optional.of(user(CLINICIAN, Role.CLINICIAN, true)));
        when(repository.insertInvitation(anyLong(), anyLong(), anyString(), any(), anyLong(), any())).thenReturn(ID);
        when(repository.findById(ID)).thenReturn(Optional.of(row("PENDING", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        service.invite(PATIENT, invitationUntil(NOW.plus(CareRelationshipService.MAX_EXPIRY))); // exactly the limit

        for (Instant tooFar : List.of(NOW.plus(CareRelationshipService.MAX_EXPIRY).plusSeconds(1),
                Instant.parse("+1000000000-01-01T00:00:00Z"))) { // a year the database could not store
            assertThatThrownBy(() -> service.invite(PATIENT, invitationUntil(tooFar)))
                    .isInstanceOfSatisfying(InvalidFieldException.class,
                            e -> assertThat(e.getField()).isEqualTo("expiresAt"));
        }
    }

    @Test
    void patientExtendsAnExpiredRelationshipAndAccessComesBack() {
        Instant expired = NOW.minus(Duration.ofHours(1));
        Instant inAMonth = NOW.plus(Duration.ofDays(30));
        Permissions permissions = CareRelationshipService.DEFAULT_PERMISSIONS;
        when(repository.findById(ID)).thenReturn(
                Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN, permissions, expired)),
                Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN, permissions, inAMonth)));
        when(repository.updatePermissionsIfOpen(ID, PATIENT, permissions, inAMonth)).thenReturn(1);

        CareRelationshipResponse response = service.updatePermissions(PATIENT, ID, until(inAMonth));

        assertThat(response.expiresAt()).isEqualTo(inAMonth);
        assertThat(response.hasAccess()).isTrue();
        verify(auditService).careRelationshipChanged(eq(PATIENT), eq(PATIENT), eq(ID),
                eq(CareChange.CARE_PERMISSIONS_CHANGED), any());
    }

    @Test
    void patientRemovesTheEndDate() {
        Permissions permissions = CareRelationshipService.DEFAULT_PERMISSIONS;
        when(repository.findById(ID)).thenReturn(
                Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN, permissions, NOW.plus(Duration.ofDays(3)))),
                Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN, permissions)));
        when(repository.updatePermissionsIfOpen(ID, PATIENT, permissions, null)).thenReturn(1);

        CareRelationshipResponse response = service.updatePermissions(PATIENT, ID,
                new CarePermissionsRequest(null, null, null, null, null, null, null, null, true));

        assertThat(response.expiresAt()).isNull();
        verify(repository).updatePermissionsIfOpen(ID, PATIENT, permissions, null);
    }

    @Test
    void changingAPermissionKeepsTheEndDate() {
        Instant inAWeek = NOW.plus(Duration.ofDays(7));
        when(repository.findById(ID)).thenReturn(Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS, inAWeek)));
        when(repository.updatePermissionsIfOpen(eq(ID), eq(PATIENT), any(), any())).thenReturn(1);

        service.updatePermissions(PATIENT, ID,
                new CarePermissionsRequest(null, false, null, null, null, null, null, null, null));

        verify(repository).updatePermissionsIfOpen(eq(ID), eq(PATIENT), any(), eq(inAWeek));
    }

    @Test
    void sameEndDateAndPermissionsChangeNothing() {
        Instant inAWeek = NOW.plus(Duration.ofDays(7));
        when(repository.findById(ID)).thenReturn(Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS, inAWeek)));

        service.updatePermissions(PATIENT, ID, until(inAWeek));

        verify(repository, never()).updatePermissionsIfOpen(anyLong(), anyLong(), any(), any());
        verifyNoInteractions(auditService);
    }

    @Test
    void endDateAndRemoveExpiryTogetherAre400() {
        when(repository.findById(ID)).thenReturn(Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThatThrownBy(() -> service.updatePermissions(PATIENT, ID, new CarePermissionsRequest(
                null, null, null, null, null, null, null, NOW.plus(Duration.ofDays(1)), true)))
                .isInstanceOfSatisfying(InvalidFieldException.class,
                        e -> assertThat(e.getField()).isEqualTo("expiresAt"));
        verify(repository, never()).updatePermissionsIfOpen(anyLong(), anyLong(), any(), any());
    }

    @Test
    void pastEndDateInAPatchIs400() {
        when(repository.findById(ID)).thenReturn(Optional.of(row("ACTIVE", "CLINICIAN", CLINICIAN,
                CareRelationshipService.DEFAULT_PERMISSIONS)));

        assertThatThrownBy(() -> service.updatePermissions(PATIENT, ID, until(NOW.minusSeconds(60))))
                .isInstanceOfSatisfying(InvalidFieldException.class,
                        e -> assertThat(e.getField()).isEqualTo("expiresAt"));
    }

    @Test
    void hasAccessIsActiveAndNotExpired() {
        Permissions p = CareRelationshipService.DEFAULT_PERMISSIONS;
        when(repository.findForUser(PATIENT, null)).thenReturn(List.of(
                row("ACTIVE", "CLINICIAN", CLINICIAN, p),                                  // no end date
                row("ACTIVE", "CLINICIAN", CLINICIAN, p, NOW.plusSeconds(1)),              // ends soon
                row("ACTIVE", "CLINICIAN", CLINICIAN, p, NOW),                             // ends right now
                row("ACTIVE", "CLINICIAN", CLINICIAN, p, NOW.minus(Duration.ofDays(1))),   // ended
                row("PENDING", "CLINICIAN", CLINICIAN, p),
                row("REVOKED", "CLINICIAN", CLINICIAN, p),
                row("DECLINED", "CLINICIAN", CLINICIAN, p)));

        assertThat(service.list(PATIENT, null)).extracting(CareRelationshipResponse::hasAccess)
                .containsExactly(true, true, false, false, false, false, false);
    }

    // ---------- helpers ----------

    private static CareInvitationRequest invitation(String email, Boolean meals, Boolean recommendations) {
        return new CareInvitationRequest(email, null, meals, null, null, null, null, recommendations, null);
    }

    private static User user(long id, Role role, boolean active) {
        User user = new User("First", "Last", LocalDate.of(1980, 1, 1), Gender.OTHER, role, "x@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", id);
        user.changeActive(active);
        return user;
    }

    private static CareInvitationRequest invitationUntil(Instant expiresAt) {
        return new CareInvitationRequest(DR_EMAIL, null, null, null, null, null, null, null, expiresAt);
    }

    private static CarePermissionsRequest until(Instant expiresAt) {
        return new CarePermissionsRequest(null, null, null, null, null, null, null, expiresAt, null);
    }

    private static CareRelationshipRow row(String status, String memberRole, long memberId, Permissions permissions) {
        return row(status, memberRole, memberId, permissions, null);
    }

    private static CareRelationshipRow row(String status, String memberRole, long memberId, Permissions permissions,
            Instant expiresAt) {
        return new CareRelationshipRow(ID, PATIENT, "Ayse", "Kaya", memberId, "Mehmet", "Demir", DR_EMAIL, memberRole,
                status, permissions, PATIENT, Instant.parse("2026-11-17T10:00:00Z"), null, null, expiresAt);
    }
}
