package com.diamate.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

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

    @Test
    void onlyTheVoiceUploadMayBeLargerThan1Mb() throws Exception {
        MockHttpServletRequest recording = new MockHttpServletRequest("POST", RequestSizeLimitFilter.VOICE_PATH);
        recording.setContent(new byte[5 * 1024 * 1024]);
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(recording, new MockHttpServletResponse(), chain);
        assertThat(chain.getRequest()).isSameAs(recording);

        MockHttpServletRequest tooLong = new MockHttpServletRequest("POST", RequestSizeLimitFilter.VOICE_PATH);
        tooLong.setContent(new byte[(int) RequestSizeLimitFilter.MAX_VOICE_BYTES + 1]);
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(tooLong, response, new MockFilterChain());
        assertThat(response.getStatus()).isEqualTo(413);
        assertThat(response.getContentAsString()).contains("\"detail\":\"The recording must be at most 10 MB\"");

        // The exception is for that one address and method only.
        for (MockHttpServletRequest other : List.of(new MockHttpServletRequest("PUT", RequestSizeLimitFilter.VOICE_PATH),
                new MockHttpServletRequest("POST", "/api/v1/ai/parse"),
                new MockHttpServletRequest("POST", RequestSizeLimitFilter.VOICE_PATH + "/x"))) {
            other.setContent(new byte[2 * 1024 * 1024]);
            MockHttpServletResponse refused = new MockHttpServletResponse();
            filter.doFilter(other, refused, new MockFilterChain());
            assertThat(refused.getStatus()).as(other.getMethod() + " " + other.getRequestURI()).isEqualTo(413);
        }
    }

    @Test
    void chunkedVoiceUploadIsCutAfter11Mb() throws Exception {
        MockHttpServletRequest request = new ChunkedRequest(new byte[(int) RequestSizeLimitFilter.MAX_VOICE_BYTES + 10]);
        request.setMethod("POST");
        request.setRequestURI(RequestSizeLimitFilter.VOICE_PATH);
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        ServletRequest seenByApplication = chain.getRequest();
        byte[] buffer = new byte[65536];
        long[] read = { 0 };
        assertThatThrownBy(() -> {
            int n;
            while ((n = seenByApplication.getInputStream().read(buffer, 0, buffer.length)) >= 0) {
                read[0] += n;
            }
        }).isInstanceOf(RequestTooLargeException.class).hasMessage("The recording must be at most 10 MB");
        assertThat(read[0]).isGreaterThan(RequestSizeLimitFilter.MAX_BODY_BYTES); // more than 1 MB was allowed
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
