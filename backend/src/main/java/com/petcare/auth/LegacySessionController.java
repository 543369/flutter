package com.petcare.auth;

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
class LegacySessionController extends ApiSupport {
 LegacySessionController(JdbcTemplate db) { super(db); }

 @PostMapping("/session") @ResponseStatus(HttpStatus.CREATED) @Transactional
 Map<String,String> session() {
  String user = id(), home = id(), token = Tokens.create();
  db.update("INSERT INTO households(id) VALUES (?)", home);
  db.update("INSERT INTO accounts(id,token_hash,household_id,display_name) VALUES (?,?,?,?)", user, Tokens.hash(token), home, "家人-"+user.substring(0,4));
  db.update("INSERT INTO account_sessions(token_hash,account_id,expires_at,session_id,created_at,last_seen_at) VALUES (?,?,?,?,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",Tokens.hash(token),user,Timestamp.from(Instant.now().plusSeconds(30L*86400)),id());
  return Map.of("token", token);
 }

}
