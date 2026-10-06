package com.diamate.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
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
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    private UserService service;

    @BeforeEach
    void setUp() {
        service = new UserService(userRepository);
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

    private static User user(long id, boolean active) {
        User user = new User("patient01@diamate.example", "hash", Role.PATIENT, "Demo Patient", "01",
                LocalDate.of(1992, 7, 1), Gender.MALE);
        ReflectionTestUtils.setField(user, "id", id);
        ReflectionTestUtils.setField(user, "active", active);
        return user;
    }
}
