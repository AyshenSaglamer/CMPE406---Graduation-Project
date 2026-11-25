package com.diamate.backend.service;

import java.time.Clock;
import java.time.LocalDate;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.diamate.backend.api.dto.request.DependentRequest;
import com.diamate.backend.api.dto.response.DependentResponse;
import com.diamate.backend.entity.DiabetesType;
import com.diamate.backend.entity.PatientProfile;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.InvalidFieldException;
import com.diamate.backend.exception.ResourceConflictException;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.CareRelationshipRepository;
import com.diamate.backend.repository.PatientProfileRepository;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.service.AuditService.DependentChange;

/**
 * Family members without an account (e.g. a child), whose diary a caregiver keeps: the "add family member" screen.
 *
 * A dependent is a PATIENT user without email and password (V12), with a patient_profiles row (so logs can be
 * saved) and an ACTIVE care relationship with manages_patient = true to the caregiver who added them. Through that
 * relationship the caregiver sees all of the dependent's data and writes their logs (fn_can_access 'write',
 * HealthDataAccess.checkCanWrite). Nobody can log in as a dependent: there is no email to log in with, and the
 * database refuses a login session for a user without a password.
 *
 * Only the managing caregiver can correct the details; for anyone else the dependent does not exist (404).
 */
@Service
public class DependentService {

    private static final String NOT_FOUND = "Dependent not found";

    /** Enough for a family; stops a single account from creating patient records without end. */
    static final int MAX_DEPENDENTS_PER_CAREGIVER = 10;

    private final UserRepository userRepository;
    private final PatientProfileRepository profileRepository;
    private final CareRelationshipRepository careRepository;
    private final AuditService auditService;
    private final Clock clock;

    public DependentService(UserRepository userRepository, PatientProfileRepository profileRepository,
            CareRelationshipRepository careRepository, AuditService auditService, Clock clock) {
        this.userRepository = userRepository;
        this.profileRepository = profileRepository;
        this.careRepository = careRepository;
        this.auditService = auditService;
        this.clock = clock;
    }

    /** The caller has the CAREGIVER role (controller). One transaction: user, profile and relationship, or nothing. */
    @Transactional
    public DependentResponse create(long caregiverId, DependentRequest request) {
        checkDateOfBirth(request.dateOfBirth());
        careRepository.lockMemberForDependent(caregiverId);
        if (careRepository.countManagedBy(caregiverId) >= MAX_DEPENDENTS_PER_CAREGIVER) {
            throw new ResourceConflictException(
                    "You can manage at most " + MAX_DEPENDENTS_PER_CAREGIVER + " family members");
        }
        User user = userRepository.saveAndFlush(User.dependent(request.firstName().trim(),
                request.lastName().trim(), request.dateOfBirth(), request.gender()));
        PatientProfile profile = profileRepository.saveAndFlush(new PatientProfile(user.getId(),
                diabetesType(request.diabetesType())));
        long relationshipId = careRepository.insertManaging(user.getId(), caregiverId);
        auditService.dependentChanged(caregiverId, user.getId(), relationshipId, DependentChange.DEPENDENT_CREATED);
        return DependentResponse.from(user, profile, relationshipId);
    }

    /** Replaces the details of a dependent the caller manages; 404 for any other patient id. */
    @Transactional
    public DependentResponse update(long caregiverId, long patientId, DependentRequest request) {
        long relationshipId = careRepository.findManagingId(caregiverId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
        User user = userRepository.findById(patientId)
                .filter(found -> !found.hasLogin()) // never reached for an account (care_manager_guard); checked anyway
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
        PatientProfile profile = profileRepository.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
        checkDateOfBirth(request.dateOfBirth());

        user.changePersonalDetails(request.firstName().trim(), request.lastName().trim(), request.dateOfBirth(),
                request.gender());
        profile.changeDiabetesType(diabetesType(request.diabetesType()));
        userRepository.saveAndFlush(user);
        profileRepository.saveAndFlush(profile);
        auditService.dependentChanged(caregiverId, patientId, relationshipId, DependentChange.DEPENDENT_UPDATED);
        return DependentResponse.from(user, profile, relationshipId);
    }

    private void checkDateOfBirth(LocalDate dateOfBirth) {
        if (dateOfBirth.isBefore(LocalDate.now(clock).minusYears(AuthService.MAX_AGE_YEARS))) {
            throw new InvalidFieldException("dateOfBirth",
                    "Date of birth must not be more than " + AuthService.MAX_AGE_YEARS + " years ago");
        }
    }

    private static DiabetesType diabetesType(DiabetesType requested) {
        return requested != null ? requested : DiabetesType.OTHER;
    }
}
