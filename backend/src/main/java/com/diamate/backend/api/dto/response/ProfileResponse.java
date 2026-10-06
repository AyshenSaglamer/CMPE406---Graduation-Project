package com.diamate.backend.api.dto.response;

import java.time.LocalDate;

import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

// The logged-in user's own profile (GET /api/v1/users/me). Personal data, so only ever returned to its owner.
public record ProfileResponse(Long id, String firstName, String lastName, String email, Role role,
        LocalDate dateOfBirth, Gender gender) {

    public static ProfileResponse from(User user) {
        return new ProfileResponse(user.getId(), user.getFirstName(), user.getLastName(), user.getEmail(),
                user.getRole(), user.getDateOfBirth(), user.getGender());
    }
}
