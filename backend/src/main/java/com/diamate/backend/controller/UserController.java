package com.diamate.backend.controller;

import com.diamate.backend.entity.User;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.JwtService;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import jakarta.validation.Valid;
import com.diamate.backend.dto.RegisterRequest;
import com.diamate.backend.dto.LoginRequest;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public UserController(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

@PostMapping("/register")
public ResponseEntity<?> register(
        @Valid @RequestBody RegisterRequest request
) {

    if (userRepository.existsByEmail(request.getEmail())) {
        return ResponseEntity
                .status(HttpStatus.CONFLICT)
                .body(Map.of(
                        "message", "Email already registered"
                ));
    }

    String hashedPassword =
            passwordEncoder.encode(request.getPassword());

    User user = new User(
            request.getName(),
            request.getEmail(),
            hashedPassword
    );

    User savedUser = userRepository.save(user);

    return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(Map.of(
                    "message", "Registration successful",
                    "id", savedUser.getId(),
                    "name", savedUser.getName(),
                    "email", savedUser.getEmail()
            ));
}
@PostMapping("/login")
public ResponseEntity<?> login(
        @Valid @RequestBody LoginRequest request
) {

    Optional<User> optionalUser =
            userRepository.findByEmail(request.getEmail());

    if (optionalUser.isEmpty()) {
        return ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .body(Map.of(
                        "message", "Invalid email or password"
                ));
    }

    User user = optionalUser.get();

    boolean passwordMatches =
            passwordEncoder.matches(
                    request.getPassword(),
                    user.getPassword()
            );

    if (!passwordMatches) {
        return ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .body(Map.of(
                        "message", "Invalid email or password"
                ));
    }

    String token = jwtService.generateToken(user.getEmail());

    return ResponseEntity.ok(
            Map.of(
                    "message", "Login successful",
                    "email", user.getEmail(),
                    "name", user.getName(),
                    "token", token
            )
    );
}
@GetMapping("/profile")
public ResponseEntity<?> profile(
        @RequestHeader(value = "Authorization", required = false)
        String authorizationHeader
) {

    if (authorizationHeader == null ||
            !authorizationHeader.startsWith("Bearer ")) {

        return ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("message", "Unauthorized"));
    }

    String token = authorizationHeader.substring(7);

    if (!jwtService.isTokenValid(token)) {

        return ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("message", "Invalid or expired token"));
    }

    String email = jwtService.extractEmail(token);

    return ResponseEntity.ok(
            Map.of(
                    "message", "Authorized",
                    "email", email
            )
    );
}
}
