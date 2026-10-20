package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import com.diamate.backend.api.dto.response.AdminUserResponse;
import com.diamate.backend.api.dto.response.ProfileResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AccountDisabledException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private AuditService auditService;

    private UserService service;

    @BeforeEach
    void setUp() {
        service = new UserService(userRepository, auditService);
    }

    @Test
    void profileOfActiveUser() {
        when(userRepository.findById(5L)).thenReturn(Optional.of(user(5L, true)));

        ProfileResponse profile = service.getProfile(5L);

        assertThat(profile.id()).isEqualTo(5L);
        assertThat(profile.dateOfBirth()).isEqualTo(LocalDate.of(1992, 7, 1));
        assertThat(profile.gender()).isEqualTo(Gender.MALE);
    }

    @Test
    void deactivatedUserWithAStillValidTokenGets403() {
        when(userRepository.findById(5L)).thenReturn(Optional.of(user(5L, false)));

        assertThatThrownBy(() -> service.getProfile(5L)).isInstanceOf(AccountDisabledException.class);
    }

    @Test
    void unknownUserIs404() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getProfile(99L)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void adminListContainsNoHealthOrPersonalFields() {
        when(userRepository.findAllByOrderByIdAsc()).thenReturn(List.of(user(5L, true)));

        List<AdminUserResponse> users = service.listUsers();

        assertThat(users).hasSize(1);
        assertThat(AdminUserResponse.class.getRecordComponents())
                .extracting(c -> c.getName())
                .doesNotContain("dateOfBirth", "gender", "passwordHash");
    }

    // ---------- PATCH /admin/users/{id}/status ----------

    @Test
    void adminDeactivatesAnAccountAndItIsAudited() {
        User patient = user(5L, true);
        when(userRepository.findById(5L)).thenReturn(Optional.of(patient));

        AdminUserResponse response = service.changeStatus(1L, 5L, false);

        assertThat(response.active()).isFalse();
        assertThat(patient.isActive()).isFalse(); // written on commit (managed entity, @DynamicUpdate)
        verify(auditService).accountStatusChanged(1L, 5L, false);
    }

    @Test
    void adminApprovesAWaitingClinician() {
        User clinician = user(7L, false);
        when(userRepository.findById(7L)).thenReturn(Optional.of(clinician));

        assertThat(service.changeStatus(1L, 7L, true).active()).isTrue();
        verify(auditService).accountStatusChanged(1L, 7L, true);
    }

    @Test
    void theSameStatusAgainChangesNothingAndIsNotAudited() {
        when(userRepository.findById(5L)).thenReturn(Optional.of(user(5L, true)));

        assertThat(service.changeStatus(1L, 5L, true).active()).isTrue();
        verifyNoInteractions(auditService);
    }

    @Test
    void anAdminCannotChangeTheirOwnStatus() {
        assertThatThrownBy(() -> service.changeStatus(1L, 1L, false))
                .isInstanceOf(ResourceConflictException.class)
                .hasMessage("An administrator cannot change the status of their own account");
        verifyNoInteractions(userRepository, auditService);
    }

    @Test
    void unknownAccountIs404() {
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.changeStatus(1L, 999L, false))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessage("User not found");
        verifyNoInteractions(auditService);
    }

    private static User user(long id, boolean active) {
        User user = new User("Demo Patient", "01",
                LocalDate.of(1992, 7, 1), Gender.MALE, Role.PATIENT, "patient01@diamate.example", "hash");
        ReflectionTestUtils.setField(user, "id", id);
        ReflectionTestUtils.setField(user, "active", active);
        return user;
    }
}
