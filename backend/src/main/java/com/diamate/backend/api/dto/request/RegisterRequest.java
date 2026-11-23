package com.diamate.backend.api.dto.request;

import java.time.LocalDate;

import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

//record: classes that only hold data, for concise code
public record RegisterRequest(

        @NotBlank(message = "First name is required") // It cannot be empty.
        @Size(max = 50, message = "First name must be at most 50 characters") // Maximum 50 characters
        @Pattern(regexp = NAME_PATTERN, message = "First name may only contain letters, spaces, apostrophes, hyphens and dots")
        String firstName,

        @NotBlank(message = "Last name is required")
        @Size(max = 50, message = "Last name must be at most 50 characters")
        @Pattern(regexp = NAME_PATTERN, message = "Last name may only contain letters, spaces, apostrophes, hyphens and dots")
        String lastName,

        @NotNull(message = "Date of birth is required")
        @Past(message = "Date of birth must be in the past") // Today or a future date is rejected
        LocalDate dateOfBirth, // JSON format "yyyy-MM-dd"
        
        @NotNull(message = "Gender is required") // FEMALE, MALE or OTHER
        Gender gender,
        
        @NotNull(message = "Role is required") // PATIENT, CLINICIAN, CAREGIVER, ADMIN
        Role role,
        
        @NotBlank(message = "Email is required")
        @Email(message = "Email format is invalid") // Must be a valid email format.
        @Size(max = 150, message = "Email must be at most 150 characters")
        String email,

        @NotBlank(message = "Password is required")
        @Size(min = 8, message = "Password must be at least 8 characters")
        String password) { // more rules (72-byte limit, common passwords, not the email) in PasswordPolicy

    /**
     * Letters of any language, with spaces, apostrophes (' and the ’ that phone keyboards type), hyphens and dots
     * between them: "Ayşe Nur", "O'Brien", "Jean-Luc", "J. R.". No digits, symbols or emoji.
     * \p{M} allows accents typed as a separate combining mark. Blank is let through here so that only
     * @NotBlank reports it (one message per mistake).
     */
    static final String NAME_PATTERN = "^\\s*(\\p{L}[\\p{L}\\p{M} .'\u2019-]*)?$";

}