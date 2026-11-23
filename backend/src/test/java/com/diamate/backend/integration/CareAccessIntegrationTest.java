package com.diamate.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import com.diamate.backend.api.dto.request.CareInvitationRequest;
import com.diamate.backend.api.dto.request.CarePermissionsRequest;
import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.api.dto.response.AccessLogEntryResponse;
import com.diamate.backend.api.dto.response.PatientOverviewResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.exception.TooManyRequestsException;
import com.diamate.backend.service.AiService;
import com.diamate.backend.service.AuditLogService;
import com.diamate.backend.service.CareRelationshipService;
import com.diamate.backend.service.HealthDataAccess;
import com.diamate.backend.service.PatientDataType;
import com.diamate.backend.service.PatientService;

/** Care sharing rules with the real database: fn_can_access, the access-log SQL, the invitation limits and locks. */
class CareAccessIntegrationTest extends PostgresIntegrationTest {

    @Autowired
    private CareRelationshipService care;

    @Autowired
    private PatientService patients;

    @Autowired
    private AiService ai;

    @Autowired
    private HealthDataAccess access;

    @Autowired
    private AuditLogService auditLog;

    @Autowired
    private NamedParameterJdbcTemplate jdbc;

    @Test
    void aMemberWithGlucoseButWithoutReportsGets404ForTheAiSummary() {
        long patient = register("Pia", Role.PATIENT);
        String doctorEmail = email("Doc");
        long doctor = registerWithEmail("Doc", Role.CLINICIAN, doctorEmail);
        share(patient, doctor, doctorEmail, glucoseOnly());

        assertThat(access.canRead(doctor, patient, PatientDataType.GLUCOSE_LOGS)).isTrue();
        assertThatThrownBy(() -> ai.patientSummary(doctor, patient, null, null, 70, 180))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void theOverviewHidesTherapyTypeAndOpenAlertsWithoutTheirPermissions() {
        long patient = register("Pia", Role.PATIENT);
        String doctorEmail = email("Doc");
        long doctor = registerWithEmail("Doc", Role.CLINICIAN, doctorEmail);
        long relationship = share(patient, doctor, doctorEmail, glucoseOnly());

        PatientOverviewResponse limited = patients.getOverview(doctor, patient);
        assertThat(limited.openAlerts()).isNull();
        assertThat(limited.therapyType()).isNull();
        assertThat(patients.getOverview(patient, patient).openAlerts()).isZero(); // the patient sees their own

        care.updatePermissions(patient, relationship, new CarePermissionsRequest(
                null, null, null, null, null, true, null, null, null));
        assertThat(patients.getOverview(doctor, patient).openAlerts()).isZero();
    }

    @Test
    void theAccessLogShowsRefusedReadsOfTheCareTeamButNotOfStrangersOrFormerMembers() {
        long patient = register("Pia", Role.PATIENT);
        long stranger = register("Stranger", Role.PATIENT);
        String doctorEmail = email("Doc");
        long doctor = registerWithEmail("Doc", Role.CLINICIAN, doctorEmail);
        long relationship = share(patient, doctor, doctorEmail, glucoseOnly());

        assertThat(access.canRead(stranger, patient, PatientDataType.GLUCOSE_LOGS)).isFalse();
        assertThat(access.canRead(doctor, patient, PatientDataType.MEAL_LOGS)).isFalse();

        assertThat(refusedReadsBy(patient, stranger)).isZero(); // still in audit_logs for the ADMIN, not here
        assertThat(refusedReadsBy(patient, doctor)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE user_id = :u AND patient_id = :p",
                Map.of("u", stranger, "p", patient), Long.class)).isEqualTo(1);

        // The doctor left the care team more than 30 days ago: their refused attempts no longer fill the log.
        jdbc.update("UPDATE care_relationships SET status = 'REVOKED', revoked_at = now() - INTERVAL '40 days' "
                + "WHERE id = :id", Map.of("id", relationship));
        assertThat(access.canRead(doctor, patient, PatientDataType.MEAL_LOGS)).isFalse();
        assertThat(refusedReadsBy(patient, doctor)).isZero();
    }

