package com.diamate.backend.api.dto.request;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;

import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

//record: classes that only hold data, for concise code
public record RegisterRequest(

        @NotBlank(message = "First name is required") // It cannot be empty.
        @Size(max = 50, message = "First name must be at most 50 characters") // maximum 50 characters
        String firstName,

        @NotBlank(message = "Last name is required")
        @Size(max = 50, message = "Last name must be at most 50 characters")
        String lastName,

        @NotBlank(message = "Email is required")
        @Email(message = "Email format is invalid") // Must be a valid email format.
        @Size(max = 150, message = "Email must be at most 150 characters")
        String email,

        @NotBlank(message = "Password is required")
        @Size(min = 8, message = "Password must be at least 8 characters")
        String password,

        @NotNull(message = "Role is required") // It cannot be empty.
        Role role,

        // JSON format "yyyy-MM-dd", e.g. "2001-04-23". The minimum age (16) is a business rule in AuthService.
        @NotNull(message = "Date of birth is required")
        @Past(message = "Date of birth must be in the past") // today or a future date is rejected
        LocalDate dateOfBirth,

        @NotNull(message = "Gender is required") // FEMALE, MALE or OTHER
        Gender gender) {

    /**
     * BCrypt only uses the first 72 bytes of a password and Spring Security rejects longer ones.
     * Counted in UTF-8 bytes, not characters: "ş" is 2 bytes.
     */
    @AssertTrue(message = "Password must be at most 72 bytes")
    public boolean isPasswordWithinBcryptLimit() {
        return password == null || password.getBytes(StandardCharsets.UTF_8).length <= 72;
    }
    
}