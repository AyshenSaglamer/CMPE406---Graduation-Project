package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.response.AlertResponse;
import com.diamate.backend.api.dto.response.CareTeamAlertResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.Alert;
import com.diamate.backend.entity.AlertSeverity;
import com.diamate.backend.entity.AlertStatus;
import com.diamate.backend.entity.AlertType;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.AlertRepository;
import com.diamate.backend.repository.PatientAccessRepository;
import com.diamate.backend.repository.PatientAccessRepository.CareTeamPatientRow;

/** AlertService with the real HealthDataAccess; only the repositories and the audit service are mocks. */
@ExtendWith(MockitoExtension.class)
class AlertServiceTest {

    private static final long PATIENT = 5;
    private static final long CLINICIAN = 2;
    private static final long CAREGIVER = 4;
    private static final long ALERT_ID = 40;
    private static final Instant NOW = Instant.parse("2026-10-12T10:00:00Z");

    @Mock
    private AlertRepository repository;

    @Mock
    private PatientAccessRepository patientAccessRepository;

    @Mock
    private AuditService auditService;

    private AlertService service;

    @BeforeEach
    void setUp() {
        service = new AlertService(repository, new HealthDataAccess(patientAccessRepository, auditService),
                patientAccessRepository, auditService, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    // ---------- list / get ----------

    @Test
    void patientListsOwnAlertsWithoutTimeLimitByDefault() {
        allow(PATIENT);
        when(repository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(alert(AlertStatus.OPEN)), PageRequest.of(0, 50), 1));

        PageResponse<AlertResponse> page = service.list(PATIENT, PATIENT, null, null, null, 0, 50);

        assertThat(page.items()).extracting(AlertResponse::id).containsExactly(ALERT_ID);
        ArgumentCaptor<Instant> from = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> to = ArgumentCaptor.forClass(Instant.class);
        verify(repository).findInRange(eq(PATIENT), from.capture(), to.capture(), any(Pageable.class));
        assertThat(from.getValue()).isEqualTo(Instant.EPOCH); // an old OPEN alert is still listed
        assertThat(to.getValue()).isEqualTo(NOW.plus(LogRules.FUTURE_TOLERANCE));
        verifyNoInteractions(auditService); // the patient reading own data is not audited
    }

    @Test
    void statusFilterUsesTheStatusQuery() {
        allow(PATIENT);
        when(repository.findInRangeWithStatus(eq(PATIENT), eq(AlertStatus.OPEN), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 50), 0));

        service.list(PATIENT, PATIENT, AlertStatus.OPEN, null, null, 0, 50);

        verify(repository, never()).findInRange(anyLong(), any(), any(), any());
    }

