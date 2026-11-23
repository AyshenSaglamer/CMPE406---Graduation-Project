package com.diamate.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

import com.diamate.backend.api.dto.request.LoginRequest;
import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.exception.AccountLockedException;
import com.diamate.backend.exception.InvalidCredentialsException;

/** The login lock with real row locks: parallel wrong passwords cannot get more than 4 tries past the limit of 5. */
class LoginLockIntegrationTest extends PostgresIntegrationTest {

    @Test
    void parallelWrongPasswordsLockTheAccountAfterExactlyFiveAttempts() throws Exception {
        String email = email("Lock");
        authService.register(new RegisterRequest("Lock", "Test", LocalDate.of(1990, 1, 1), Gender.OTHER,
                Role.PATIENT, email, PASSWORD));

        List<Callable<String>> attempts = IntStream.range(0, 20).<Callable<String>>mapToObj(i -> () -> {
            try {
                authService.login(new LoginRequest(email, "Wrong-Password-" + i));
                return "logged in";
            } catch (InvalidCredentialsException wrong) {
                return "wrong";
            } catch (AccountLockedException locked) {
                return "locked";
            }
        }).toList();
        List<String> results = new ArrayList<>();
        ExecutorService pool = Executors.newFixedThreadPool(20);
        try {
            for (Future<String> result : pool.invokeAll(attempts)) {
                results.add(result.get());
            }
        } finally {
            pool.shutdown();
        }

        // Attempts 1-4 are "wrong", the 5th locks the account, every later one is refused while locked.
        assertThat(results).filteredOn("wrong"::equals).hasSize(4);
        assertThat(results).filteredOn("locked"::equals).hasSize(16);
        assertThatThrownBy(() -> authService.login(new LoginRequest(email, PASSWORD)))
                .isInstanceOf(AccountLockedException.class);
    }
}
