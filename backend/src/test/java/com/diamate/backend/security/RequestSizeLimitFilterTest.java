package com.diamate.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import com.diamate.backend.exception.RequestTooLargeException;

import jakarta.servlet.ServletRequest;
import tools.jackson.databind.json.JsonMapper;

/** The filter alone, without Spring: the 413 through the whole application is tested in HealthLogWebTest. */
class RequestSizeLimitFilterTest {

    private final RequestSizeLimitFilter filter = new RequestSizeLimitFilter(JsonMapper.builder().build());

    @Test
    void bodyWithContentLengthOver1MbIsRefusedBeforeItIsRead() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/auth/login");
        request.setContent(new byte[(int) RequestSizeLimitFilter.MAX_BODY_BYTES + 1]);
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(413);
        assertThat(response.getContentType()).isEqualTo(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        assertThat(response.getContentAsString()).contains("\"detail\":\"Request body must be at most 1 MB\"");
        assertThat(chain.getRequest()).isNull(); // the application never saw the request
    }

    @Test
    void smallBodyPassesUnchanged() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/auth/login");
        request.setContent("{\"email\":\"x@example.com\"}".getBytes());
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        assertThat(chain.getRequest()).isSameAs(request);
    }

    @Test
    void bodyWithoutContentLengthIsCutAfter1Mb() throws Exception {
        MockHttpServletRequest request = new ChunkedRequest(new byte[(int) RequestSizeLimitFilter.MAX_BODY_BYTES + 10]);
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        ServletRequest seenByApplication = chain.getRequest();
        byte[] buffer = new byte[8192];
        assertThatThrownBy(() -> {
            while (seenByApplication.getInputStream().read(buffer, 0, buffer.length) >= 0) {
                // keep reading, like Jackson does
            }
        }).isInstanceOf(RequestTooLargeException.class).hasMessage("Request body must be at most 1 MB");
    }

    /** A request whose size is not announced (Transfer-Encoding: chunked): Content-Length is -1. */
    private static final class ChunkedRequest extends MockHttpServletRequest {

        ChunkedRequest(byte[] body) {
            super("POST", "/api/v1/patients/5/glucose-logs");
            setContent(body);
        }

        @Override
        public long getContentLengthLong() {
            return -1;
        }
    }
}
