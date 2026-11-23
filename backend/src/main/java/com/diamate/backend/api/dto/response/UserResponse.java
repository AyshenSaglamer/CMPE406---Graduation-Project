package com.diamate.backend.api.dto.response;

import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;

// The only user fields the API exposes. Never add passwordHash or security counters here.
public record UserResponse(Long id, String firstName, String lastName, Role role, String email) {

    public static UserResponse from(User user) {
        return new UserResponse(user.getId(), user.getFirstName(), user.getLastName(), user.getRole(), user.getEmail());
    }
    
}