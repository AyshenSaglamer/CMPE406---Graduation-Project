package com.diamate.backend.dto;

import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

// The only user fields the API exposes. Never add passwordHash or security counters here.
public record UserResponse(Long id, String fullName, String email, Role role) {

    public static UserResponse from(User user) {
        return new UserResponse(user.getId(), user.getFullName(), user.getEmail(), user.getRole());
    }
}
