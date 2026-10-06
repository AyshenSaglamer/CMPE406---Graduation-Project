package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.request.InsulinLogRequest;
import com.diamate.backend.api.dto.response.InsulinLogResponse;
import com.diamate.backend.entity.InsulinDeliveryMethod;
import com.diamate.backend.entity.InsulinLog;
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

    private InsulinLogService service;

    @BeforeEach
    void setUp() {
        service = new InsulinLogService(repository, mealLogRepository, new HealthDataAccess(patientAccessRepository),
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
}
