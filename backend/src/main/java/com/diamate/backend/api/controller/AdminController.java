package com.diamate.backend.api.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.diamate.backend.api.dto.response.AdminUserResponse;
import com.diamate.backend.service.UserService;

@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('ADMIN')") // every endpoint in this controller: ADMIN only, others get 403
public class AdminController {

    private final UserService userService;

    public AdminController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/users")
    public List<AdminUserResponse> users() {
        return userService.listUsers();
    }
}
