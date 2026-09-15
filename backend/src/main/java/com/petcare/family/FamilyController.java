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
 private final com.petcare.benefits.HouseholdBenefits benefits;
 FamilyController(JdbcTemplate db,com.petcare.benefits.HouseholdBenefits benefits) { super(db);this.benefits=benefits; }
 record InvitationOptions(String role,java.util.List<String> permissions,Instant expiresAt) {}
 record InviteInput(@NotBlank @Size(max=100) String code) {}
 @PostMapping("/invites") @Transactional
 Map<String,String> invite(Authentication auth,@RequestBody(required=false) InvitationOptions input) {
  String home=permission(auth,"ADMIN"), code=Tokens.create();
  String role=input==null||input.role()==null?"MEMBER":input.role();
  if(role.equals("ADMIN"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  Instant until=input==null?null:input.expiresAt();
  String permissions=RoleRules.validate(role,input==null?null:input.permissions(),until,home,benefits);
  db.update("DELETE FROM invites WHERE household_id=?",home);
  db.update("INSERT INTO invites(token_hash,household_id,expires_at,family_role,permissions,access_until) VALUES (?,?,?,?,?,?)",Tokens.hash(code),home,Timestamp.from(Instant.now().plusSeconds(86400)),role,permissions,until==null?null:Timestamp.from(until));
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
  db.queryForObject("SELECT id FROM households WHERE id=? FOR UPDATE",String.class,target);
  var invitation=db.queryForMap("SELECT family_role,permissions,access_until FROM invites WHERE token_hash=?",Tokens.hash(input.code()));
  var until=(Timestamp)invitation.get("access_until");
  if(until!=null&&!until.toInstant().isAfter(Instant.now()))throw new ResponseStatusException(HttpStatus.GONE,"ACCESS_EXPIRED");
  RoleRules.validate((String)invitation.get("family_role"),((String)invitation.get("permissions")).isEmpty()?List.of():Arrays.asList(((String)invitation.get("permissions")).split(",")),until==null?null:until.toInstant(),target,benefits);
  db.update("UPDATE accounts SET household_id=?,family_role=?,permissions=?,access_until=? WHERE id=?",target,invitation.get("family_role"),invitation.get("permissions"),until,auth.getName());
  db.update("DELETE FROM invites WHERE token_hash=?",Tokens.hash(input.code()));
  db.update("DELETE FROM households WHERE id=?",old);
  return Map.of("joined",true);
 }

}
