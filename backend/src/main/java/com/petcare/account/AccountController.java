package com.petcare.account;

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
class AccountController extends ApiSupport {
 AccountController(JdbcTemplate db) { super(db); }
 record ProfileInput(@NotBlank @Size(max=40) String name) {}
 @PatchMapping("/profile") @Transactional
 Map<String,String> profile(Authentication auth, @Valid @RequestBody ProfileInput input) {
  household(auth);
  db.update("UPDATE accounts SET display_name=? WHERE id=?",input.name().strip(),auth.getName());
  return Map.of("name",input.name().strip());
 }

 @DeleteMapping("/account") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void deleteAccount(Authentication auth) {
  String home=household(auth);
  db.update("DELETE FROM invites WHERE household_id=?",home);
  db.update("DELETE FROM accounts WHERE id=?",auth.getName());
  if(db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?",Integer.class,home)==0)
   db.update("DELETE FROM households WHERE id=?",home);
 }
}
