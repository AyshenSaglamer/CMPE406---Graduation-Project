package com.diamate.backend.api.dto.request;

import java.time.LocalDate;

import com.diamate.backend.entity.DiabetesType;
import com.diamate.backend.entity.Gender;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * A family member without an account (e.g. a child), added and corrected by the caregiver who manages them:
 * POST /care-team/dependents and PUT /care-team/dependents/{patientId}. PUT replaces every field, so send all of them.
 * No email and no password: a dependent can never log in. No minimum age (a dependent is often a child).
 * diabetesType is optional: OTHER when left out.
 */
public record DependentRequest(

        @NotBlank(message = "First name is required")
        @Size(max = 50, message = "First name must be at most 50 characters")
        @Pattern(regexp = RegisterRequest.NAME_PATTERN, message = "First name may only contain letters, spaces, apostrophes, hyphens and dots")
        String firstName,

        @NotBlank(message = "Last name is required")
        @Size(max = 50, message = "Last name must be at most 50 characters")
        @Pattern(regexp = RegisterRequest.NAME_PATTERN, message = "Last name may only contain letters, spaces, apostrophes, hyphens and dots")
        String lastName,

        @NotNull(message = "Date of birth is required")
        @Past(message = "Date of birth must be in the past")
        LocalDate dateOfBirth,

        @NotNull(message = "Gender is required")
        Gender gender,

        DiabetesType diabetesType) {
}
