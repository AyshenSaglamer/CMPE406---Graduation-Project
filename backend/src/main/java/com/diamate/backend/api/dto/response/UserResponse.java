package com.diamate.backend.api.dto.response;

import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

// The only user fields the API exposes. Never add passwordHash or security counters here.
public record UserResponse(Long id, String firstName, String lastName, String email, Role role) {

    public static UserResponse from(User user) {
        return new UserResponse(user.getId(), user.getFirstName(), user.getLastName(), user.getEmail(), user.getRole());
    }
    
}