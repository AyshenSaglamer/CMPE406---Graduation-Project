package com.diamate.backend.integration;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.MountableFile;

import com.diamate.backend.api.dto.request.RegisterRequest;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.service.AuthService;

/**
 * Base of the tests that run against a real PostgreSQL 17 in Docker: the SQL, the database functions (fn_can_access),
 * the triggers and the row locks are the real ones. The unit tests mock the repositories, so a broken SQL string
 * (e.g. "WHEREa ...") passes them; these tests catch it.
 *
 * The database is built like a real install: the Database/sql package (schema, functions, views, reference data,
 * without the research CSV load and the demo seed, which need the dataset files), then the application starts and
 * Flyway applies V2..V8 on top. One container for all test classes (started on first use, removed by Testcontainers
 * when the JVM ends). Each test creates its own accounts with unique emails, so tests do not depend on each other.
 *
 * Skipped (not failed) when Docker is not running.
 */
@SpringBootTest(properties = {
        "diamate.jwt.secret=aW50ZWdyYXRpb24tdGVzdC1vbmx5LXNlY3JldC1ub3QtZm9yLXByb2R1Y3Rpb24hIQ==", // base64, test only
        "diamate.ai.base-url=http://127.0.0.1:9" // nothing listens there: AI calls fail fast, none are expected
})
@Testcontainers(disabledWithoutDocker = true)
public abstract class PostgresIntegrationTest {

    static final String PASSWORD = "Integration-Test-Pass-4821";

    /** Database/sql scripts that make the baseline schema (version 1 for Flyway), in install order. */
    private static final List<String> BASELINE_SCRIPTS = List.of("01_extensions_roles", "02_research_schema",
            "04_research_keys_indexes", "06_app_schema", "06b_app_column_comments", "07_app_functions_views",
            "08_reference_seed", "10_grants");

    private static PostgreSQLContainer postgres;

    @Autowired
    protected AuthService authService;

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        PostgreSQLContainer database = startOnce();
        registry.add("spring.datasource.url", database::getJdbcUrl);
        registry.add("spring.datasource.username", database::getUsername);
        registry.add("spring.datasource.password", database::getPassword);
    }

    private static synchronized PostgreSQLContainer startOnce() {
        if (postgres == null) {
            Path sql = sqlDirectory();
            PostgreSQLContainer container = new PostgreSQLContainer("postgres:17").withDatabaseName("diamate");
            for (int i = 0; i < BASELINE_SCRIPTS.size(); i++) {
                String name = BASELINE_SCRIPTS.get(i) + ".sql";
                // Numbered, because the image runs /docker-entrypoint-initdb.d in alphabetical order.
                container.withCopyFileToContainer(MountableFile.forHostPath(sql.resolve(name)),
                        "/docker-entrypoint-initdb.d/%02d_%s".formatted(i, name));
            }
            container.start();
            postgres = container;
        }
        return postgres;
    }

    /** ../Database/sql from the backend folder (mvn runs the tests there), or Database/sql from the repository root. */
    private static Path sqlDirectory() {
        for (Path candidate : List.of(Path.of("..", "Database", "sql"), Path.of("Database", "sql"))) {
            if (Files.isRegularFile(candidate.resolve("06_app_schema.sql"))) {
                return candidate.toAbsolutePath().normalize();
            }
        }
        throw new IllegalStateException("Database/sql not found from " + Path.of("").toAbsolutePath());
    }

    /** Registers a new account with a unique email and returns its id. */
    protected long register(String firstName, Role role) {
        return authService.register(new RegisterRequest(firstName, "Test", LocalDate.of(1990, 1, 1), Gender.OTHER,
                role, email(firstName), PASSWORD)).id();
    }

    /** A unique email; the same name gives a different email on every call. */
    protected static String email(String name) {
        return name.toLowerCase() + "." + UUID.randomUUID().toString().substring(0, 8) + "@it.diamate.test";
    }
}
