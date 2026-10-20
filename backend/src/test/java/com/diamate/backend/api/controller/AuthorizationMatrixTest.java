package com.diamate.backend.api.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

import com.diamate.backend.api.dto.response.AiEntriesResponse;
import com.diamate.backend.entity.Gender;
import com.diamate.backend.entity.Role;
import com.diamate.backend.entity.User;
import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.JwtProperties;
import com.diamate.backend.security.JwtService;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.ActivityLogService;
import com.diamate.backend.service.AiEntryService;
import com.diamate.backend.service.AiService;
import com.diamate.backend.service.AlertService;
import com.diamate.backend.service.AuthService;
import com.diamate.backend.service.CreateResult;
import com.diamate.backend.service.GlucoseLogService;
import com.diamate.backend.service.InsulinLogService;
import com.diamate.backend.service.MealLogService;
import com.diamate.backend.service.PatientService;
import com.diamate.backend.service.UserService;

/**
 * The role rules of every endpoint, in one table (the "authorization matrix" of docs/BACKEND_REVIEW.md). Each
 * endpoint is called with a valid body by each of the four roles: an allowed role must get past the role check
 * (anything but 401 / 403; the services are mocks), a role that is not allowed must get 403.
 *
 * Only the role level (@PreAuthorize) is tested here. Which patient a clinician or caregiver may see is decided in the
 * services (fn_can_access, 404 otherwise) and tested there and end to end. The endpoints come from Spring's own list
 * of mappings: a new endpoint without a row in RULES fails this test.
 */