    @Test
    void refusedInvitationsCountForTheDailyLimit() {
        long patient = register("Pia", Role.PATIENT);
        String doctorEmail = email("Doc");
        registerWithEmail("Doc", Role.CLINICIAN, doctorEmail);

        // Probing ten unknown emails uses up the day: they all answer 404 but are counted.
        for (int i = 0; i < 10; i++) {
            String unknown = email("nobody" + i);
            assertThatThrownBy(() -> care.invite(patient, invitation(unknown)))
                    .isInstanceOf(ResourceNotFoundException.class);
        }
        assertThatThrownBy(() -> care.invite(patient, invitation(doctorEmail)))
                .isInstanceOf(TooManyRequestsException.class);
    }

    @Test
    void parallelInvitationsCannotPassTheDailyLimit() throws Exception {
        long patient = register("Pia", Role.PATIENT);
        List<String> members = new ArrayList<>();
        for (int i = 0; i < 15; i++) {
            String memberEmail = email("care" + i);
            registerWithEmail("Care", Role.CAREGIVER, memberEmail);
            members.add(memberEmail);
        }

        List<Callable<String>> calls = members.stream().<Callable<String>>map(memberEmail -> () -> {
            try {
                care.invite(patient, invitation(memberEmail));
                return "created";
            } catch (TooManyRequestsException limited) {
                return "limited";
            }
        }).toList();
        List<String> results = new ArrayList<>();
        ExecutorService pool = Executors.newFixedThreadPool(15);
        try {
            for (Future<String> result : pool.invokeAll(calls)) {
                results.add(result.get());
            }
        } finally {
            pool.shutdown();
        }

        assertThat(results).filteredOn("created"::equals).hasSize(10);
        assertThat(results).filteredOn("limited"::equals).hasSize(5);
    }

    @Test
    void aMemberWhoDeclinedCannotBeInvitedAgainRightAway() {
        long patient = register("Pia", Role.PATIENT);
        String caregiverEmail = email("Care");
        long caregiver = registerWithEmail("Care", Role.CAREGIVER, caregiverEmail);
        long relationship = care.invite(patient, invitation(caregiverEmail)).id();
        care.decline(caregiver, relationship);

        assertThatThrownBy(() -> care.invite(patient, invitation(caregiverEmail)))
                .isInstanceOf(ResourceConflictException.class)
                .hasMessageContaining("declined");
    }

    // ---------- helpers ----------

    private long registerWithEmail(String firstName, Role role, String memberEmail) {
        return authService.register(new RegisterRequest(firstName, "Test",
                LocalDate.of(1985, 5, 5), Gender.OTHER, role, memberEmail,
                PASSWORD)).id();
    }

    /** Patient invites the member with these permissions and the member accepts. Returns the relationship id. */
    private long share(long patient, long member, String memberEmail, CareInvitationRequest permissions) {
        CareInvitationRequest request = new CareInvitationRequest(memberEmail, permissions.canViewGlucose(),
                permissions.canViewMeals(), permissions.canViewMedications(), permissions.canViewActivity(),
                permissions.canViewReports(), permissions.canReceiveAlerts(), permissions.canAddRecommendations(),
                null);
        long id = care.invite(patient, request).id();
        care.accept(member, id);
        return id;
    }

    private static CareInvitationRequest glucoseOnly() {
        return new CareInvitationRequest(null, true, false, false, false, false, false, false, null);
    }

    private static CareInvitationRequest invitation(String memberEmail) {
        return new CareInvitationRequest(memberEmail, null, null, null, null, null, null, null, null);
    }

    private long refusedReadsBy(long patient, long actor) {
        List<AccessLogEntryResponse> items = auditLog.patientAccessLog(patient, patient, null, null, 0, 200).items();
        return items.stream()
                .filter(item -> item.actorId() != null && item.actorId() == actor && !item.success())
                .count();
    }
}
