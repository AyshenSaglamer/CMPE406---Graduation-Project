package com.diamate.backend.exception;

import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.TypeMismatchException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import com.diamate.backend.config.TextDeserializer;

import tools.jackson.core.JacksonException;
import tools.jackson.core.exc.StreamReadException;
import tools.jackson.databind.exc.InvalidFormatException;
import tools.jackson.databind.exc.MismatchedInputException;

/**
 * Turns exceptions into RFC 9457 "problem detail" JSON responses (Content-Type: application/problem+json).
 * The parent class already does this for Spring MVC's own errors (415, 405, ...); the overrides below make the
 * messages useful for the app (which field is wrong and why) and never show internal details.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /** @Valid failures: adds an "errors" map of field name -> message so the app can show it under each field. */
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        Map<String, String> errors = new LinkedHashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) {
            errors.putIfAbsent(error.getField(), error.getDefaultMessage()); // first message per field is enough
        }
        return handleExceptionInternal(ex, validationProblem(errors), headers, HttpStatus.BAD_REQUEST, request);
    }

    /**
     * The body could not be turned into the request object: not JSON, missing, or a field of the wrong type
     * (text for a number, an unknown enum value, an invalid date). Spring's default only says "Failed to read
     * request"; here a field problem gets the same "errors" map as @Valid failures.
     */
    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(HttpMessageNotReadableException ex,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        ProblemDetail body = unreadableBodyProblem(ex);
        return handleExceptionInternal(ex, body, headers, HttpStatusCode.valueOf(body.getStatus()), request);
    }

    /** A path or query parameter of the wrong type, e.g. /patients/abc or ?from=yesterday. */
    @Override
    protected ResponseEntity<Object> handleTypeMismatch(TypeMismatchException ex, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {
        String name = ex.getPropertyName() != null ? ex.getPropertyName() : "parameter";
        return handleExceptionInternal(ex, validationProblem(Map.of(name, expectedValue(ex.getRequiredType()))),
                headers, HttpStatus.BAD_REQUEST, request);
    }

    /** Unknown address. Spring's default text ("No static resource ...") describes its internals. */
    @Override
    protected ResponseEntity<Object> handleNoResourceFoundException(NoResourceFoundException ex,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        return handleExceptionInternal(ex, ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, "Resource not found"),
                headers, HttpStatus.NOT_FOUND, request);
    }

    /** Rules checked in the service (e.g. a time in the future): same 400 shape as @Valid failures. */
    @ExceptionHandler(InvalidFieldException.class)
    public ProblemDetail handleInvalidField(InvalidFieldException ex) {
        return validationProblem(Map.of(ex.getField(), ex.getMessage()));
    }

    @ExceptionHandler(EmailAlreadyRegisteredException.class)
    public ProblemDetail handleEmailAlreadyRegistered(EmailAlreadyRegisteredException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
    }

    @ExceptionHandler(InvalidCredentialsException.class)
    public ProblemDetail handleInvalidCredentials(InvalidCredentialsException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, ex.getMessage());
    }

    /** 429 + "Retry-After: <seconds>", so the app can tell the user when to try again. */
    @ExceptionHandler(AccountLockedException.class)
    public ResponseEntity<ProblemDetail> handleAccountLocked(AccountLockedException ex) {
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header(HttpHeaders.RETRY_AFTER, String.valueOf(ex.getRetryAfter().toSeconds()))
                .body(ProblemDetail.forStatusAndDetail(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage()));
    }

    @ExceptionHandler(AccountDisabledException.class)
    public ProblemDetail handleAccountDisabled(AccountDisabledException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.FORBIDDEN, ex.getMessage());
    }

    @ExceptionHandler(RegistrationNotAllowedException.class)
    public ProblemDetail handleRegistrationNotAllowed(RegistrationNotAllowedException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.getMessage());
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleResourceNotFound(ResourceNotFoundException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(ResourceConflictException.class)
    public ProblemDetail handleResourceConflict(ResourceConflictException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
    }

    @ExceptionHandler(AiServiceException.class)
    public ProblemDetail handleAiService(AiServiceException ex) {
        return ProblemDetail.forStatusAndDetail(ex.getStatus(), ex.getMessage());
    }

    @ExceptionHandler(RequestTooLargeException.class)
    public ProblemDetail handleRequestTooLarge(RequestTooLargeException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONTENT_TOO_LARGE, ex.getMessage());
    }

    /**
     * 401 / 403 raised by @PreAuthorize inside a controller: thrown on, so Spring Security answers them
     * (ProblemDetailSecurityHandler). Without this, the catch-all below would turn them into 500.
     */
    @ExceptionHandler({ AccessDeniedException.class, AuthenticationException.class })
    public void rethrowSecurityException(RuntimeException ex) {
        throw ex;
    }

    /**
     * Anything not handled above is a bug, not a client error: 500 with a fixed text. The details (stack trace)
     * go only to the server log; showing them to the client could reveal internals (tables, SQL, classes).
     */
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        log.error("Unexpected error", ex);
        return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }

    private static ProblemDetail validationProblem(Map<String, String> errors) {
        ProblemDetail body = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "One or more fields are invalid");
        body.setTitle("Validation failed");
        body.setProperty("errors", errors);
        return body;
    }

    private static ProblemDetail unreadableBodyProblem(HttpMessageNotReadableException ex) {
        MismatchedInputException mismatch = null;
        StreamReadException notJson = null;
        for (Throwable cause = ex.getCause(); cause != null; cause = cause.getCause()) {
            if (cause instanceof RequestTooLargeException tooLarge) {
                return ProblemDetail.forStatusAndDetail(HttpStatus.CONTENT_TOO_LARGE, tooLarge.getMessage());
            }
            if (mismatch == null && cause instanceof MismatchedInputException found) {
                mismatch = found;
            }
            if (notJson == null && cause instanceof StreamReadException found) {
                notJson = found;
            }
        }
        if (mismatch != null) {
            // An empty path means the body as a whole has the wrong shape (e.g. [] or "text" instead of {...}).
            if (mismatch.getPath().isEmpty()) {
                return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Request body must be a JSON object");
            }
            // Text with an invalid format can only come from TextDeserializer (control characters).
            String message = mismatch instanceof InvalidFormatException && mismatch.getTargetType() == String.class
                    ? TextDeserializer.CONTROL_CHARACTER_MESSAGE
                    : expectedValue(mismatch.getTargetType());
            return validationProblem(Map.of(fieldPath(mismatch), message));
        }
        if (notJson != null) {
            return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Request body is not valid JSON");
        }
        if (ex.getMessage() != null && ex.getMessage().startsWith("Required request body is missing")) {
            return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Request body is required");
        }
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Request body could not be read");
    }

    /** "glucoseValue", or "items[0].carbsG" for nested values. */
    private static String fieldPath(JacksonException ex) {
        StringBuilder path = new StringBuilder();
        for (JacksonException.Reference reference : ex.getPath()) {
            if (reference.getPropertyName() != null) {
                if (!path.isEmpty()) {
                    path.append('.');
                }
                path.append(reference.getPropertyName());
            } else if (reference.getIndex() >= 0) {
                path.append('[').append(reference.getIndex()).append(']');
            }
        }
        return path.isEmpty() ? "body" : path.toString();
    }

    /** What the field expects, in words the app can show the user. */
    private static String expectedValue(Class<?> type) {
        if (type == null) {
            return "Invalid value";
        }
        if (type.isEnum()) {
            return "Must be one of: " + Arrays.stream(type.getEnumConstants())
                    .map(constant -> ((Enum<?>) constant).name())
                    .collect(Collectors.joining(", "));
        }
        if (type == Integer.class || type == int.class || type == Long.class || type == long.class
                || type == Short.class || type == short.class) {
            return "Must be a whole number";
        }
        if (Number.class.isAssignableFrom(type) || type == double.class || type == float.class) {
            return "Must be a number";
        }
        if (type == Boolean.class || type == boolean.class) {
            return "Must be true or false";
        }
        if (type == LocalDate.class) {
            return "Must be a date in yyyy-MM-dd format";
        }
        if (type == Instant.class || type == OffsetDateTime.class) {
            return "Must be an ISO-8601 date-time, e.g. 2026-10-05T08:30:00Z";
        }
        if (type == UUID.class) {
            return "Must be a UUID";
        }
        if (type == String.class) {
            return "Must be text";
        }
        return "Invalid value";
    }
}
