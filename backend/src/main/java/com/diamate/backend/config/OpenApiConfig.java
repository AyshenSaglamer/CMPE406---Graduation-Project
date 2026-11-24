package com.diamate.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;

/**
 * The OpenAPI 3 description that springdoc builds from the controllers (/v3/api-docs, Swagger UI at
 * /swagger-ui.html). Served only with API_DOCS_ENABLED=true (application.yml).
 *
 * Every endpoint needs "Authorization: Bearer <accessToken>" except the public ones (register, login, refresh,
 * health), which springdoc cannot tell apart; they are listed in the description below and in docs/DEVELOPER_GUIDE.md.
 */
@Configuration
public class OpenApiConfig {

    private static final String BEARER = "bearerAuth";

    @Bean
    public OpenAPI diamateOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("DiaMate Backend API")
                        .version("v1")
                        .description("""
                                REST API of the DiaMate diabetes app (Spring Boot). All paths start with /api/v1.

                                **Authentication:** `POST /api/v1/auth/login` returns an access token (JWT, short-lived) \
                                and a refresh token. Send `Authorization: Bearer <accessToken>` with every other request. \
                                When it expires (401), call `POST /api/v1/auth/refresh` with the refresh token and \
                                replace both tokens; a refresh token works only once. `POST /api/v1/auth/logout` ends \
                                the session of the token at once.

                                **Public (no token):** `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, \
                                `GET /health`.

                                **Errors:** RFC 9457 `application/problem+json` (`status`, `detail`, field errors in \
                                `errors`). A patient the caller may not see gives 404, not 403.

                                Guide: docs/DEVELOPER_GUIDE.md in the backend folder."""))
                .components(new Components().addSecuritySchemes(BEARER, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")
                        .description("Access token from POST /api/v1/auth/login or /refresh")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER));
    }
}
