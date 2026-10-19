package com.petcare.shared;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
class ApiErrors {
    @ExceptionHandler(org.springframework.web.server.ResponseStatusException.class)
    ResponseEntity<Map<String,String>> status(org.springframework.web.server.ResponseStatusException e) {
        var known=java.util.Set.of("CURRENT_PASSWORD_INVALID","PASSWORD_ACCOUNT_REQUIRED","EMAIL_UNCHANGED","EMAIL_IN_USE","EMAIL_CHANGE_INVALID","APPLE_ALREADY_LINKED","APPLE_LINK_EXPIRED","APPLE_IDENTITY_INVALID","USE_LEAVE_HOUSEHOLD","INVALID_OVERDUE_FILTER","BATCH_TOO_LARGE","OVERDUE_SELECTION_EMPTY","OVERDUE_PREVIEW_EXPIRED","SYNC_CONFLICT","HOUSEHOLD_CHANGED","DEPENDENCY_MISSING","OPERATION_REUSED","TASK_NOT_PENDING","INVALID_CARE_TIME","REGISTRATION_CODE_INVALID","EMAIL_VERIFICATION_REQUIRED","ACCESS_EXPIRED","PERMISSION_DENIED","LAST_ADMIN","BENEFIT_UNAVAILABLE","STORAGE_LIMIT_EXCEEDED","INVALID_ASSIGNEE","WEIGHT_REQUIRED");
        return ResponseEntity.status(e.getStatusCode()).body(Map.of("error",e.getReason()!=null && known.contains(e.getReason())?e.getReason():"REQUEST_FAILED"));
    }
    // Do not return or log rejected request values (especially passwords).
    @ExceptionHandler({MethodArgumentNotValidException.class, HttpMessageNotReadableException.class})
    ResponseEntity<Map<String,String>> invalidInput(Exception ignored) {
        return ResponseEntity.badRequest().body(Map.of("error","INVALID_INPUT"));
    }
}
