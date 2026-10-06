package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
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

import com.diamate.backend.api.dto.request.ActivityLogRequest;
import com.diamate.backend.api.dto.request.EntrySource;
import com.diamate.backend.api.dto.request.MealLogRequest;
import com.diamate.backend.api.dto.response.ActivityLogResponse;
import com.diamate.backend.api.dto.response.MealLogResponse;
import com.diamate.backend.entity.ActivityIntensity;
import com.diamate.backend.entity.ActivityLog;
import com.diamate.backend.entity.ActivitySource;
import com.diamate.backend.entity.MealLog;
import com.diamate.backend.entity.MealSource;
import com.diamate.backend.entity.MealType;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.ActivityLogRepository;
import com.diamate.backend.repository.MealLogRepository;
import com.diamate.backend.repository.PatientAccessRepository;

/** What differs from glucose for meals and activities: the permission names and the activity source. */
@ExtendWith(MockitoExtension.class)
class MealAndActivityLogServiceTest {

    private static final long PATIENT = 8;
    private static final long CAREGIVER = 4;
    private static final Instant NOW = Instant.parse("2026-10-05T10:00:00Z");
    private static final Instant EARLIER = Instant.parse("2026-10-05T07:45:00Z");

    @Mock
    private MealLogRepository mealRepository;

    @Mock
    private ActivityLogRepository activityRepository;

    @Mock
    private PatientAccessRepository patientAccessRepository;

    @Mock
    private AuditService auditService;

    private MealLogService mealService;
    private ActivityLogService activityService;

    @BeforeEach
    void setUp() {
        HealthDataAccess access = new HealthDataAccess(patientAccessRepository, auditService);
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        mealService = new MealLogService(mealRepository, access, clock);
        activityService = new ActivityLogService(activityRepository, access, clock);
    }

    @Test
    void mealsNeedTheMealsPermission() {
        // Like the demo caregiver and patient08: glucose is shared, meals are not.
        when(patientAccessRepository.canAccess(CAREGIVER, PATIENT, "meals")).thenReturn(false);

        assertThatThrownBy(() -> mealService.list(CAREGIVER, PATIENT, null, null, 0, 50))
                .isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(mealRepository);
    }

    @Test
    void activitiesNeedTheActivityPermission() {
        when(patientAccessRepository.canAccess(CAREGIVER, PATIENT, "activity")).thenReturn(false);

        assertThatThrownBy(() -> activityService.get(CAREGIVER, PATIENT, 1L))
                .isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(activityRepository);
    }

    @Test
    void mealIsSavedWithItsSource() {
        when(mealRepository.saveAndFlush(any(MealLog.class))).thenAnswer(invocation -> withId(invocation.getArgument(0)));

        MealLogResponse meal = mealService.create(PATIENT, PATIENT, new MealLogRequest(MealType.LUNCH, EARLIER,
                " lentil soup ", new BigDecimal("45.5"), null, null, null, null, EntrySource.AI_ASSISTANT, null)).log();

        assertThat(meal.mealType()).isEqualTo(MealType.LUNCH);
        assertThat(meal.description()).isEqualTo("lentil soup");
        assertThat(meal.carbsG()).isEqualByComparingTo("45.5");
        assertThat(meal.source()).isEqualTo(MealSource.AI_ASSISTANT);
    }

    @Test
    void activityIsAlwaysSavedAsManual() {
        when(activityRepository.saveAndFlush(any(ActivityLog.class))).thenAnswer(invocation -> withId(invocation.getArgument(0)));

        ActivityLogResponse activity = activityService.create(PATIENT, PATIENT, new ActivityLogRequest(" walking ",
                EARLIER, new BigDecimal("30"), 3500, 110, null, ActivityIntensity.MODERATE, null, null)).log();

        assertThat(activity.activityType()).isEqualTo("walking");
        assertThat(activity.avgHeartRate()).isEqualTo(110);
        assertThat(activity.source()).isEqualTo(ActivitySource.MANUAL);
    }

    private static <T> T withId(T log) {
        ReflectionTestUtils.setField(log, "id", 300L);
        return log;
    }
}
