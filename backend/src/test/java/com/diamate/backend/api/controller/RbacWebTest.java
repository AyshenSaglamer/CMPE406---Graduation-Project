package com.diamate.backend.api.controller;

import static org.hamcrest.Matchers.startsWith;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import com.diamate.backend.api.dto.response.AdminUserResponse;
import com.diamate.backend.api.dto.response.CareTeamPatientResponse;
import com.diamate.backend.api.dto.response.PatientOverviewResponse;
import com.diamate.backend.api.dto.response.ProfileResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.exception.ResourceNotFoundException;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.PatientService;
import com.diamate.backend.service.UserService;

/**
 * Role-based access: real SecurityConfig and real signed tokens (so the "role" claim -> ROLE_x mapping is
 * tested too); the services are mocks, so no database is needed. Data-level rules (which patient a clinician
 * may see) are tested in PatientServiceTest and against the real database with Postman.
 */
@WebMvcTest(
        controllers = { UserController.class, AdminController.class, CareTeamController.class, PatientController.class },
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class RbacWebTest {

    private static final long PATIENT_ID = 5;
    private static final long CLINICIAN_ID = 2;
    private static final long CAREGIVER_ID = 4;
    private static final long ADMIN_ID = 1;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean
    private UserService userService;

    @MockitoBean
    private PatientService patientService;

    @MockitoBean
    private UserRepository userRepository;

    // Every test account exists, is active and still has the role written in its token.
    @BeforeEach
    void everyAccountIsActive() {
        when(userRepository.findActiveUserRole(anyLong())).thenAnswer(call -> Optional.of(roleOf(call.getArgument(0))));
    }

    // ---------- 401: no or bad token ----------

    @Test
    void requestWithoutTokenGets401ProblemDetail() throws Exception {
        mockMvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, startsWith("Bearer")))
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.detail").value("Authentication required"))
                .andExpect(jsonPath("$.instance").value("/api/v1/users/me"));
    }

    @Test
    void malformedTokenGets401() throws Exception {
        mockMvc.perform(get("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, "Bearer abc.def.ghi"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Invalid or expired access token"));
    }

    @Test
    void expiredTokenGets401() throws Exception {
        Instant twoHoursAgo = Instant.now().minusSeconds(7200);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(jwtProperties.issuer())
                .subject(String.valueOf(PATIENT_ID))
                .issuedAt(twoHoursAgo)
                .expiresAt(twoHoursAgo.plusSeconds(3600))
                .claim(JwtService.ROLE_CLAIM, "PATIENT")
                .build();
        String expired = jwtEncoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
                .getTokenValue();

        mockMvc.perform(get("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Invalid or expired access token"));
        verifyNoInteractions(userService);
        verify(userRepository, never()).findActiveUserRole(anyLong()); // the database is only asked for otherwise valid tokens
    }

    @Test
    void tokenOfADisabledAccountIs401() throws Exception {
        // The token itself is valid (signature, expiry), but the account was disabled after it was issued.
        when(userRepository.findActiveUserRole(PATIENT_ID)).thenReturn(Optional.empty());

        as(get("/api/v1/users/me"), PATIENT_ID, Role.PATIENT)
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Invalid or expired access token"));
        verifyNoInteractions(userService);
    }

    @Test
    void tokenWithAnOutdatedRoleIs401() throws Exception {
        // The token says CLINICIAN, but the role was changed to CAREGIVER after the token was issued.
        when(userRepository.findActiveUserRole(CLINICIAN_ID)).thenReturn(Optional.of(Role.CAREGIVER));

        as(get("/api/v1/care-team/patients"), CLINICIAN_ID, Role.CLINICIAN)
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Invalid or expired access token"));
        verifyNoInteractions(patientService);
    }

    // ---------- /users/me: any role, own profile ----------

    @Test
    void everyRoleCanReadItsOwnProfile() throws Exception {
        when(userService.getProfile(anyLong())).thenAnswer(invocation -> new ProfileResponse(
                invocation.getArgument(0), "First", "Last", "x@example.com", Role.PATIENT,
                LocalDate.of(2000, 1, 15), Gender.FEMALE));

        for (long id : new long[] { PATIENT_ID, CLINICIAN_ID, CAREGIVER_ID, ADMIN_ID }) {
            as(get("/api/v1/users/me"), id, roleOf(id))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.id").value(id))
                    .andExpect(jsonPath("$.dateOfBirth").value("2000-01-15"));
            verify(userService).getProfile(id); // the id comes from the token, never from the request
        }
    }

    // ---------- /admin/users: ADMIN only ----------

    @Test
    void nonAdminRolesGet403OnAdminEndpoints() throws Exception {
        for (long id : new long[] { PATIENT_ID, CLINICIAN_ID, CAREGIVER_ID }) {
            as(get("/api/v1/admin/users"), id, roleOf(id))
                    .andExpect(status().isForbidden())
                    .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                    .andExpect(jsonPath("$.status").value(403))
                    .andExpect(jsonPath("$.detail").value("You do not have permission to access this resource"));
        }
        verifyNoInteractions(userService);
    }

    @Test
    void adminCanListUsers() throws Exception {
        when(userService.listUsers()).thenReturn(List.of(new AdminUserResponse(
                1L, "DiaMate", "Admin", "admin@diamate.example", Role.ADMIN, true, true, Instant.now(), null)));

        as(get("/api/v1/admin/users"), ADMIN_ID, Role.ADMIN)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].email").value("admin@diamate.example"))
                .andExpect(jsonPath("$[0].dateOfBirth").doesNotExist());
    }

    // ---------- /care-team/patients: CLINICIAN and CAREGIVER ----------

    @Test
    void patientAndAdminGet403OnCareTeamList() throws Exception {
        as(get("/api/v1/care-team/patients"), PATIENT_ID, Role.PATIENT).andExpect(status().isForbidden());
        as(get("/api/v1/care-team/patients"), ADMIN_ID, Role.ADMIN).andExpect(status().isForbidden());
        verifyNoInteractions(patientService);
    }

    @Test
    void clinicianAndCaregiverGetTheirOwnPatients() throws Exception {
        when(patientService.getCareTeamPatients(anyLong())).thenReturn(List.of(new CareTeamPatientResponse(
                PATIENT_ID, "Demo Patient", "01", true, true, true, true, true, true, false)));

        for (long id : new long[] { CLINICIAN_ID, CAREGIVER_ID }) {
            as(get("/api/v1/care-team/patients"), id, roleOf(id))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$[0].patientId").value(PATIENT_ID));
            verify(patientService).getCareTeamPatients(id);
        }
    }

    // ---------- /patients/{id}/overview: data-level check in the service ----------

    @Test
    void overviewIsReturnedWhenTheServiceAllowsIt() throws Exception {
        when(patientService.getOverview(CLINICIAN_ID, PATIENT_ID)).thenReturn(new PatientOverviewResponse(
                PATIENT_ID, "Demo Patient", "01", "MALE", 34, "TYPE_1", "PUMP", 70, 180, 96, Instant.now(), 1));

        as(get("/api/v1/patients/{id}/overview", PATIENT_ID), CLINICIAN_ID, Role.CLINICIAN)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patientId").value(PATIENT_ID))
                .andExpect(jsonPath("$.lastGlucoseMgdl").value(96));
    }

    @Test
    void overviewWithoutAccessIs404ProblemDetail() throws Exception {
        when(patientService.getOverview(CLINICIAN_ID, 8L)).thenThrow(new ResourceNotFoundException("Patient not found"));

        as(get("/api/v1/patients/{id}/overview", 8L), CLINICIAN_ID, Role.CLINICIAN)
                .andExpect(status().isNotFound())
                .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value("Patient not found"));
    }

    @Test
    void nonNumericPatientIdIs400() throws Exception {
        as(get("/api/v1/patients/abc/overview"), CLINICIAN_ID, Role.CLINICIAN)
                .andExpect(status().isBadRequest());
        verifyNoInteractions(patientService);
    }

    // ---------- helpers ----------

    /** Sends the request with a real token signed by the application's JwtEncoder. */
    private ResultActions as(MockHttpServletRequestBuilder request,
            long userId, Role role) throws Exception {
        return mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenFor(userId, role)));
    }

    private String tokenFor(long userId, Role role) {
        User user = new User("u" + userId + "@example.com", "hash", role, "First", "Last",
                LocalDate.of(2000, 1, 15), Gender.OTHER);
        ReflectionTestUtils.setField(user, "id", userId);
        return new JwtService(jwtEncoder, jwtProperties).generateToken(user);
    }

    private static Role roleOf(long id) {
        if (id == ADMIN_ID) {
            return Role.ADMIN;
        }
        if (id == CLINICIAN_ID) {
            return Role.CLINICIAN;
        }
        if (id == CAREGIVER_ID) {
            return Role.CAREGIVER;
        }
        return Role.PATIENT;
    }
}
