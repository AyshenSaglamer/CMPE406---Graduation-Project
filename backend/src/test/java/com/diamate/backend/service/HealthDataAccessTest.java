package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Arrays;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.PatientAccessRepository;

/**
 * The one place that decides whether a viewer may read or write a patient's data. The rule itself lives in the
 * database function fn_can_access; it is tested on a real database by Database/tools/access_rules_test.sql and
 * through the API by the Postman folder "Permissions (Week 3)".
 */
@ExtendWith(MockitoExtension.class)
class HealthDataAccessTest {

    private static final long PATIENT = 5;
    private static final long OTHER_PATIENT = 6;
    private static final long CLINICIAN = 2;

    /** Permission names fn_can_access understands (Database/sql/07_app_functions_views.sql); anything else is false. */
    private static final Set<String> DATABASE_PERMISSIONS =
            Set.of("glucose", "meals", "medications", "activity", "reports", "alerts", "recommend");

    @Mock
    private PatientAccessRepository repository;

    @Mock
    private AuditService auditService;

    private HealthDataAccess access;

    @BeforeEach
    void setUp() {
        access = new HealthDataAccess(repository, auditService);
    }

    @Test
    void eachDataTypeIsSharedByTheExpectedPermission() {
        // Pinned on purpose: changing a mapping changes who can see what, so it must be a deliberate change.
        Map<PatientDataType, String> expected = Map.of(
                PatientDataType.OVERVIEW, "glucose",
                PatientDataType.GLUCOSE_LOGS, "glucose",
                PatientDataType.INSULIN_LOGS, "medications",
                PatientDataType.MEAL_LOGS, "meals",
                PatientDataType.ACTIVITY_LOGS, "activity",
                PatientDataType.ALERTS, "alerts",
                PatientDataType.REPORTS, "reports");

        Map<PatientDataType, String> actual = Arrays.stream(PatientDataType.values())
                .collect(Collectors.toMap(type -> type, PatientDataType::permission));

        assertThat(actual).isEqualTo(expected);
    }

    @ParameterizedTest
    @EnumSource(PatientDataType.class)
    void everyPermissionIsOneTheDatabaseUnderstands(PatientDataType type) {
        // A typo here would not fail loudly: fn_can_access answers false for an unknown name, so the care team
        // would silently lose access.
        assertThat(DATABASE_PERMISSIONS).contains(type.permission());
    }

    @ParameterizedTest
    @EnumSource(PatientDataType.class)
    void theDatabaseIsAskedWithThePermissionOfTheDataType(PatientDataType type) {
        when(repository.canAccess(CLINICIAN, PATIENT, type.permission())).thenReturn(true);

        assertThatCode(() -> access.checkCanRead(CLINICIAN, PATIENT, type)).doesNotThrowAnyException();

        verify(repository).canAccess(CLINICIAN, PATIENT, type.permission());
    }

    @ParameterizedTest
    @EnumSource(PatientDataType.class)
    void refusedReadIs404AndAudited(PatientDataType type) {
        when(repository.canAccess(CLINICIAN, PATIENT, type.permission())).thenReturn(false);

        assertThatThrownBy(() -> access.checkCanRead(CLINICIAN, PATIENT, type))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Patient not found"); // same answer as an unknown patient id

        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, type, false);
    }

    @Test
    void allowedReadByTheCareTeamIsAudited() {
        when(repository.canAccess(CLINICIAN, PATIENT, "glucose")).thenReturn(true);

        access.checkCanRead(CLINICIAN, PATIENT, PatientDataType.GLUCOSE_LOGS);

        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.GLUCOSE_LOGS, true);
    }

    @Test
    void thePatientReadingTheirOwnDataIsNotAudited() {
        when(repository.canAccess(PATIENT, PATIENT, "meals")).thenReturn(true);

        access.checkCanRead(PATIENT, PATIENT, PatientDataType.MEAL_LOGS);

        verifyNoInteractions(auditService);
    }

    @Test
    void canReadAnswersWithoutThrowingAndStillAudits() {
        when(repository.canAccess(CLINICIAN, PATIENT, "activity")).thenReturn(false);

        assertThat(access.canRead(CLINICIAN, PATIENT, PatientDataType.ACTIVITY_LOGS)).isFalse();

        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.ACTIVITY_LOGS, false);
    }

    @Test
    void thePatientMayWriteTheirOwnData() {
        assertThatCode(() -> access.checkCanWrite(PATIENT, PATIENT)).doesNotThrowAnyException();
        verifyNoInteractions(repository, auditService);
    }

    @Test
    void nobodyElseMayWriteEvenWithAnActiveRelationship() {
        // Writing does not consult care_relationships at all: a clinician with every permission is still refused.
        assertThatThrownBy(() -> access.checkCanWrite(CLINICIAN, PATIENT))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Patient not found");
        assertThatThrownBy(() -> access.checkCanWrite(OTHER_PATIENT, PATIENT))
                .isInstanceOf(ResourceNotFoundException.class);

        verify(repository, never()).canAccess(anyLong(), anyLong(), any());
        verify(auditService, never()).patientDataViewed(anyLong(), anyLong(), any(), anyBoolean());
    }
}