@WebMvcTest(
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class AuthorizationMatrixTest {

    private static final Set<Role> EVERYONE = EnumSet.of(Role.PATIENT, Role.CLINICIAN, Role.CAREGIVER, Role.ADMIN);
    private static final Set<Role> PATIENT = EnumSet.of(Role.PATIENT);
    private static final Set<Role> ADMIN = EnumSet.of(Role.ADMIN);
    private static final Set<Role> CARE_TEAM = EnumSet.of(Role.CLINICIAN, Role.CAREGIVER);

    private static final String LOGS = "/api/v1/patients/{patientId}/";
    private static final Map<String, Set<Role>> RULES = new TreeMap<>();

    static {
        // Public (no token needed; a token is ignored) and "any logged-in user": every role passes the role check.
        RULES.put("POST /api/v1/auth/register", EVERYONE);
        RULES.put("POST /api/v1/auth/login", EVERYONE);
        RULES.put("GET /api/v1/health", EVERYONE);
        RULES.put("GET /api/v1/users/me", EVERYONE);
        RULES.put("GET /api/v1/patients/{patientId}/overview", EVERYONE);
        for (String log : new String[] { "glucose-logs", "insulin-logs", "meal-logs", "activity-logs" }) {
            RULES.put("GET " + LOGS + log, EVERYONE);
            RULES.put("GET " + LOGS + log + "/{logId}", EVERYONE);
            RULES.put("POST " + LOGS + log, PATIENT);
            RULES.put("PUT " + LOGS + log + "/{logId}", PATIENT);
            RULES.put("DELETE " + LOGS + log + "/{logId}", PATIENT);
        }
        RULES.put("GET " + LOGS + "alerts", EVERYONE);
        RULES.put("GET " + LOGS + "alerts/{alertId}", EVERYONE);
        RULES.put("PATCH " + LOGS + "alerts/{alertId}", EVERYONE);
        RULES.put("POST " + LOGS + "ai-entries", PATIENT);
        RULES.put("POST /api/v1/ai/parse", PATIENT);
        RULES.put("GET /api/v1/admin/users", ADMIN);
        RULES.put("PATCH /api/v1/admin/users/{userId}/status", ADMIN);
        RULES.put("GET /api/v1/care-team/patients", CARE_TEAM);
        RULES.put("GET /api/v1/care-team/alerts", CARE_TEAM);
    }

    // Valid bodies, so a request is not stopped by validation (400) before the role check could answer.
    private static final Map<String, String> BODIES = Map.ofEntries(
            Map.entry("POST /api/v1/auth/register", """
                    {"firstName":"Ayse","lastName":"Kaya","email":"a@example.com","password":"Mavi-Deniz-77",
                     "role":"PATIENT","dateOfBirth":"1990-01-01","gender":"FEMALE"}"""),
            Map.entry("POST /api/v1/auth/login", "{\"email\":\"a@example.com\",\"password\":\"Mavi-Deniz-77\"}"),
            Map.entry("glucose-logs", "{\"glucoseValue\":120,\"measurementTime\":\"2026-10-05T08:30:00Z\"}"),
            Map.entry("insulin-logs", "{\"doseUnits\":4,\"administeredAt\":\"2026-10-05T08:30:00Z\"}"),
            Map.entry("meal-logs", "{\"mealType\":\"LUNCH\",\"eatenAt\":\"2026-10-05T08:30:00Z\",\"carbsG\":40}"),
            Map.entry("activity-logs", "{\"activityType\":\"walking\",\"startedAt\":\"2026-10-05T08:30:00Z\"}"),
            Map.entry("alerts", "{\"status\":\"ACKNOWLEDGED\"}"),
            Map.entry("ai-entries", "{\"entries\":[{\"intent\":\"LOG_GLUCOSE\",\"value\":120}]}"),
            Map.entry("POST /api/v1/ai/parse", "{\"text\":\"my glucose is 120\"}"),
            Map.entry("PATCH /api/v1/admin/users/{userId}/status", "{\"active\":false}"));

    private static final Map<Role, Long> USER_IDS = Map.of(Role.ADMIN, 1L, Role.CLINICIAN, 2L, Role.CAREGIVER, 4L,
            Role.PATIENT, 5L);

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    @Qualifier("requestMappingHandlerMapping")
    private RequestMappingHandlerMapping handlerMapping;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtProperties jwtProperties;

    @MockitoBean private AuthService authService;
    @MockitoBean private UserService userService;
    @MockitoBean private PatientService patientService;
    @MockitoBean private GlucoseLogService glucoseLogService;
    @MockitoBean private InsulinLogService insulinLogService;
    @MockitoBean private MealLogService mealLogService;
    @MockitoBean private ActivityLogService activityLogService;
    @MockitoBean private AiService aiService;
    @MockitoBean private AlertService alertService;
    @MockitoBean private AiEntryService aiEntryService;
    @MockitoBean private UserRepository userRepository;

    @BeforeEach
    void setUp() {
        // Every account is active and still has the role of its token.
        when(userRepository.findActiveUserRole(anyLong())).thenAnswer(call -> USER_IDS.entrySet().stream()
                .filter(e -> e.getValue().equals(call.getArgument(0))).map(Map.Entry::getKey).findFirst());
        // The controllers that read the service's answer get one (the others return the mock's null as an empty body).
        when(glucoseLogService.create(anyLong(), anyLong(), any())).thenReturn(CreateResult.existing(null));
        when(insulinLogService.create(anyLong(), anyLong(), any())).thenReturn(CreateResult.existing(null));
        when(mealLogService.create(anyLong(), anyLong(), any())).thenReturn(CreateResult.existing(null));
        when(activityLogService.create(anyLong(), anyLong(), any())).thenReturn(CreateResult.existing(null));
        when(aiEntryService.save(anyLong(), anyLong(), any())).thenReturn(new AiEntriesResponse(0, List.of()));
    }

    @Test
    void everyEndpointHasARuleAndEveryRoleGetsWhatTheRuleSays() throws Exception {
        assertThat(endpoints()).as("endpoints without a row in RULES (or rows of endpoints that no longer exist)")
                .isEqualTo(RULES.keySet());

        List<String> wrong = new ArrayList<>();
        for (Map.Entry<String, Set<Role>> rule : RULES.entrySet()) {
            for (Role role : Role.values()) {
                int status = mockMvc.perform(withToken(rule.getKey(), role)).andReturn().getResponse().getStatus();
                boolean allowed = rule.getValue().contains(role);
                boolean passedRoleCheck = status != 401 && status != 403;
                if (allowed != passedRoleCheck) {
                    wrong.add(rule.getKey() + " as " + role + ": " + status + " (expected "
                            + (allowed ? "not 401/403" : "403") + ")");
                } else if (!allowed && status != 403) {
                    wrong.add(rule.getKey() + " as " + role + ": " + status + " (expected 403)");
                }
            }
        }
        assertThat(wrong).as("role rule mismatches").isEmpty();
    }

    /** "METHOD /path" of every controller method; Spring's /error endpoint is left out. */
    private Set<String> endpoints() {
        Set<String> endpoints = new TreeSet<>();
        for (RequestMappingInfo info : handlerMapping.getHandlerMethods().keySet()) {
            for (String path : info.getPatternValues()) {
                if (!path.startsWith("/error")) {
                    for (RequestMethod method : info.getMethodsCondition().getMethods()) {
                        endpoints.add(method.name() + " " + path);
                    }
                }
            }
        }
        return endpoints;
    }

    /** The patient's own id in {patientId}, 9 for any other id, a valid body for POST / PUT / PATCH. */
    private MockHttpServletRequestBuilder withToken(String endpoint, Role role) {
        String[] methodAndPath = endpoint.split(" ", 2);
        String path = methodAndPath[1].replace("{patientId}", "5").replaceAll("\\{[^}]+}", "9");
        MockHttpServletRequestBuilder request = request(HttpMethod.valueOf(methodAndPath[0]), path)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenFor(role));
        if (!methodAndPath[0].equals("GET") && !methodAndPath[0].equals("DELETE")) {
            request.contentType(MediaType.APPLICATION_JSON).content(bodyFor(endpoint));
        }
        return request;
    }

    private static String bodyFor(String endpoint) {
        if (BODIES.containsKey(endpoint)) {
            return BODIES.get(endpoint);
        }
        return BODIES.entrySet().stream()
                .filter(e -> !e.getKey().contains(" ") && endpoint.contains("/" + e.getKey()))
                .map(Map.Entry::getValue).findFirst()
                .orElseThrow(() -> new IllegalStateException("no test body for " + endpoint));
    }

    private String tokenFor(Role role) {
        User user = new User("First", "Last", LocalDate.of(2000, 1, 15), Gender.OTHER, role, "u@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", USER_IDS.get(role));
        return new JwtService(jwtEncoder, jwtProperties, Clock.systemUTC()).generateToken(user);
    }
}
