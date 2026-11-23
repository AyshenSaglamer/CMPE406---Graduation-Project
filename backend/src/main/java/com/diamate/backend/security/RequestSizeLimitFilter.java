package com.diamate.backend.security;

import java.io.IOException;

import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.diamate.backend.exception.RequestTooLargeException;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import tools.jackson.databind.ObjectMapper;

/**
 * Refuses request bodies over 1 MB with 413, before anything reads them into memory (the largest field the API
 * accepts is 1000 characters). Runs first, even before Spring Security, so it also protects the login endpoint.
 *
 * With a Content-Length header the request is refused at once. Without it (chunked upload) the size is only
 * known while reading, so the bytes are counted and reading stops after 1 MB.
 *
 * Two exceptions, both multipart uploads read by Tomcat (spring.servlet.multipart): POST /api/v1/ai/voice carries a
 * recording of up to 10 MB, so it may be 11 MB (the file plus the multipart headers), and POST /api/v1/ai/food a meal
 * photo of up to 5 MB, so it may be 6 MB.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class RequestSizeLimitFilter extends OncePerRequestFilter {

    static final long MAX_BODY_BYTES = 1024 * 1024;
    static final String TOO_LARGE = "Request body must be at most 1 MB";
    static final String VOICE_PATH = "/api/v1/ai/voice";
    static final long MAX_VOICE_BYTES = 11L * 1024 * 1024;
    static final String VOICE_TOO_LARGE = "The recording must be at most 10 MB";
    static final String FOOD_PATH = "/api/v1/ai/food";
    static final long MAX_FOOD_BYTES = 6L * 1024 * 1024;
    static final String FOOD_TOO_LARGE = "The image must be at most 5 MB";

    private final ObjectMapper objectMapper;

    public RequestSizeLimitFilter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        boolean post = "POST".equals(request.getMethod());
        long limit = MAX_BODY_BYTES;
        String message = TOO_LARGE;
        if (post && VOICE_PATH.equals(request.getRequestURI())) {
            limit = MAX_VOICE_BYTES;
            message = VOICE_TOO_LARGE;
        } else if (post && FOOD_PATH.equals(request.getRequestURI())) {
            limit = MAX_FOOD_BYTES;
            message = FOOD_TOO_LARGE;
        }
        long declaredLength = request.getContentLengthLong(); // -1 when the client did not send Content-Length
        if (declaredLength > limit) {
            ProblemJson.write(objectMapper, request, response, HttpStatus.CONTENT_TOO_LARGE, message);
            return;
        }
        chain.doFilter(declaredLength < 0 ? new SizeLimitedRequest(request, limit, message) : request, response);
    }

    /** Gives the application a body stream that throws RequestTooLargeException (413) after the limit. */
    private static final class SizeLimitedRequest extends HttpServletRequestWrapper {

        private final long limit;
        private final String message;
        private ServletInputStream limitedStream;

        SizeLimitedRequest(HttpServletRequest request, long limit, String message) {
            super(request);
            this.limit = limit;
            this.message = message;
        }

        @Override
        public ServletInputStream getInputStream() throws IOException {
            if (limitedStream == null) {
                limitedStream = new SizeLimitedInputStream(super.getInputStream(), limit, message);
            }
            return limitedStream;
        }
    }

    private static final class SizeLimitedInputStream extends ServletInputStream {

        private final ServletInputStream body;
        private final long limit;
        private final String message;
        private long bytesRead;

        SizeLimitedInputStream(ServletInputStream body, long limit, String message) {
            this.body = body;
            this.limit = limit;
            this.message = message;
        }

        @Override
        public int read() throws IOException {
            int value = body.read();
            if (value >= 0) {
                count(1);
            }
            return value;
        }

        @Override
        public int read(byte[] buffer, int offset, int length) throws IOException {
            int read = body.read(buffer, offset, length);
            if (read > 0) {
                count(read);
            }
            return read;
        }

        private void count(int read) {
            bytesRead += read;
            if (bytesRead > limit) {
                throw new RequestTooLargeException(message);
            }
        }

        @Override
        public boolean isFinished() {
            return body.isFinished();
        }

        @Override
        public boolean isReady() {
            return body.isReady();
        }

        @Override
        public void setReadListener(ReadListener listener) {
            body.setReadListener(listener);
        }
    }
}
