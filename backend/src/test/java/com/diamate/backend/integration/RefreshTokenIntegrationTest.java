package com.diamate.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidationException;

import com.diamate.backend.api.dto.request.LoginRequest;
import com.diamate.backend.api.dto.request.RefreshRequest;
import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.api.dto.response.AuthResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.exception.InvalidRefreshTokenException;

/**
 * Refresh tokens and logout against the real auth_sessions table (V11) and the real token check
 * (UserRepository.findRoleForOpenSession through the application's JwtDecoder).
 */
class RefreshTokenIntegrationTest extends PostgresIntegrationTest {

    @Autowired
    private JwtDecoder jwtDecoder;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void refreshRotatesAndAReusedTokenClosesTheSession() {
        AuthResponse login = registerAndLogin("Refresh");
        assertThat(jwtDecoder.decode(login.accessToken())).isNotNull();

        AuthResponse refreshed = authService.refresh(new RefreshRequest(login.refreshToken()));
        assertThat(refreshed.refreshToken()).isNotEqualTo(login.refreshToken());
        assertThat(jwtDecoder.decode(refreshed.accessToken()).getClaimAsString("sid"))
                .isEqualTo(jwtDecoder.decode(login.accessToken()).getClaimAsString("sid")); // same session

        // The first refresh token again: only a copy can still be in use. The whole session ends.
        assertThatThrownBy(() -> authService.refresh(new RefreshRequest(login.refreshToken())))
                .isInstanceOf(InvalidRefreshTokenException.class);
        assertThatThrownBy(() -> authService.refresh(new RefreshRequest(refreshed.refreshToken())))
                .isInstanceOf(InvalidRefreshTokenException.class);
        assertThatThrownBy(() -> jwtDecoder.decode(refreshed.accessToken())).isInstanceOf(JwtValidationException.class);
        assertThat(jdbc.queryForObject("select count(*) from audit_logs where user_id = ? and action = ?",
                Long.class, login.user().id(), "REFRESH_TOKEN_REUSED")).isEqualTo(1L);
    }

    @Test
    void logoutEndsTheAccessAndRefreshTokenAtOnceButNotOtherDevices() {
        AuthResponse phone = registerAndLogin("Logout");
        AuthResponse tablet = authService.login(new LoginRequest(phone.user().email(), PASSWORD));
        long userId = phone.user().id();
        UUID phoneSession = UUID.fromString(jwtDecoder.decode(phone.accessToken()).getClaimAsString("sid"));

        authService.logout(userId, phoneSession);

        assertThatThrownBy(() -> jwtDecoder.decode(phone.accessToken())).isInstanceOf(JwtValidationException.class);
        assertThatThrownBy(() -> authService.refresh(new RefreshRequest(phone.refreshToken())))
                .isInstanceOf(InvalidRefreshTokenException.class);
        assertThat(jwtDecoder.decode(tablet.accessToken())).isNotNull();
        assertThat(jdbc.queryForObject("select count(*) from audit_logs where user_id = ? and action = 'LOGOUT'",
                Long.class, userId)).isEqualTo(1L);
    }

    @Test
    void onlyTheHashOfTheRefreshTokenIsStored() {
        AuthResponse login = registerAndLogin("Hash");

        assertThat(jdbc.queryForObject("select count(*) from auth_sessions where refresh_token_hash = ?", Long.class,
                login.refreshToken())).isZero();
        assertThat(jdbc.queryForObject("select count(*) from auth_sessions where user_id = ?", Long.class,
                login.user().id())).isEqualTo(1L);
    }

    @Test
    void aDisabledAccountCannotRefresh() {
        AuthResponse login = registerAndLogin("Disabled");
        jdbc.update("update users set is_active = false where id = ?", login.user().id());

        assertThatThrownBy(() -> authService.refresh(new RefreshRequest(login.refreshToken())))
                .isInstanceOf(InvalidRefreshTokenException.class);
        assertThat(jdbc.queryForObject("select revoke_reason from auth_sessions where user_id = ?", String.class,
                login.user().id())).isEqualTo("ACCOUNT_DISABLED");
    }

    private AuthResponse registerAndLogin(String name) {
        String email = email(name);
        authService.register(new RegisterRequest(name, "Test", LocalDate.of(1990, 1, 1), Gender.OTHER, Role.PATIENT,
                email, PASSWORD));
        return authService.login(new LoginRequest(email, PASSWORD));
    }
}
