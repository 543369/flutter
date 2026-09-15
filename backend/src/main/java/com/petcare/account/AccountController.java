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
 record ProfileInput(@NotBlank @Size(max=40) String name,
  @jakarta.validation.constraints.PastOrPresent java.time.LocalDate birthDate,
  @Size(max=25) @Pattern(regexp="^$|^[+]?[0-9][0-9 ()-]{5,24}$") String phone) {}
 @GetMapping("/profile") @Transactional
 Map<String,Object> profile(Authentication auth) {
  household(auth);
  return db.queryForObject("SELECT id,display_name,email,apple_subject,birth_date,phone,created_at FROM accounts WHERE id=?",(rs,n)->{
   Map<String,Object> result=new LinkedHashMap<>();
   result.put("id",rs.getString("id")); result.put("name",rs.getString("display_name"));
   result.put("account",rs.getString("email")!=null?rs.getString("email"):
    rs.getString("apple_subject")!=null?"Apple ID":"DEVICE");
   result.put("birthDate",rs.getDate("birth_date")==null?null:rs.getDate("birth_date").toLocalDate().toString());
   result.put("phone",rs.getString("phone"));
   result.put("createdAt",rs.getTimestamp("created_at")==null?null:rs.getTimestamp("created_at").toInstant().toString());
   return result;
  },auth.getName());
 }
 @PatchMapping("/profile") @Transactional
 Map<String,Object> profile(Authentication auth, @Valid @RequestBody ProfileInput input) {
  household(auth);
  db.update("UPDATE accounts SET display_name=?,birth_date=?,phone=? WHERE id=?",input.name().strip(),input.birthDate(),input.phone()==null||input.phone().isBlank()?null:input.phone().strip(),auth.getName());
  return profile(auth);
 }

 @DeleteMapping("/account") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void deleteAccount(Authentication auth) {
  String home=household(auth);
  if(db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?",Integer.class,home)>1
    && "ADMIN".equals(db.queryForObject("SELECT family_role FROM accounts WHERE id=?",String.class,auth.getName()))
    && db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=? AND family_role='ADMIN'",Integer.class,home)==1)
   throw new ResponseStatusException(HttpStatus.CONFLICT,"LAST_ADMIN");
  if("ADMIN".equals(db.queryForObject("SELECT family_role FROM accounts WHERE id=?",String.class,auth.getName())))
   db.update("DELETE FROM invites WHERE household_id=?",home);
  db.update("UPDATE care_tasks SET assigned_to=NULL WHERE assigned_to=?",auth.getName());
  db.update("DELETE FROM accounts WHERE id=?",auth.getName());
  if(db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?",Integer.class,home)==0)
   db.update("DELETE FROM households WHERE id=?",home);
 }
}
