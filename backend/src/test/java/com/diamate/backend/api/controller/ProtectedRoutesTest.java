package com.diamate.backend.api.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;

import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

import com.diamate.backend.repository.UserRepository;
import com.diamate.backend.security.ActiveAccountValidator;
import com.diamate.backend.security.ProblemDetailSecurityHandler;
import com.diamate.backend.security.SecurityConfig;
import com.diamate.backend.service.ActivityLogService;
import com.diamate.backend.service.AiEntryService;
import com.diamate.backend.service.AiService;
import com.diamate.backend.service.AlertService;
import com.diamate.backend.service.AuthService;
import com.diamate.backend.service.GlucoseLogService;
import com.diamate.backend.service.InsulinLogService;
import com.diamate.backend.service.MealLogService;
import com.diamate.backend.service.PatientService;
import com.diamate.backend.service.UserService;

/**
 * Every endpoint of every controller, found from Spring's own list of mappings (not a hand-written list), is called
 * without a token. Only the three public endpoints may answer something other than 401, so an endpoint added later
 * is covered automatically: if it is reachable without a token, this test fails.
 */
@WebMvcTest( // no "controllers": all controllers of the application are loaded
        // Fixed, test-only key (base64 of "test-only-jwt-key-not-a-real-secret-0123456789"); the real one lives in .env.
        properties = "diamate.jwt.secret=dGVzdC1vbmx5LWp3dC1rZXktbm90LWEtcmVhbC1zZWNyZXQtMDEyMzQ1Njc4OQ==")
@Import({ SecurityConfig.class, ProblemDetailSecurityHandler.class, ActiveAccountValidator.class })
class ProtectedRoutesTest {

    private static final Set<String> PUBLIC_ENDPOINTS = Set.of(
            "POST /api/v1/auth/register",
            "POST /api/v1/auth/login",
            "GET /api/v1/health");

    // 34 controller endpoints (+ /actuator/health, which is not a controller). When this changes, update the
    // endpoint inventory in docs/BACKEND_REVIEW.md, the README and AuthorizationMatrixTest.
    private static final int ENDPOINT_COUNT = 34;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    @Qualifier("requestMappingHandlerMapping")
    private RequestMappingHandlerMapping handlerMapping;

    @MockitoBean
    private AuthService authService;

    @MockitoBean
    private UserService userService;

    @MockitoBean
    private PatientService patientService;

    @MockitoBean
    private GlucoseLogService glucoseLogService;

    @MockitoBean
    private InsulinLogService insulinLogService;

    @MockitoBean
    private MealLogService mealLogService;

    @MockitoBean
    private ActivityLogService activityLogService;

    @MockitoBean
    private AiService aiService;

    @MockitoBean
    private AlertService alertService;

    @MockitoBean
    private AiEntryService aiEntryService;

    @MockitoBean
    private UserRepository userRepository;

    @Test
    void everyEndpointExceptTheThreePublicOnesNeedsAToken() throws Exception {
        Map<String, Integer> statusWithoutToken = new TreeMap<>();
        for (String endpoint : endpoints()) {
            String[] methodAndPath = endpoint.split(" ", 2);
            statusWithoutToken.put(endpoint, mockMvc.perform(withoutToken(methodAndPath[0], methodAndPath[1]))
                    .andReturn().getResponse().getStatus());
        }

        assertThat(statusWithoutToken).hasSize(ENDPOINT_COUNT);
        Set<String> reachableWithoutToken = new TreeSet<>();
        statusWithoutToken.forEach((endpoint, status) -> {
            if (status != 401) {
                reachableWithoutToken.add(endpoint);
            }
        });
        assertThat(reachableWithoutToken)
                .as("endpoints that answered without a token (status per endpoint: %s)", statusWithoutToken)
                .isEqualTo(PUBLIC_ENDPOINTS);
        // A protected endpoint is refused before the controller: no service was called.
        verifyNoInteractions(userService, patientService, glucoseLogService, insulinLogService, mealLogService,
                activityLogService, aiService, alertService, aiEntryService);
    }

    /** "METHOD /path" for every controller method; Spring's /error endpoint is left out (it is not an API). */
    private Set<String> endpoints() {
        Set<String> endpoints = new TreeSet<>();
        for (RequestMappingInfo info : handlerMapping.getHandlerMethods().keySet()) {
            for (String path : info.getPatternValues()) {
                if (path.startsWith("/error")) {
                    continue;
                }
                for (RequestMethod method : info.getMethodsCondition().getMethods()) {
                    endpoints.add(method.name() + " " + path);
                }
            }
        }
        return endpoints;
    }

    /** Path variables ({patientId}, {logId}) become 1; POST and PUT get an empty JSON object as body. */
    private static MockHttpServletRequestBuilder withoutToken(String method, String pathPattern) {
        MockHttpServletRequestBuilder request = request(HttpMethod.valueOf(method), pathPattern.replaceAll("\\{[^}]+}", "1"));
        if (method.equals("POST") || method.equals("PUT")) {
            request.contentType(MediaType.APPLICATION_JSON).content("{}");
        }
        return request;
    }
}
