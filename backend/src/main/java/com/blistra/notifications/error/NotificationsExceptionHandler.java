package com.blistra.notifications.error;

import com.blistra.common.error.ApiErrorResponse;
import com.blistra.notifications.exception.InvalidReminderTimeException;
import com.blistra.notifications.exception.ReminderStateConflictException;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;

/**
 * Advice scoped to the Notifications module. Notification-specific error codes
 * are mapped here without touching the module-agnostic global handler. All
 * other exceptions (validation, bad request, not found, authentication) are
 * handled globally.
 */
@Slf4j
@Order(Ordered.HIGHEST_PRECEDENCE)
@RestControllerAdvice(basePackages = "com.blistra.notifications")
public class NotificationsExceptionHandler {

    @ExceptionHandler(InvalidReminderTimeException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ResponseEntity<ApiErrorResponse> handleInvalidReminderTime(
            InvalidReminderTimeException ex,
            HttpServletRequest request) {
        ApiErrorResponse response = ApiErrorResponse.builder()
                .timestamp(LocalDateTime.now())
                .status(HttpStatus.BAD_REQUEST.value())
                .code("INVALID_REMINDER_TIME")
                .message(ex.getMessage())
                .path(request.getServletPath())
                .build();
        return ResponseEntity.badRequest().body(response);
    }

    @ExceptionHandler(ReminderStateConflictException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ResponseEntity<ApiErrorResponse> handleReminderStateConflict(
            ReminderStateConflictException ex,
            HttpServletRequest request) {
        ApiErrorResponse response = ApiErrorResponse.builder()
                .timestamp(LocalDateTime.now())
                .status(HttpStatus.CONFLICT.value())
                .code("REMINDER_STATE_CONFLICT")
                .message(ex.getMessage())
                .path(request.getServletPath())
                .build();
        return ResponseEntity.status(HttpStatus.CONFLICT).body(response);
    }
}