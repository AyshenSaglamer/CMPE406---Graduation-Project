package com.diamate.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.response.AdminUserResponse;
import com.diamate.backend.api.dto.response.ProfileResponse;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AccountDisabledException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    /**
     * The caller's own profile. The token is valid for up to an hour, so the account state is checked again here:
     * a user deactivated after logging in gets 403 instead of their data.
     */
    @Transactional(readOnly = true)
    public ProfileResponse getProfile(long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        if (!user.isActive()) {
            throw new AccountDisabledException();
        }
        return ProfileResponse.from(user);
    }

    /** For ADMIN only (enforced in AdminController). Account data, no health data. */
    @Transactional(readOnly = true)
    public List<AdminUserResponse> listUsers() {
        return userRepository.findAllByOrderByIdAsc().stream().map(AdminUserResponse::from).toList();
    }
}