    @Test
    void clinicianWithAlertPermissionReadsAndIsAudited() {
        allow(CLINICIAN);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT)).thenReturn(Optional.of(alert(AlertStatus.OPEN)));

        AlertResponse response = service.get(CLINICIAN, PATIENT, ALERT_ID);

        assertThat(response.status()).isEqualTo(AlertStatus.OPEN);
        verify(patientAccessRepository).canAccess(CLINICIAN, PATIENT, "alerts");
        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.ALERTS, true);
    }

    @Test
    void withoutAlertPermissionIs404AndTheRepositoryIsNotQueried() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "alerts")).thenReturn(false);

        assertThatThrownBy(() -> service.list(CLINICIAN, PATIENT, null, null, null, 0, 50))
                .isInstanceOf(ResourceNotFoundException.class).hasMessage("Patient not found");
        assertThatThrownBy(() -> service.changeStatus(CLINICIAN, PATIENT, ALERT_ID, AlertStatus.ACKNOWLEDGED))
                .isInstanceOf(ResourceNotFoundException.class);

        verify(auditService, times(2))
                .patientDataViewed(CLINICIAN, PATIENT, PatientDataType.ALERTS, false);
        verifyNoInteractions(repository);
    }

    @Test
    void alertOfAnotherPatientIs404() {
        allow(PATIENT);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get(PATIENT, PATIENT, ALERT_ID))
                .isInstanceOf(ResourceNotFoundException.class).hasMessage("Alert not found");
    }

    @Test
    void pageSizeIsLimitedLikeTheLogLists() {
        allow(PATIENT);

        assertThatThrownBy(() -> service.list(PATIENT, PATIENT, null, null, null, 0, 201))
                .isInstanceOf(InvalidFieldException.class).hasMessage("Size must be between 1 and 200");
    }

    // ---------- change status: one conditional UPDATE, audited ----------

    @Test
    void clinicianAcknowledgesAnOpenAlert() {
        allow(CLINICIAN);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT))
                .thenReturn(Optional.of(alert(AlertStatus.OPEN)), Optional.of(handled(AlertStatus.ACKNOWLEDGED, CLINICIAN)));
        when(repository.acknowledgeIfOpen(ALERT_ID, PATIENT, CLINICIAN, NOW)).thenReturn(1);

        AlertResponse response = service.changeStatus(CLINICIAN, PATIENT, ALERT_ID, AlertStatus.ACKNOWLEDGED);

        assertThat(response.status()).isEqualTo(AlertStatus.ACKNOWLEDGED);
        assertThat(response.acknowledgedBy()).isEqualTo(CLINICIAN);
        verify(auditService).alertStatusChanged(CLINICIAN, PATIENT, ALERT_ID, AlertStatus.OPEN, AlertStatus.ACKNOWLEDGED);
        verify(repository, never()).saveAndFlush(any()); // no read-change-save
    }

    @Test
    void resolvingUsesTheResolveUpdateAndRecordsWhoResolved() {
        allow(PATIENT);
        Alert resolved = handled(AlertStatus.RESOLVED, CLINICIAN);
        ReflectionTestUtils.setField(resolved, "resolvedBy", PATIENT);
        ReflectionTestUtils.setField(resolved, "resolvedAt", NOW);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT))
                .thenReturn(Optional.of(handled(AlertStatus.ACKNOWLEDGED, CLINICIAN)), Optional.of(resolved));
        when(repository.resolveIfNotClosed(ALERT_ID, PATIENT, PATIENT, NOW)).thenReturn(1);

        AlertResponse response = service.changeStatus(PATIENT, PATIENT, ALERT_ID, AlertStatus.RESOLVED);

        assertThat(response.status()).isEqualTo(AlertStatus.RESOLVED);
        assertThat(response.acknowledgedBy()).isEqualTo(CLINICIAN); // the first handler is kept
        assertThat(response.resolvedBy()).isEqualTo(PATIENT);
        assertThat(response.resolvedAt()).isEqualTo(NOW);
        verify(auditService).alertStatusChanged(PATIENT, PATIENT, ALERT_ID, AlertStatus.ACKNOWLEDGED, AlertStatus.RESOLVED);
    }

    @Test
    void sameStatusAgainIsReturnedUnchangedWithoutAnUpdate() {
        allow(PATIENT);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT)).thenReturn(Optional.of(alert(AlertStatus.RESOLVED)));

        AlertResponse response = service.changeStatus(PATIENT, PATIENT, ALERT_ID, AlertStatus.RESOLVED);

        assertThat(response.status()).isEqualTo(AlertStatus.RESOLVED);
        verify(repository, never()).resolveIfNotClosed(anyLong(), anyLong(), anyLong(), any());
        verify(auditService, never()).alertStatusChanged(anyLong(), anyLong(), anyLong(), any(), any());
    }

    @Test
    void someoneElseAcknowledgedAMomentEarlierAndTheFirstOneIsKept() {
        // Read as OPEN, but the caregiver's update came first: this update matches no row.
        allow(PATIENT);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT))
                .thenReturn(Optional.of(alert(AlertStatus.OPEN)), Optional.of(handled(AlertStatus.ACKNOWLEDGED, CAREGIVER)));
        when(repository.acknowledgeIfOpen(ALERT_ID, PATIENT, PATIENT, NOW)).thenReturn(0);

        AlertResponse response = service.changeStatus(PATIENT, PATIENT, ALERT_ID, AlertStatus.ACKNOWLEDGED);

        assertThat(response.acknowledgedBy()).isEqualTo(CAREGIVER);
        verify(auditService, never()).alertStatusChanged(anyLong(), anyLong(), anyLong(), any(), any());
    }

    @Test
    void anAlertTheBackendDismissedMeanwhileIsNotReopened() {
        // Read as OPEN; then the reading was deleted and the alert DISMISSED before this request's update.
        allow(CLINICIAN);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT))
                .thenReturn(Optional.of(alert(AlertStatus.OPEN)), Optional.of(alert(AlertStatus.DISMISSED)));
        when(repository.acknowledgeIfOpen(ALERT_ID, PATIENT, CLINICIAN, NOW)).thenReturn(0);

        assertThatThrownBy(() -> service.changeStatus(CLINICIAN, PATIENT, ALERT_ID, AlertStatus.ACKNOWLEDGED))
                .isInstanceOf(ResourceConflictException.class).hasMessage("Alert is already dismissed");
    }

    @Test
    void resolvedOrDismissedAlertCannotBeChangedAgain() {
        allow(PATIENT);
        when(repository.findByIdAndPatientId(ALERT_ID, PATIENT)).thenReturn(
                Optional.of(alert(AlertStatus.RESOLVED)), Optional.of(alert(AlertStatus.RESOLVED)),
                Optional.of(alert(AlertStatus.DISMISSED)), Optional.of(alert(AlertStatus.DISMISSED)));

        assertThatThrownBy(() -> service.changeStatus(PATIENT, PATIENT, ALERT_ID, AlertStatus.ACKNOWLEDGED))
                .isInstanceOf(ResourceConflictException.class).hasMessage("Alert is already resolved");
        assertThatThrownBy(() -> service.changeStatus(PATIENT, PATIENT, ALERT_ID, AlertStatus.RESOLVED))
                .isInstanceOf(ResourceConflictException.class).hasMessage("Alert is already dismissed");
        verify(auditService, never()).alertStatusChanged(anyLong(), anyLong(), anyLong(), any(), any());
    }

    @Test
    void onlyAcknowledgedOrResolvedCanBeRequested() {
        for (AlertStatus status : new AlertStatus[] { AlertStatus.OPEN, AlertStatus.DISMISSED }) {
            assertThatThrownBy(() -> service.changeStatus(PATIENT, PATIENT, ALERT_ID, status))
                    .isInstanceOf(InvalidFieldException.class).hasMessage("Status must be ACKNOWLEDGED or RESOLVED");
        }
        verifyNoInteractions(repository, patientAccessRepository);
    }

    // ---------- GET /care-team/alerts ----------

    @Test
    void careTeamListContainsOnlyPatientsWhoShareAlertsAndAuditsThePatientsShown() {
        when(patientAccessRepository.findActivePatientsOf(CLINICIAN)).thenReturn(List.of(
                row(PATIENT, true), row(8L, false), row(9L, true)));
        when(repository.findForPatients(any(), eq(PageRequest.of(0, 50))))
                .thenReturn(new PageImpl<>(List.of(alert(AlertStatus.OPEN)), PageRequest.of(0, 50), 1));

        PageResponse<CareTeamAlertResponse> page = service.careTeamAlerts(CLINICIAN, null, 0, 50);

        ArgumentCaptor<Collection<Long>> ids = ArgumentCaptor.captor();
        verify(repository).findForPatients(ids.capture(), any());
        assertThat(ids.getValue()).containsExactlyInAnyOrder(PATIENT, 9L); // patient 8 does not share alerts
        assertThat(page.items()).hasSize(1);
        assertThat(page.items().get(0).patientFirstName()).isEqualTo("First" + PATIENT);
        assertThat(page.items().get(0).alert().id()).isEqualTo(ALERT_ID);
        // Only the patient whose alert is on the page is audited, not every patient on the list.
        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.ALERTS, true);
        verify(auditService, never()).patientDataViewed(CLINICIAN, 9L, PatientDataType.ALERTS, true);
    }

    @Test
    void careTeamStatusFilterUsesTheStatusQuery() {
        when(patientAccessRepository.findActivePatientsOf(CAREGIVER)).thenReturn(List.of(row(PATIENT, true)));
        when(repository.findForPatientsWithStatus(any(), eq(AlertStatus.OPEN), any()))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 1), 3));

        PageResponse<CareTeamAlertResponse> page = service.careTeamAlerts(CAREGIVER, AlertStatus.OPEN, 0, 1);

        assertThat(page.totalElements()).isEqualTo(3); // the dashboard's open-alert count
        verify(repository, never()).findForPatients(any(), any());
    }

    @Test
    void withoutPatientsWhoShareAlertsNothingIsQueried() {
        when(patientAccessRepository.findActivePatientsOf(CAREGIVER)).thenReturn(List.of(row(PATIENT, false)));

        PageResponse<CareTeamAlertResponse> page = service.careTeamAlerts(CAREGIVER, null, 0, 50);

        assertThat(page.items()).isEmpty();
        assertThat(page.totalElements()).isZero();
        verifyNoInteractions(repository, auditService);
    }

    // ---------- helpers ----------

    private void allow(long viewerId) {
        when(patientAccessRepository.canAccess(viewerId, PATIENT, "alerts")).thenReturn(true);
    }

    private static Alert alert(AlertStatus status) {
        Alert alert = new Alert(PATIENT, AlertType.LOW, AlertSeverity.WARNING, 100L, 62, "Low glucose: 62 mg/dL");
        ReflectionTestUtils.setField(alert, "id", ALERT_ID);
        ReflectionTestUtils.setField(alert, "status", status);
        ReflectionTestUtils.setField(alert, "triggeredAt", NOW.minusSeconds(3600));
        return alert;
    }

    private static Alert handled(AlertStatus status, long by) {
        Alert alert = alert(status);
        ReflectionTestUtils.setField(alert, "acknowledgedBy", by);
        ReflectionTestUtils.setField(alert, "acknowledgedAt", NOW.minusSeconds(600));
        return alert;
    }

    private static CareTeamPatientRow row(long patientId, boolean canReceiveAlerts) {
        return new CareTeamPatientRow(patientId, "First" + patientId, "Last", true, true, true, true, true,
                canReceiveAlerts, false);
    }
}
