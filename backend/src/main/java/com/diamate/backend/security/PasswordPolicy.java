package com.diamate.backend.security;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import com.diamate.backend.exception.InvalidFieldException;

/**
 * Password rules checked at registration, on top of the minimum length in RegisterRequest (8 characters).
 *
 * Follows NIST SP 800-63B: no "must contain an upper-case letter, a digit and a symbol" rules (they push people
 * to predictable passwords like "Password1!"); instead, passwords that attackers try first are refused.
 * Errors are reported on the "password" field, so the app shows them under the password input.
 */
@Component
public class PasswordPolicy {

    /** BCrypt only uses the first 72 bytes and Spring Security refuses longer passwords when hashing. */
    static final int MAX_BYTES = 72;

    private static final String COMMON_PASSWORDS_FILE = "security/common-passwords.txt";

    private final Set<String> commonPasswords;

    public PasswordPolicy() {
        this.commonPasswords = loadCommonPasswords();
    }

    public void check(String password, String email) {
        // Counted in UTF-8 bytes, not characters: "ş" is 2 bytes.
        if (password.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES) {
            throw new InvalidFieldException("password", "Password must be at most " + MAX_BYTES + " bytes");
        }
        String candidate = password.toLowerCase(Locale.ROOT);
        if (commonPasswords.contains(candidate)) {
            throw new InvalidFieldException("password", "This password is too common. Choose a less predictable one");
        }
        String normalizedEmail = email.trim().toLowerCase(Locale.ROOT);
        int at = normalizedEmail.indexOf('@');
        String localPart = at > 0 ? normalizedEmail.substring(0, at) : normalizedEmail;
        if (candidate.equals(normalizedEmail) || candidate.equals(localPart)) {
            throw new InvalidFieldException("password", "Password must not be the same as your email");
        }
    }

    private static Set<String> loadCommonPasswords() {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new ClassPathResource(COMMON_PASSWORDS_FILE).getInputStream(), StandardCharsets.UTF_8))) {
            return reader.lines()
                    .map(String::trim)
                    .filter(line -> !line.isEmpty() && !line.startsWith("#"))
                    .map(line -> line.toLowerCase(Locale.ROOT))
                    .collect(Collectors.toUnmodifiableSet());
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot read " + COMMON_PASSWORDS_FILE, e);
        }
    }
}
