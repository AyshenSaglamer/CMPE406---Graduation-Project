package com.diamate.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.oauth2.core.OAuth2ErrorCodes;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;

import com.diamate.backend.entity.Role;
import com.diamate.backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class ActiveAccountValidatorTest {

    private static final UUID SESSION = UUID.fromString("7d5e2a1c-0b9f-4c6e-8a3d-2f1b0c9e8d7a");

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private ActiveAccountValidator validator;

    @Test
    void activeAccountWithTheSameRoleAndAnOpenSessionPasses() {
        when(userRepository.findRoleForOpenSession(eq(5L), eq(SESSION), any())).thenReturn(Optional.of(Role.PATIENT));

        assertThat(validator.validate(token("5", "PATIENT", SESSION.toString())).hasErrors()).isFalse();
    }

    @Test
    void disabledAccountOrClosedSessionFails() {
        // The query returns a role only for an existing, active account whose session is open (not logged out,
        // not revoked, not expired); the reasons are checked against the real database in RefreshTokenIntegrationTest.
        when(userRepository.findRoleForOpenSession(eq(5L), eq(SESSION), any())).thenReturn(Optional.empty());

        OAuth2TokenValidatorResult result = validator.validate(token("5", "PATIENT", SESSION.toString()));

        assertThat(result.hasErrors()).isTrue();
        assertThat(result.getErrors()).extracting(error -> error.getErrorCode())
                .containsExactly(OAuth2ErrorCodes.INVALID_TOKEN);
    }

    @Test
    void roleChangedSinceTheTokenWasIssuedFails() {
        when(userRepository.findRoleForOpenSession(eq(2L), eq(SESSION), any())).thenReturn(Optional.of(Role.CAREGIVER));

        assertThat(validator.validate(token("2", "CLINICIAN", SESSION.toString())).hasErrors()).isTrue();
    }

    @Test
    void subjectThatIsNotAUserIdFailsWithoutAskingTheDatabase() {
        assertThat(validator.validate(token("admin", "ADMIN", SESSION.toString())).hasErrors()).isTrue();
        verifyNoInteractions(userRepository);
    }

    @Test
    void tokenWithoutASessionOrWithAMalformedOneFailsWithoutAskingTheDatabase() {
        // Tokens issued before V11 have no "sid": they are refused, the app logs in again.
        assertThat(validator.validate(token("5", "PATIENT", null)).hasErrors()).isTrue();
        assertThat(validator.validate(token("5", "PATIENT", "not-a-uuid")).hasErrors()).isTrue();
        verifyNoInteractions(userRepository);
    }

    private static Jwt token(String subject, String role, String sessionId) {
        Jwt.Builder builder = Jwt.withTokenValue("token").header("alg", "HS256").subject(subject)
                .claim(JwtService.ROLE_CLAIM, role);
        if (sessionId != null) {
            builder.claim(JwtService.SESSION_CLAIM, sessionId);
        }
        return builder.build();
    }
}
