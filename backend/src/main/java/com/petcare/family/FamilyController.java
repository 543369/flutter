package com.petcare.family;

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
class FamilyController extends ApiSupport {
 FamilyController(JdbcTemplate db) { super(db); }
 record InviteInput(@NotBlank @Size(max=100) String code) {}
 @PostMapping("/invites") @Transactional
 Map<String,String> invite(Authentication auth) {
  String home=household(auth), code=Tokens.create();
  db.update("DELETE FROM invites WHERE household_id=?",home);
  db.update("INSERT INTO invites(token_hash,household_id,expires_at) VALUES (?,?,?)",Tokens.hash(code),home,Timestamp.from(Instant.now().plusSeconds(86400)));
  return Map.of("code",code);
 }
 @PostMapping("/join") @Transactional
 Map<String,Boolean> join(Authentication auth, @Valid @RequestBody InviteInput input) {
  String old=household(auth);
  var homes=db.queryForList("SELECT household_id FROM invites WHERE token_hash=? AND expires_at>? FOR UPDATE",String.class,Tokens.hash(input.code()),Timestamp.from(Instant.now()));
  if(homes.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  String target=homes.getFirst();
  if(old.equals(target)) throw new ResponseStatusException(HttpStatus.CONFLICT);
  // Only empty solo households can join; never silently lose existing pet records.
  if(db.queryForObject("SELECT COUNT(*) FROM pets WHERE household_id=?",Integer.class,old)>0 || db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?",Integer.class,old)>1)
   throw new ResponseStatusException(HttpStatus.CONFLICT);
  db.update("UPDATE accounts SET household_id=? WHERE id=?",target,auth.getName());
  db.update("DELETE FROM invites WHERE token_hash=?",Tokens.hash(input.code()));
  db.update("DELETE FROM households WHERE id=?",old);
  return Map.of("joined",true);
 }

}
