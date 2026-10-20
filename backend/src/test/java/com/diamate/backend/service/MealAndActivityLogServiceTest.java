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
import com.diamate.backend.repository.InsulinLogRepository;
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
    private InsulinLogRepository insulinRepository;

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
        mealService = new MealLogService(mealRepository, insulinRepository, access, clock);
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
    void activityIsSavedWithItsSourceAndManualByDefault() {
        when(activityRepository.saveAndFlush(any(ActivityLog.class))).thenAnswer(invocation -> withId(invocation.getArgument(0)));

        ActivityLogResponse activity = activityService.create(PATIENT, PATIENT, new ActivityLogRequest(" walking ",
                EARLIER, new BigDecimal("30"), 3500, 110, null, ActivityIntensity.MODERATE, null, null, null)).log();
        // Allowed since V6: an activity the patient confirmed in the AI assistant keeps that origin.
        ActivityLogResponse fromDia = activityService.create(PATIENT, PATIENT, new ActivityLogRequest("running",
                EARLIER, new BigDecimal("20"), null, null, null, null, null, EntrySource.AI_ASSISTANT, null)).log();

        assertThat(activity.activityType()).isEqualTo("walking");
        assertThat(activity.avgHeartRate()).isEqualTo(110);
        assertThat(activity.source()).isEqualTo(ActivitySource.MANUAL);
        assertThat(fromDia.source()).isEqualTo(ActivitySource.AI_ASSISTANT);
    }

    // ---------- get, update, delete ----------

    @Test
    void careTeamWithThePermissionGetsAPageOfMealsAndActivities() {
        when(patientAccessRepository.canAccess(CAREGIVER, PATIENT, "meals")).thenReturn(true);
        when(patientAccessRepository.canAccess(CAREGIVER, PATIENT, "activity")).thenReturn(true);
        when(mealRepository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(meal()), PageRequest.of(0, 50), 1));
        when(activityRepository.findInRange(eq(PATIENT), any(), any(), any()))
                .thenReturn(new PageImpl<>(List.of(activity()), PageRequest.of(0, 50), 1));

        assertThat(mealService.list(CAREGIVER, PATIENT, null, null, 0, 50).items())
                .extracting(MealLogResponse::id).containsExactly(300L);
        assertThat(activityService.list(CAREGIVER, PATIENT, null, null, 0, 50).items())
                .extracting(ActivityLogResponse::id).containsExactly(400L);
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.MEAL_LOGS, true);
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.ACTIVITY_LOGS, true);
    }

    @Test
    void careTeamWithTheMealsPermissionReadsOneMeal() {
        when(patientAccessRepository.canAccess(CAREGIVER, PATIENT, "meals")).thenReturn(true);
        when(mealRepository.findByIdAndPatientId(300L, PATIENT)).thenReturn(Optional.of(meal()));

        assertThat(mealService.get(CAREGIVER, PATIENT, 300L).mealType()).isEqualTo(MealType.BREAKFAST);
        verify(auditService).patientDataViewed(CAREGIVER, PATIENT, PatientDataType.MEAL_LOGS, true);
    }

    @Test
    void mealUpdateReplacesTheValuesButNotTheSource() {
        MealLog existing = meal();
        when(mealRepository.findByIdAndPatientId(300L, PATIENT)).thenReturn(Optional.of(existing));
        when(mealRepository.saveAndFlush(existing)).thenReturn(existing);

        MealLogResponse updated = mealService.update(PATIENT, PATIENT, 300L, new MealLogRequest(MealType.DINNER, EARLIER,
                " pasta ", new BigDecimal("80"), new BigDecimal("650"), null, null, null, EntrySource.AI_ASSISTANT, null));

        assertThat(updated.mealType()).isEqualTo(MealType.DINNER);
        assertThat(updated.description()).isEqualTo("pasta");
        assertThat(updated.carbsG()).isEqualByComparingTo("80");
        assertThat(updated.source()).isEqualTo(MealSource.MANUAL);
    }

    @Test
    void deletingAMealUnlinksItsInsulinDoses() {
        // Otherwise a dose keeps pointing to a meal that is gone, and saving that dose again fails ("Meal log not found").
        MealLog existing = meal();
        when(mealRepository.findByIdAndPatientId(300L, PATIENT)).thenReturn(Optional.of(existing));

        mealService.delete(PATIENT, PATIENT, 300L);

        assertThat(existing.getDeletedAt()).isEqualTo(NOW);
        verify(insulinRepository).unlinkMeal(300L);
        verify(mealRepository, never()).delete(any());
    }

    @Test
    void aMissingMealIs404AndNothingIsUnlinked() {
        when(mealRepository.findByIdAndPatientId(999L, PATIENT)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> mealService.delete(PATIENT, PATIENT, 999L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("Meal log not found");
        verifyNoInteractions(insulinRepository);
    }

    @Test
    void activitySourceDoesNotChangeOnUpdate() {
        ActivityLog existing = activity();
        when(activityRepository.findByIdAndPatientId(400L, PATIENT)).thenReturn(Optional.of(existing));
        when(activityRepository.saveAndFlush(existing)).thenReturn(existing);

        ActivityLogResponse updated = activityService.update(PATIENT, PATIENT, 400L, new ActivityLogRequest(" cycling ",
                EARLIER, new BigDecimal("45"), null, 130, null, ActivityIntensity.HIGH, null, EntrySource.AI_ASSISTANT, null));

        assertThat(updated.activityType()).isEqualTo("cycling");
        assertThat(updated.durationMinutes()).isEqualByComparingTo("45");
        assertThat(updated.intensity()).isEqualTo(ActivityIntensity.HIGH);
        assertThat(updated.source()).isEqualTo(ActivitySource.MANUAL);
    }

    @Test
    void activityDeleteIsASoftDelete() {
        ActivityLog existing = activity();
        when(activityRepository.findByIdAndPatientId(400L, PATIENT)).thenReturn(Optional.of(existing));

        activityService.delete(PATIENT, PATIENT, 400L);

        assertThat(existing.getDeletedAt()).isEqualTo(NOW);
        verify(activityRepository, never()).delete(any());
    }

    @Test
    void aPatientCannotChangeAnotherPatientsMealsOrActivities() {
        assertThatThrownBy(() -> mealService.delete(PATIENT, 5L, 300L)).isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> activityService.delete(PATIENT, 5L, 400L)).isInstanceOf(ResourceNotFoundException.class);
        verifyNoInteractions(mealRepository, activityRepository, insulinRepository);
    }

    private static MealLog meal() {
        MealLog log = new MealLog(PATIENT, null, MealSource.MANUAL);
        log.update(MealType.BREAKFAST, EARLIER, "oatmeal", new BigDecimal("40"), null, null, null, null);
        return withId(log, 300L);
    }

    private static ActivityLog activity() {
        ActivityLog log = new ActivityLog(PATIENT, null, ActivitySource.MANUAL);
        log.update("walking", EARLIER, new BigDecimal("30"), null, null, null, ActivityIntensity.LOW, null);
        return withId(log, 400L);
    }

    private static <T> T withId(T log, long id) {
        ReflectionTestUtils.setField(log, "id", id);
        return log;
    }

    private static <T> T withId(T log) {
        ReflectionTestUtils.setField(log, "id", 300L);
        return log;
    }
}
