package com.blistra.common.error;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();
    private final MockHttpServletRequest request = new MockHttpServletRequest();

    @Test
    void typeMismatch_returnsSafeMessage() {
        var ex = new MethodArgumentTypeMismatchException("secret_table_value", UUID.class,
                "id", null, new IllegalArgumentException("org.postgresql table users failed at /tmp/x"));
        ResponseEntity<ApiErrorResponse> res = handler.handleMethodArgumentTypeMismatch(ex, request);
        assertThat(res.getStatusCode().value()).isEqualTo(400);
        assertThat(res.getBody().getCode()).isEqualTo("INVALID_ARGUMENT");
        assertThat(res.getBody().getMessage()).doesNotContain("postgresql", "users", "/tmp");
    }

    @Test
    void missingParameter_returnsSafeMessage() {
        var ex = new MissingServletRequestParameterException("q", "String");
        ResponseEntity<ApiErrorResponse> res = handler.handleMissingParameter(ex, request);
        assertThat(res.getStatusCode().value()).isEqualTo(400);
        assertThat(res.getBody().getCode()).isEqualTo("MISSING_PARAMETER");
        assertThat(res.getBody().getMessage()).isEqualTo("Required request parameter is missing");
    }

    @Test
    void malformedBody_returnsSafeMessage() {
        var ex = new HttpMessageNotReadableException("test",
                org.mockito.Mockito.mock(org.springframework.http.HttpInputMessage.class));
        ex.initCause(new RuntimeException("SQL error at column password"));
        ResponseEntity<ApiErrorResponse> res = handler.handleNotReadable(ex, request);
        assertThat(res.getStatusCode().value()).isEqualTo(400);
        assertThat(res.getBody().getCode()).isEqualTo("MALFORMED_REQUEST");
        assertThat(res.getBody().getMessage()).isEqualTo("Malformed request body");
    }

    @Test
    void genericException_returnsGenericMessage() {
        var ex = new RuntimeException("Hibernate dialect table finance_accounts failed");
        ResponseEntity<ApiErrorResponse> res = handler.handleGenericException(ex, request);
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(res.getBody().getMessage()).isEqualTo("An unexpected error occurred");
        assertThat(res.getBody().getMessage()).doesNotContain("Hibernate", "finance_accounts");
    }

    @Test
    void appExceptions_preserveCuratedMessages() {
        ResponseEntity<ApiErrorResponse> bad = handler.handleBadRequest(
                new BadRequestException("Custom safe message"), request);
        assertThat(bad.getBody().getMessage()).isEqualTo("Custom safe message");
        ResponseEntity<ApiErrorResponse> notFound = handler.handleResourceNotFound(
                new ResourceNotFoundException("Account not found"), request);
        assertThat(notFound.getStatusCode().value()).isEqualTo(404);
        assertThat(notFound.getBody().getMessage()).isEqualTo("Account not found");
    }
}
