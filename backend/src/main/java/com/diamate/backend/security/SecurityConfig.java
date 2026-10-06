package com.diamate.backend.security;

import java.util.Arrays;
import java.util.Base64;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;

@Configuration
@EnableMethodSecurity // enables @PreAuthorize("hasRole(...)") on controller/service methods
@EnableConfigurationProperties(JwtProperties.class)
public class SecurityConfig {

    private static final int MIN_SECRET_BYTES = 32; // HS256 needs a key of at least 256 bits

    // Reachable without a token. Any HTTP method is let through, so a wrong method gets 405 from Spring MVC
    // instead of a misleading 401 (only POST is mapped on the auth endpoints, so nothing else is opened).
    private static final String[] PUBLIC_PATHS = { "/api/v1/auth/register", "/api/v1/auth/login", "/api/v1/health",
            "/actuator/health", "/actuator/health/**" };

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, ProblemDetailSecurityHandler problemHandler)
            throws Exception {
        http
                // Mobile clients send a Bearer token, not cookies, so CSRF protection does not apply.
                .csrf(AbstractHttpConfigurer::disable)
                // No HTTP session: every request must carry its own token.
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(PUBLIC_PATHS).permitAll()
                        // Spring forwards errors to /error; without this, every error would turn into a 401.
                        .requestMatchers("/error").permitAll()
                        .anyRequest().authenticated())
                // Validate "Authorization: Bearer <jwt>" on every other request.
                .oauth2ResourceServer(oauth2 -> oauth2
                        .bearerTokenResolver(bearerTokenResolver())
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter()))
                        .authenticationEntryPoint(problemHandler)
                        .accessDeniedHandler(problemHandler))
                // 401 / 403 as problem+json (also for requests without any token)
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(problemHandler)
                        .accessDeniedHandler(problemHandler));
        return http.build();
    }

    /**
     * Reads "Authorization: Bearer ..." except on the public endpoints. The app may still send an old or expired
     * token there (e.g. on the login screen after the token ran out); reading it would turn the login into a 401.
     */
    @Bean
    public BearerTokenResolver bearerTokenResolver() {
        RequestMatcher publicEndpoints = new OrRequestMatcher(Arrays.stream(PUBLIC_PATHS)
                .map(path -> (RequestMatcher) PathPatternRequestMatcher.withDefaults().matcher(path))
                .toList());
        DefaultBearerTokenResolver standard = new DefaultBearerTokenResolver();
        return request -> publicEndpoints.matches(request) ? null : standard.resolve(request);
    }

    /**
     * Turns a validated token into the logged-in user: the "role" claim (e.g. "PATIENT") becomes the authority
     * ROLE_PATIENT (what hasRole('PATIENT') checks), and the "sub" claim (the user id) becomes the principal name.
     */
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter authorities = new JwtGrantedAuthoritiesConverter();
        authorities.setAuthoritiesClaimName(JwtService.ROLE_CLAIM);
        authorities.setAuthorityPrefix("ROLE_");
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authorities);
        return converter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public JwtEncoder jwtEncoder(JwtProperties properties) {
        return NimbusJwtEncoder.withSecretKey(signingKey(properties))
                .algorithm(MacAlgorithm.HS256)
                .build();
    }

    @Bean
    public JwtDecoder jwtDecoder(JwtProperties properties, ActiveAccountValidator activeAccountValidator) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withSecretKey(signingKey(properties))
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        // The decoder checks the signature. Then: expiry ("exp") and that the token was issued by us ("iss"),
        // and only for such a token, that the account still exists and is active (one database lookup).
        OAuth2TokenValidator<Jwt> standard = JwtValidators.createDefaultWithIssuer(properties.issuer());
        decoder.setJwtValidator(token -> {
            OAuth2TokenValidatorResult result = standard.validate(token);
            return result.hasErrors() ? result : activeAccountValidator.validate(token);
        });
        return decoder;
    }

    private static SecretKey signingKey(JwtProperties properties) {
        byte[] keyBytes;
        try {
            keyBytes = Base64.getDecoder().decode(properties.secret());
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("JWT_SECRET must be base64-encoded", e);
        }
        if (keyBytes.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("JWT_SECRET must be at least " + MIN_SECRET_BYTES + " bytes after base64 decoding");
        }
        return new SecretKeySpec(keyBytes, "HmacSHA256");
    }
    
}