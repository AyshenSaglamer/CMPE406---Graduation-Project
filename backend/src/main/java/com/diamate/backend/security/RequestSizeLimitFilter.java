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
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class RequestSizeLimitFilter extends OncePerRequestFilter {

    static final long MAX_BODY_BYTES = 1024 * 1024;
    static final String TOO_LARGE = "Request body must be at most 1 MB";

    private final ObjectMapper objectMapper;

    public RequestSizeLimitFilter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long declaredLength = request.getContentLengthLong(); // -1 when the client did not send Content-Length
        if (declaredLength > MAX_BODY_BYTES) {
            ProblemJson.write(objectMapper, request, response, HttpStatus.CONTENT_TOO_LARGE, TOO_LARGE);
            return;
        }
        chain.doFilter(declaredLength < 0 ? new SizeLimitedRequest(request) : request, response);
    }

    /** Gives the application a body stream that throws RequestTooLargeException (413) after 1 MB. */
    private static final class SizeLimitedRequest extends HttpServletRequestWrapper {

        private ServletInputStream limitedStream;

        SizeLimitedRequest(HttpServletRequest request) {
            super(request);
        }

        @Override
        public ServletInputStream getInputStream() throws IOException {
            if (limitedStream == null) {
                limitedStream = new SizeLimitedInputStream(super.getInputStream());
            }
            return limitedStream;
        }
    }

    private static final class SizeLimitedInputStream extends ServletInputStream {

        private final ServletInputStream body;
        private long bytesRead;

        SizeLimitedInputStream(ServletInputStream body) {
            this.body = body;
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
            if (bytesRead > MAX_BODY_BYTES) {
                throw new RequestTooLargeException(TOO_LARGE);
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
