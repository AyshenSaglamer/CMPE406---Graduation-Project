package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.diamate.backend.api.dto.response.CareTeamPatientResponse;
import com.diamate.backend.api.dto.response.PatientOverviewResponse;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.PatientAccessRepository;
import com.diamate.backend.repository.PatientAccessRepository.CareTeamPatientRow;
import com.diamate.backend.repository.PatientAccessRepository.PatientOverviewRow;

/** Data-level authorization. The access rule itself (fn_can_access) is checked against the real database with Postman. */
@ExtendWith(MockitoExtension.class)
class PatientServiceTest {

    private static final long CLINICIAN = 2;
    private static final long PATIENT = 5;

    @Mock
    private PatientAccessRepository repository;

    private PatientService service;

    @BeforeEach
    void setUp() {
        service = new PatientService(repository);
    }

    @Test
    void overviewIsReturnedWhenAccessIsGranted() {
        when(repository.canAccess(CLINICIAN, PATIENT, "glucose")).thenReturn(true);
        when(repository.findOverview(PATIENT)).thenReturn(Optional.of(new PatientOverviewRow(
                PATIENT, "Demo Patient", "01", "MALE", 34, "TYPE_1", "PUMP", 70, 180, 96, Instant.now(), 1)));

        PatientOverviewResponse overview = service.getOverview(CLINICIAN, PATIENT);

        assertThat(overview.patientId()).isEqualTo(PATIENT);
        assertThat(overview.lastGlucoseMgdl()).isEqualTo(96);
    }

    @Test
    void noAccessIs404AndThePatientDataIsNeverRead() {
        when(repository.canAccess(CLINICIAN, PATIENT, "glucose")).thenReturn(false);

        assertThatThrownBy(() -> service.getOverview(CLINICIAN, PATIENT))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Patient not found");
        verify(repository, never()).findOverview(anyLong());
    }

    @Test
    void accessButNoPatientProfileIsAlso404() {
        when(repository.canAccess(PATIENT, PATIENT, "glucose")).thenReturn(true);
        when(repository.findOverview(PATIENT)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getOverview(PATIENT, PATIENT))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Patient not found");
    }

    @Test
    void careTeamListMapsRows() {
        when(repository.findActivePatientsOf(CLINICIAN)).thenReturn(List.of(
                new CareTeamPatientRow(PATIENT, "Demo Patient", "01", true, true, true, true, true, true, true)));

        List<CareTeamPatientResponse> patients = service.getCareTeamPatients(CLINICIAN);

        assertThat(patients).extracting(CareTeamPatientResponse::patientId).containsExactly(PATIENT);
    }
}
