package com.diamate.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Optional;

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

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private ActiveAccountValidator validator;

    @Test
    void activeAccountWithTheSameRolePasses() {
        when(userRepository.findActiveUserRole(5L)).thenReturn(Optional.of(Role.PATIENT));

        assertThat(validator.validate(token("5", "PATIENT")).hasErrors()).isFalse();
    }

    @Test
    void disabledOrDeletedAccountFails() {
        // The query only returns a role for an existing, active account.
        when(userRepository.findActiveUserRole(5L)).thenReturn(Optional.empty());

        OAuth2TokenValidatorResult result = validator.validate(token("5", "PATIENT"));

        assertThat(result.hasErrors()).isTrue();
        assertThat(result.getErrors()).extracting(error -> error.getErrorCode())
                .containsExactly(OAuth2ErrorCodes.INVALID_TOKEN);
    }

    @Test
    void roleChangedSinceTheTokenWasIssuedFails() {
        when(userRepository.findActiveUserRole(2L)).thenReturn(Optional.of(Role.CAREGIVER));

        assertThat(validator.validate(token("2", "CLINICIAN")).hasErrors()).isTrue();
    }

    @Test
    void subjectThatIsNotAUserIdFailsWithoutAskingTheDatabase() {
        assertThat(validator.validate(token("admin", "ADMIN")).hasErrors()).isTrue();
        verifyNoInteractions(userRepository);
    }

    private static Jwt token(String subject, String role) {
        return Jwt.withTokenValue("token").header("alg", "HS256").subject(subject)
                .claim(JwtService.ROLE_CLAIM, role).build();
    }
}
