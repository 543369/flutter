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
  return db.queryForObject("SELECT id,display_name,email,apple_subject,birth_date,phone,created_at,avatar_data FROM accounts WHERE id=?",(rs,n)->{
   Map<String,Object> result=new LinkedHashMap<>();
   result.put("id",rs.getString("id")); result.put("name",rs.getString("display_name"));
   result.put("account",rs.getString("email")!=null?rs.getString("email"):
    rs.getString("apple_subject")!=null?"Apple ID":"DEVICE");
   result.put("birthDate",rs.getDate("birth_date")==null?null:rs.getDate("birth_date").toLocalDate().toString());
   result.put("phone",rs.getString("phone"));
   result.put("avatarData",rs.getString("avatar_data"));
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

 record AvatarInput(@NotBlank @Size(max=200000) String avatarData) {}
 @PutMapping("/profile/avatar") @Transactional
 Map<String,Object> avatar(Authentication auth, @Valid @RequestBody AvatarInput input) {
  household(auth);
  validateAvatar(input.avatarData());
  db.update("UPDATE accounts SET avatar_data=? WHERE id=?",input.avatarData(),auth.getName());
  return profile(auth);
 }
 static void validateAvatar(String value) {
  try {
   if(value==null || value.length()>200000) throw new IllegalArgumentException();
   byte[] bytes=Base64.getDecoder().decode(value);
   try(var stream=javax.imageio.ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(bytes))) {
    var readers=javax.imageio.ImageIO.getImageReaders(stream);
    if(!readers.hasNext()) throw new IllegalArgumentException();
    var reader=readers.next();
    try {
     reader.setInput(stream);
     String format=reader.getFormatName();
     if(!format.equalsIgnoreCase("JPEG") && !format.equalsIgnoreCase("PNG")) throw new IllegalArgumentException();
     if(reader.getWidth(0)>512 || reader.getHeight(0)>512 || reader.read(0)==null) throw new IllegalArgumentException();
    } finally { reader.dispose(); }
   }
  } catch(java.io.IOException | RuntimeException e) {
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_AVATAR");
  }
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
  db.update("UPDATE care_tasks SET revision=revision+1,assigned_to=NULL WHERE assigned_to=?",auth.getName());
  db.update("DELETE FROM accounts WHERE id=?",auth.getName());
  if(db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?",Integer.class,home)==0)
   db.update("DELETE FROM households WHERE id=?",home);
 }
}
