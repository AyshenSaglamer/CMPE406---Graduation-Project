package com.diamate.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import com.diamate.backend.api.dto.request.AiEntriesRequest;
import com.diamate.backend.api.dto.request.AiIntent;
import com.diamate.backend.api.dto.request.CareInvitationRequest;
import com.diamate.backend.api.dto.request.DependentRequest;
import com.diamate.backend.api.dto.request.GlucoseLogRequest;
import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.api.dto.request.ReminderEventRequest;
import com.diamate.backend.api.dto.request.ReminderRequest;
import com.diamate.backend.api.dto.response.CareTeamPatientResponse;
import com.diamate.backend.api.dto.response.DependentResponse;
import com.diamate.backend.entity.DiabetesType;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.ReminderEventStatus;
import com.diamate.backend.entity.ReminderType;
import com.diamate.backend.entity.Role;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.service.AiEntryService;
import com.diamate.backend.service.CareRelationshipService;
import com.diamate.backend.service.DependentService;
import com.diamate.backend.service.GlucoseLogService;
import com.diamate.backend.service.HealthDataAccess;
import com.diamate.backend.service.PatientDataType;
import com.diamate.backend.service.PatientService;
import com.diamate.backend.service.ReminderService;

/**
 * V12 with the real database: a caregiver adds a family member without an account, keeps their diary, and nobody can
 * ever log in as that record. Also that the new write rule gives nothing to anyone else.
 */
class DependentIntegrationTest extends PostgresIntegrationTest {

    @Autowired private DependentService dependents;
    @Autowired private CareRelationshipService care;
    @Autowired private GlucoseLogService glucose;
    @Autowired private ReminderService reminders;
    @Autowired private AiEntryService aiEntries;
    @Autowired private PatientService patients;
    @Autowired private HealthDataAccess access;
    @Autowired private UserRepository users;
    @Autowired private NamedParameterJdbcTemplate jdbc;

    @Test
    void theCaregiverAddsAChildSeesThemManagedAndWritesTheirLogs() {
        long caregiver = register("Mom", Role.CAREGIVER);

        DependentResponse child = dependents.create(caregiver, child("Can", DiabetesType.TYPE_1));

        assertThat(child.diabetesType()).isEqualTo(DiabetesType.TYPE_1);
        assertThat(jdbc.queryForMap("SELECT email, password_hash, role FROM users WHERE id = :id",
                Map.of("id", child.patientId())))
                .containsEntry("email", null).containsEntry("password_hash", null).containsEntry("role", "PATIENT");
        assertThat(patients.getCareTeamPatients(caregiver)).singleElement()
                .satisfies(p -> {
                    assertThat(p.patientId()).isEqualTo(child.patientId());
                    assertThat(p.managed()).isTrue();
                });

        long logId = glucose.create(caregiver, child.patientId(), reading(140)).log().id();
        assertThat(glucose.get(caregiver, child.patientId(), logId).glucoseValue()).isEqualTo(140);
        glucose.delete(caregiver, child.patientId(), logId);
        assertThat(jdbc.queryForObject("SELECT entered_by FROM glucose_logs WHERE id = :id", Map.of("id", logId),
                Long.class)).isEqualTo(caregiver);
    }

