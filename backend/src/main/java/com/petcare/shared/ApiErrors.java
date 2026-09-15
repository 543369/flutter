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
        var known=java.util.Set.of("ACCESS_EXPIRED","PERMISSION_DENIED","LAST_ADMIN","BENEFIT_UNAVAILABLE","STORAGE_LIMIT_EXCEEDED","INVALID_ASSIGNEE","WEIGHT_REQUIRED");
        return ResponseEntity.status(e.getStatusCode()).body(Map.of("error",e.getReason()!=null && known.contains(e.getReason())?e.getReason():"REQUEST_FAILED"));
    }
    // Do not return or log rejected request values (especially passwords).
    @ExceptionHandler({MethodArgumentNotValidException.class, HttpMessageNotReadableException.class})
    ResponseEntity<Map<String,String>> invalidInput(Exception ignored) {
        return ResponseEntity.badRequest().body(Map.of("error","INVALID_INPUT"));
    }
}
