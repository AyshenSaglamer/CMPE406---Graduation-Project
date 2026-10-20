package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.api.dto.request.InsulinLogRequest;
import com.diamate.backend.api.dto.response.InsulinLogResponse;
import com.diamate.backend.api.dto.response.PageResponse;
import com.diamate.backend.entity.InsulinDeliveryMethod;
import com.diamate.backend.entity.InsulinLog;
import com.diamate.backend.entity.InsulinSource;
import com.diamate.backend.entity.InsulinType;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.InsulinLogRepository;
import com.diamate.backend.repository.MealLogRepository;
import com.diamate.backend.repository.PatientAccessRepository;

/** What differs from glucose: the "medications" permission, the defaults and the meal link. */
@ExtendWith(MockitoExtension.class)
class InsulinLogServiceTest {

    private static final long PATIENT = 5;
    private static final long CLINICIAN = 2;
    private static final Instant NOW = Instant.parse("2026-10-05T10:00:00Z");
    private static final Instant EARLIER = Instant.parse("2026-10-05T08:30:00Z");

    @Mock
    private InsulinLogRepository repository;

    @Mock
    private MealLogRepository mealLogRepository;

    @Mock
    private PatientAccessRepository patientAccessRepository;

    @Mock
    private AuditService auditService;

    private InsulinLogService service;

    @BeforeEach
    void setUp() {
        service = new InsulinLogService(repository, mealLogRepository, new HealthDataAccess(patientAccessRepository, auditService),
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void careTeamNeedsTheMedicationsPermissionToSeeInsulin() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "medications")).thenReturn(false);

        assertThatThrownBy(() -> service.list(CLINICIAN, PATIENT, null, null, 0, 50))
                .isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(repository);
    }

    @Test
    void typeAndDeliveryMethodDefaultToOther() {
        when(repository.saveAndFlush(any(InsulinLog.class))).thenAnswer(invocation -> {
            InsulinLog log = invocation.getArgument(0);
            ReflectionTestUtils.setField(log, "id", 200L);
            return log;
        });

        InsulinLogResponse created = service.create(PATIENT, PATIENT,
                new InsulinLogRequest(new BigDecimal("4.5"), null, null, " ", EARLIER, null, null, null, null)).log();

        assertThat(created.doseUnits()).isEqualByComparingTo("4.5");
        assertThat(created.insulinType()).isEqualTo(InsulinType.OTHER);
        assertThat(created.deliveryMethod()).isEqualTo(InsulinDeliveryMethod.OTHER);
        assertThat(created.productName()).isNull();
    }

    @Test
    void aDoseCanOnlyBeLinkedToTheSamePatientsMeal() {
        when(mealLogRepository.existsByIdAndPatientId(77L, PATIENT)).thenReturn(false); // someone else's meal

        assertThatThrownBy(() -> service.create(PATIENT, PATIENT, new InsulinLogRequest(new BigDecimal("6"),
                InsulinType.RAPID, InsulinDeliveryMethod.PEN, "NovoRapid", EARLIER, 77L, null, null, null)))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Meal log not found");
        verify(repository, never()).saveAndFlush(any());
    }

    // ---------- get, update, delete ----------

    @Test
    void careTeamWithTheMedicationsPermissionGetsAPage() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "medications")).thenReturn(true);
        when(repository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(dose(200L, null)), PageRequest.of(0, 50), 1));

        PageResponse<InsulinLogResponse> page = service.list(CLINICIAN, PATIENT, null, null, 0, 50);

        assertThat(page.items()).extracting(InsulinLogResponse::id).containsExactly(200L);
        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.INSULIN_LOGS, true);
    }

    @Test
    void careTeamWithTheMedicationsPermissionReadsOneDose() {
        when(patientAccessRepository.canAccess(CLINICIAN, PATIENT, "medications")).thenReturn(true);
        when(repository.findByIdAndPatientId(200L, PATIENT)).thenReturn(Optional.of(dose(200L, null)));

        assertThat(service.get(CLINICIAN, PATIENT, 200L).doseUnits()).isEqualByComparingTo("4");
        verify(auditService).patientDataViewed(CLINICIAN, PATIENT, PatientDataType.INSULIN_LOGS, true);
    }

    @Test
    void updateReplacesTheValuesButNotTheSource() {
        InsulinLog existing = dose(200L, null);
        when(repository.findByIdAndPatientId(200L, PATIENT)).thenReturn(Optional.of(existing));
        when(mealLogRepository.existsByIdAndPatientId(30L, PATIENT)).thenReturn(true);
        when(repository.saveAndFlush(existing)).thenReturn(existing);

        InsulinLogResponse updated = service.update(PATIENT, PATIENT, 200L, new InsulinLogRequest(new BigDecimal("7.25"),
                InsulinType.RAPID, InsulinDeliveryMethod.PEN, "Fiasp", EARLIER, 30L, "before lunch",
                EntrySource.AI_ASSISTANT, null));

        assertThat(updated.doseUnits()).isEqualByComparingTo("7.25");
        assertThat(updated.insulinType()).isEqualTo(InsulinType.RAPID);
        assertThat(updated.mealLogId()).isEqualTo(30L);
        assertThat(updated.source()).isEqualTo(InsulinSource.MANUAL); // where a log came from never changes
    }

    @Test
    void updateChecksTheMealLinkToo() {
        when(repository.findByIdAndPatientId(200L, PATIENT)).thenReturn(Optional.of(dose(200L, null)));
        when(mealLogRepository.existsByIdAndPatientId(77L, PATIENT)).thenReturn(false); // someone else's or deleted meal

        assertThatThrownBy(() -> service.update(PATIENT, PATIENT, 200L, new InsulinLogRequest(new BigDecimal("6"),
                null, null, null, EARLIER, 77L, null, null, null)))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Meal log not found");
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    void deleteIsASoftDelete() {
        InsulinLog existing = dose(200L, null);
        when(repository.findByIdAndPatientId(200L, PATIENT)).thenReturn(Optional.of(existing));

        service.delete(PATIENT, PATIENT, 200L);

        assertThat(existing.getDeletedAt()).isEqualTo(NOW);
        verify(repository, never()).delete(any());
    }

    @Test
    void aMissingOrDeletedDoseIs404() {
        when(repository.findByIdAndPatientId(999L, PATIENT)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(PATIENT, PATIENT, 999L, new InsulinLogRequest(new BigDecimal("6"),
                null, null, null, EARLIER, null, null, null, null)))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Insulin log not found");
        assertThatThrownBy(() -> service.delete(PATIENT, PATIENT, 999L)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void aPatientCannotChangeAnotherPatientsDoses() {
        assertThatThrownBy(() -> service.delete(PATIENT, 8L, 200L)).isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(repository);
    }

    private static InsulinLog dose(long id, Long mealLogId) {
        InsulinLog log = new InsulinLog(PATIENT, null, InsulinSource.MANUAL, PATIENT);
        log.update(new BigDecimal("4"), InsulinType.LONG, InsulinDeliveryMethod.PEN, null, EARLIER, mealLogId, null);
        ReflectionTestUtils.setField(log, "id", id);
        return log;
    }
}
