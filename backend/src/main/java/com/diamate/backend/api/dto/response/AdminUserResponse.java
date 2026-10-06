package com.diamate.backend.api.dto.response;

import java.time.Instant;

import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

// What an ADMIN sees when managing accounts: account data only, never health data, birth date or gender.
public record AdminUserResponse(Long id, String firstName, String lastName, String email, Role role,
        boolean active, boolean demo, Instant createdAt, Instant lastLoginAt) {

    public static AdminUserResponse from(User user) {
        return new AdminUserResponse(user.getId(), user.getFirstName(), user.getLastName(), user.getEmail(),
                user.getRole(), user.isActive(), user.isDemo(), user.getCreatedAt(), user.getLastLoginAt());
    }
}
