package com.diamate.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

import com.diamate.backend.exception.InvalidFieldException;

class PasswordPolicyTest {

    private final PasswordPolicy policy = new PasswordPolicy();

    @Test
    void anOrdinaryPasswordIsAccepted() {
        assertThatCode(() -> policy.check("Kara-Deniz-42", "melih@example.com")).doesNotThrowAnyException();
        assertThatCode(() -> policy.check("şeker ölçerim mavi", "melih@example.com")).doesNotThrowAnyException();
    }

    @Test
    void commonPasswordsAreRefusedWhateverTheirCase() {
        for (String password : new String[] { "password123", "Password123", "12345678", "QWERTY123", "Fenerbahce",
                "DiaMate123" }) {
            assertThatThrownBy(() -> policy.check(password, "melih@example.com"))
                    .as(password)
                    .isInstanceOf(InvalidFieldException.class)
                    .hasMessage("This password is too common. Choose a less predictable one");
        }
    }

    @Test
    void theEmailOrItsFirstPartIsNotAPassword() {
        assertThatThrownBy(() -> policy.check("Melih.Kocabiyik@Example.com", " melih.kocabiyik@example.com "))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Password must not be the same as your email");
        assertThatThrownBy(() -> policy.check("melih.kocabiyik", "melih.kocabiyik@example.com"))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Password must not be the same as your email");
    }

    @Test
    void atMost72BytesCountedInUtf8() {
        assertThatCode(() -> policy.check("a".repeat(72), "melih@example.com")).doesNotThrowAnyException();
        // 37 x "ş" is only 37 characters but 74 bytes: BCrypt would refuse it.
        assertThatThrownBy(() -> policy.check("ş".repeat(37), "melih@example.com"))
                .isInstanceOf(InvalidFieldException.class)
                .hasMessage("Password must be at most 72 bytes");
    }

    @Test
    void errorsAreReportedOnThePasswordField() {
        assertThatThrownBy(() -> policy.check("12345678", "melih@example.com"))
                .satisfies(e -> assertThat(((InvalidFieldException) e).getField()).isEqualTo("password"));
    }
}
