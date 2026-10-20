package com.diamate.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.response.AdminUserResponse;
import com.diamate.backend.api.dto.response.ProfileResponse;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.AccountDisabledException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final AuditService auditService;

    public UserService(UserRepository userRepository, AuditService auditService) {
        this.userRepository = userRepository;
        this.auditService = auditService;
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

    /**
     * For ADMIN only (enforced in AdminController): turns an account on or off. Off takes effect at once: the account
     * cannot log in (403) and the tokens it already has get 401 (ActiveAccountValidator). On approves a clinician
     * who registered (they start inactive) or brings back a stopped account. Asking for the status the account
     * already has changes nothing; only a real change is audited.
     *
     * An admin cannot change their own status: switching yourself off by mistake would leave no way back through the
     * API (and switching yourself on is not needed: an inactive admin cannot call this).
     */
    @Transactional
    public AdminUserResponse changeStatus(long adminId, long userId, boolean active) {
        if (adminId == userId) {
            throw new ResourceConflictException("An administrator cannot change the status of their own account");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        if (user.isActive() != active) {
            user.changeActive(active); // @DynamicUpdate: only is_active is written
            auditService.accountStatusChanged(adminId, userId, active);
        }
        return AdminUserResponse.from(user);
    }
}
