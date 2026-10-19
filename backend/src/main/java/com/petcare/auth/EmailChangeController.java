package com.petcare.auth;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/auth/email/change")
public class EmailChangeController {
 private final JdbcTemplate db;private final AuthService auth;private final AuthRateLimiter limits;private final IdentityMailSender mail;
 EmailChangeController(JdbcTemplate db,AuthService auth,AuthRateLimiter limits,IdentityMailSender mail){this.db=db;this.auth=auth;this.limits=limits;this.mail=mail;}
 public record Request(@NotBlank @Email @Size(max=254) String email,@NotBlank @Size(max=72) String password) {}
 public record Confirm(@NotBlank @Size(max=128) String code) {}
 @PostMapping("/request") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 public void request(Authentication user,@RequestHeader("Authorization") String bearer,@Valid @RequestBody Request input,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());auth.requirePassword(user,bearer.substring(7),input.password());
  String address=input.email().strip().toLowerCase(Locale.ROOT);
  var row=db.queryForMap("SELECT email,password_hash FROM accounts WHERE id=?",user.getName());
  if(row.get("email")==null)throw new ResponseStatusException(HttpStatus.CONFLICT,"PASSWORD_ACCOUNT_REQUIRED");
  if(address.equals(row.get("email")))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"EMAIL_UNCHANGED");
  if(db.queryForObject("SELECT COUNT(*) FROM accounts WHERE email=?",Integer.class,address)>0)throw new ResponseStatusException(HttpStatus.CONFLICT,"EMAIL_IN_USE");
  if(db.queryForObject("SELECT COUNT(*) FROM email_change_requests WHERE account_id=? AND sent_at>DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE)",Integer.class,user.getName())>0)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
  String code=Tokens.create();
  db.update("DELETE FROM email_change_requests WHERE account_id=?",user.getName());
  db.update("INSERT INTO email_change_requests VALUES(?,?,?,?,?,?,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 15 MINUTE),UTC_TIMESTAMP(6))",user.getName(),address,row.get("email"),Tokens.hash((String)row.get("password_hash")),Tokens.hash(bearer.substring(7)),Tokens.hash(code));
  mail.send(address,"爪伴更换邮箱 / Change PetCare email","请在发起更换的设备上粘贴验证码，15 分钟内有效。\nPaste this code on the device requesting the change. Expires in 15 minutes.\n\n"+code+"\n\n不是你发起的请求请忽略，不会更改邮箱。 / Ignore if you did not request this change.");
 }
 @PostMapping("/confirm") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 public void confirm(Authentication user,@RequestHeader("Authorization") String bearer,@Valid @RequestBody Confirm input,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  var accounts=db.queryForList("SELECT email,password_hash FROM accounts WHERE id=? FOR UPDATE",user.getName());
  if(accounts.isEmpty())throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
  var row=accounts.getFirst();
  var changes=db.queryForList("SELECT * FROM email_change_requests WHERE account_id=? AND token_hash=? AND session_hash=? AND expires_at>UTC_TIMESTAMP(6)",user.getName(),Tokens.hash(input.code()),Tokens.hash(bearer.substring(7)));
  if(changes.isEmpty())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"EMAIL_CHANGE_INVALID");
  var change=changes.getFirst();
  if(!Objects.equals(row.get("email"),change.get("old_email")) || row.get("password_hash")==null || !Tokens.hash((String)row.get("password_hash")).equals(change.get("credential_hash")))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"EMAIL_CHANGE_INVALID");
  if(db.queryForObject("SELECT COUNT(*) FROM account_sessions WHERE account_id=? AND token_hash=? AND expires_at>UTC_TIMESTAMP(6)",Integer.class,user.getName(),Tokens.hash(bearer.substring(7)))!=1)throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
  try {db.update("UPDATE accounts SET email=?,email_verified=TRUE WHERE id=?",change.get("new_email"),user.getName());}
  catch(DuplicateKeyException e){throw new ResponseStatusException(HttpStatus.CONFLICT,"EMAIL_IN_USE");}
  // Notify the previous verified inbox. Delivery acceptance is required for commit;
  // transport rejection rolls back the identity change and preserves the challenge.
  mail.send((String)row.get("email"),"爪伴邮箱已更换 / PetCare email changed","你的爪伴登录邮箱已更换。如果不是你本人操作，请尽快联系支持。\nYour PetCare sign-in email was changed. Contact support if this was not you.");
  db.update("DELETE FROM email_change_requests WHERE account_id=?",user.getName());
  db.update("DELETE FROM email_actions WHERE account_id=?",user.getName());
  db.update("DELETE FROM apple_link_challenges WHERE account_id=?",user.getName());
  db.update("DELETE FROM account_sessions WHERE account_id=? AND token_hash<>?",user.getName(),Tokens.hash(bearer.substring(7)));
 }
}
