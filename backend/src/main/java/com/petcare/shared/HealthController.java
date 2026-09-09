package com.petcare.shared;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import com.petcare.shared.ApiSupport;
import com.petcare.care.CarePlans;
import com.petcare.auth.Tokens;

@RestController
@RequestMapping("/api")
class HealthController extends ApiSupport {
 HealthController(JdbcTemplate db) { super(db); }

 @GetMapping("/health") Map<String,Object> health() { db.queryForObject("SELECT 1", Integer.class); return Map.of("status", "ok", "database", "mysql"); }

}