    @Test
    void onlyTheManagingCaregiverCorrectsTheDetails() {
        long caregiver = register("Mom", Role.CAREGIVER);
        long otherCaregiver = register("Aunt", Role.CAREGIVER);
        DependentResponse child = dependents.create(caregiver, child("Can", null));
        assertThat(child.diabetesType()).isEqualTo(DiabetesType.OTHER);

        DependentResponse fixed = dependents.update(caregiver, child.patientId(),
                new DependentRequest("Cem", "Kaya", LocalDate.of(2017, 2, 3), Gender.MALE, DiabetesType.TYPE_1));
        assertThat(fixed.firstName()).isEqualTo("Cem");
        assertThat(fixed.diabetesType()).isEqualTo(DiabetesType.TYPE_1);

        assertThatThrownBy(() -> dependents.update(otherCaregiver, child.patientId(), child("X", null)))
                .isInstanceOf(ResourceNotFoundException.class);
        // A patient with their own account is never a "dependent", even for a caregiver they share everything with.
        long adult = register("Adult", Role.PATIENT);
        assertThatThrownBy(() -> dependents.update(caregiver, adult, child("X", null)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void viewPermissionsNeverAllowWriting() {
        long patient = register("Pia", Role.PATIENT);
        String caregiverEmail = email("Care");
        long caregiver = registerWithEmail("Care", Role.CAREGIVER, caregiverEmail);
        long id = care.invite(patient, new CareInvitationRequest(caregiverEmail, null, null, null, null, null, null,
                null, null)).id();
        care.accept(caregiver, id);

        assertThat(access.canRead(caregiver, patient, PatientDataType.GLUCOSE_LOGS)).isTrue();
        assertThatThrownBy(() -> glucose.create(caregiver, patient, reading(120)))
                .isInstanceOf(ResourceNotFoundException.class);

        // Someone else's dependent is not writable either.
        long mom = register("Mom", Role.CAREGIVER);
        long child = dependents.create(mom, child("Can", null)).patientId();
        assertThatThrownBy(() -> glucose.create(caregiver, child, reading(120)))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThat(access.canRead(caregiver, child, PatientDataType.GLUCOSE_LOGS)).isFalse();
    }

    @Test
    void theManagerCannotLeaveTheDependent() {
        long caregiver = register("Mom", Role.CAREGIVER);
        DependentResponse child = dependents.create(caregiver, child("Can", null));

        assertThatThrownBy(() -> care.revoke(caregiver, child.relationshipId()))
                .isInstanceOf(ResourceConflictException.class);
    }

    @Test
    void theDatabaseKeepsDependentsAndManagersConsistent() {
        long caregiver = register("Mom", Role.CAREGIVER);
        long child = dependents.create(caregiver, child("Can", null)).patientId();
        long adult = register("Adult", Role.PATIENT);

        // Email without password (or the other way round), and an account-less non-patient: refused.
        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO users (email, password_hash, role, first_name, last_name)
                VALUES (NULL, NULL, 'CAREGIVER', 'No', 'Login')""", Map.of()))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> jdbc.update("UPDATE users SET email = 'x@it.diamate.test' WHERE id = :id",
                Map.of("id", child))).isInstanceOf(DataIntegrityViolationException.class);
        // A caregiver cannot be made the manager of a patient who has an account.
        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO care_relationships (patient_id, member_id, member_role, status, manages_patient)
                VALUES (:patient, :member, 'CAREGIVER', 'ACTIVE', true)""",
                Map.of("patient", adult, "member", caregiver))).isInstanceOf(DataIntegrityViolationException.class);
        // A second manager for the same dependent.
        long otherCaregiver = register("Aunt", Role.CAREGIVER);
        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO care_relationships (patient_id, member_id, member_role, status, manages_patient)
                VALUES (:patient, :member, 'CAREGIVER', 'ACTIVE', true)""",
                Map.of("patient", child, "member", otherCaregiver)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void nobodyCanEverLogInAsADependent() {
        long caregiver = register("Mom", Role.CAREGIVER);
        long child = dependents.create(caregiver, child("Can", null)).patientId();

        // The database refuses a login session for a user without a password, whatever the backend does.
        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO auth_sessions (id, user_id, refresh_token_hash, expires_at)
                VALUES (:id, :user, :hash, now() + INTERVAL '1 day')""",
                Map.of("id", UUID.randomUUID(), "user", child, "hash", "a".repeat(64))))
                .isInstanceOf(DataIntegrityViolationException.class);
        // And a token claiming to be the dependent is rejected (no open session can exist, and no login).
        assertThat(users.findRoleForOpenSession(child, UUID.randomUUID(), Instant.now())).isEmpty();
        assertThat(users.findById(child)).get().satisfies(u -> assertThat(u.hasLogin()).isFalse());
    }

    @Test
    void theManagingCaregiverKeepsRemindersAndSavesAssistantEntries() {
        long caregiver = register("Mom", Role.CAREGIVER);
        long child = dependents.create(caregiver, child("Can", DiabetesType.TYPE_1)).patientId();

        long reminderId = reminders.create(caregiver, child, insulinReminder()).id();
        assertThat(reminders.list(caregiver, child)).singleElement()
                .satisfies(r -> assertThat(r.medicationName()).isEqualTo("Insulin"));
        assertThat(reminders.reportEvent(caregiver, child, reminderId,
                new ReminderEventRequest(Instant.now().minus(1, ChronoUnit.HOURS), ReminderEventStatus.TAKEN))
                .created()).isTrue();
        reminders.update(caregiver, child, reminderId, insulinReminder());

        assertThat(aiEntries.save(caregiver, child, assistantReading(150)).savedCount()).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "SELECT entered_by FROM glucose_logs WHERE patient_id = :p AND source = 'AI_ASSISTANT'",
                Map.of("p", child), Long.class)).isEqualTo(caregiver);

        reminders.delete(caregiver, child, reminderId);
        assertThat(reminders.list(caregiver, child)).isEmpty();
    }

    @Test
    void aCaregiverWhoOnlyFollowsCannotWriteRemindersOrAssistantEntries() {
        long patient = register("Pia", Role.PATIENT);
        String caregiverEmail = email("Care");
        long caregiver = registerWithEmail("Care", Role.CAREGIVER, caregiverEmail);
        care.accept(caregiver, care.invite(patient, new CareInvitationRequest(caregiverEmail, null, null, null, null,
                null, null, null, null)).id());
        long reminderId = reminders.create(patient, patient, insulinReminder()).id();

        // Sees the reminders (every view permission), but changes nothing.
        assertThat(reminders.list(caregiver, patient)).hasSize(1);
        assertThatThrownBy(() -> reminders.create(caregiver, patient, insulinReminder()))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> reminders.update(caregiver, patient, reminderId, insulinReminder()))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> reminders.delete(caregiver, patient, reminderId))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> reminders.reportEvent(caregiver, patient, reminderId,
                new ReminderEventRequest(Instant.now(), ReminderEventStatus.TAKEN)))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> aiEntries.save(caregiver, patient, assistantReading(150)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void aClinicianNeverWritesEvenWithEveryViewPermission() {
        long patient = register("Pia", Role.PATIENT);
        String clinicianEmail = email("Doc");
        long clinician = registerWithEmail("Doc", Role.CLINICIAN, clinicianEmail);
        care.accept(clinician, care.invite(patient, new CareInvitationRequest(clinicianEmail, null, null, null, null,
                null, null, null, null)).id());

        assertThat(access.canRead(clinician, patient, PatientDataType.GLUCOSE_LOGS)).isTrue();
        assertThatThrownBy(() -> glucose.create(clinician, patient, reading(120)))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> reminders.create(clinician, patient, insulinReminder()))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> aiEntries.save(clinician, patient, assistantReading(150)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void theManagingCaregiverWritesOnlyForTheirOwnDependent() {
        long mom = register("Mom", Role.CAREGIVER);
        long ownChild = dependents.create(mom, child("Can", null)).patientId();
        long aunt = register("Aunt", Role.CAREGIVER);
        long otherChild = dependents.create(aunt, child("Ece", null)).patientId();
        long stranger = register("Stranger", Role.PATIENT);

        reminders.create(mom, ownChild, insulinReminder());
        for (long patient : new long[] { otherChild, stranger }) {
            assertThatThrownBy(() -> glucose.create(mom, patient, reading(120)))
                    .isInstanceOf(ResourceNotFoundException.class);
            assertThatThrownBy(() -> reminders.create(mom, patient, insulinReminder()))
                    .isInstanceOf(ResourceNotFoundException.class);
            assertThatThrownBy(() -> aiEntries.save(mom, patient, assistantReading(150)))
                    .isInstanceOf(ResourceNotFoundException.class);
        }
        assertThat(jdbc.queryForObject("SELECT count(*) FROM reminders WHERE patient_id IN (:ids)",
                Map.of("ids", List.of(otherChild, stranger)), Integer.class)).isZero();
    }

    @Test
    void aCaregiverCanManageAtMostTenFamilyMembers() {
        long caregiver = register("Mom", Role.CAREGIVER);
        for (int i = 0; i < 10; i++) {
            dependents.create(caregiver, child("Can", null));
        }
        assertThatThrownBy(() -> dependents.create(caregiver, child("Can", null)))
                .isInstanceOf(ResourceConflictException.class);
        assertThat(patients.getCareTeamPatients(caregiver)).hasSize(10)
                .allMatch(CareTeamPatientResponse::managed);
    }

    // ---------- helpers ----------

    private static DependentRequest child(String firstName, DiabetesType type) {
        return new DependentRequest(firstName, "Kaya", LocalDate.of(2016, 4, 1), Gender.MALE, type);
    }

    private static ReminderRequest insulinReminder() {
        return new ReminderRequest(ReminderType.MEDICATION, "Insulin", "4 units", null, LocalTime.of(8, 0),
                List.of(DayOfWeek.values()), "Europe/Istanbul", true);
    }

    private static AiEntriesRequest assistantReading(int value) {
        return new AiEntriesRequest(List.of(new AiEntriesRequest.Entry(AiIntent.LOG_GLUCOSE, BigDecimal.valueOf(value),
                "mg/dL", null, Instant.now().minus(30, ChronoUnit.MINUTES), null, null, UUID.randomUUID())));
    }

    private static GlucoseLogRequest reading(int value) {
        return new GlucoseLogRequest(value, Instant.now().minus(1, ChronoUnit.HOURS), null, null, null, null);
    }

    private long registerWithEmail(String firstName, Role role, String memberEmail) {
        return authService.register(new RegisterRequest(firstName, "Test", LocalDate.of(1985, 5, 5), Gender.OTHER,
                role, memberEmail, PASSWORD)).id();
    }
}
