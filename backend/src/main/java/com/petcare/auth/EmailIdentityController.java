package com.petcare.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/auth")
class EmailIdentityController {
 private final JdbcTemplate db; private final AuthRateLimiter limits;
 private final ObjectProvider<JavaMailSender> mail;
 private final String from;
 EmailIdentityController(JdbcTemplate db,AuthRateLimiter limits,ObjectProvider<JavaMailSender> mail,@Value("${petcare.mail.from:}") String from) {
  this.db=db;this.limits=limits;this.mail=mail;this.from=from;
 }
 record Email(@NotBlank @jakarta.validation.constraints.Email @Size(max=254) String email) {}
 record Code(@NotBlank @Size(max=128) String code) {}
 record Reset(@NotBlank @Size(max=128) String code,@NotBlank @Size(min=10,max=72) String password) {}
 @GetMapping("/email/status") Map<String,Object> status(Authentication user) {
  return db.queryForMap("SELECT email, email_verified AS verified, password_hash IS NOT NULL AS hasPassword FROM accounts WHERE id=?",user.getName());
 }
 private void send(String account,String address,String purpose) {
  var sender=mail.getIfAvailable();
  if(sender==null || from.isBlank()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);
  if(db.queryForObject("SELECT COUNT(*) FROM email_actions WHERE account_id=? AND purpose=? AND sent_at>DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE)",Integer.class,account,purpose)>0) return;
  String code=Tokens.create();
  db.update("DELETE FROM email_actions WHERE account_id=? AND purpose=?",account,purpose);
  db.update("INSERT INTO email_actions VALUES (?,?,?,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 15 MINUTE),UTC_TIMESTAMP(6))",account,purpose,Tokens.hash(code));
  SimpleMailMessage message=new SimpleMailMessage(); message.setFrom(from);message.setTo(address);
  message.setSubject(purpose.equals("verify")?"PetCare 邮箱验证 / Verify email":"PetCare 重置密码 / Reset password");
  message.setText("请在 PetCare 中粘贴以下验证码，15 分钟内有效，仅可使用一次。\nPaste this code in PetCare. Expires in 15 minutes, single use.\n\n"+code+"\n\n如果不是你发起的请求，请忽略此邮件。 / Ignore this email if you did not request it.");
  sender.send(message);
 }
 @PostMapping("/email/request") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void requestVerification(Authentication user,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  var row=db.queryForMap("SELECT email,email_verified FROM accounts WHERE id=? FOR UPDATE",user.getName());
  if(row.get("email")==null) throw new ResponseStatusException(HttpStatus.CONFLICT);
  if(!Boolean.TRUE.equals(row.get("email_verified"))) send(user.getName(),(String)row.get("email"),"verify");
 }
 @PostMapping("/email/confirm") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void verify(Authentication user,@Valid @RequestBody Code input,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  db.queryForList("SELECT id FROM accounts WHERE id=? FOR UPDATE",user.getName());
  if(db.update("DELETE FROM email_actions WHERE account_id=? AND purpose='verify' AND token_hash=? AND expires_at>UTC_TIMESTAMP(6)",user.getName(),Tokens.hash(input.code()))!=1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  db.update("UPDATE accounts SET email_verified=TRUE WHERE id=?",user.getName());
 }
 @PostMapping("/recovery/request") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void recovery(@Valid @RequestBody Email input,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  if(mail.getIfAvailable()==null || from.isBlank()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);
  var rows=db.queryForList("SELECT id,email FROM accounts WHERE email=? AND password_hash IS NOT NULL FOR UPDATE",input.email().strip().toLowerCase(Locale.ROOT));
  if(!rows.isEmpty()) send((String)rows.getFirst().get("id"),(String)rows.getFirst().get("email"),"reset");
 }
 @PostMapping("/recovery/confirm") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void reset(@Valid @RequestBody Reset input,HttpServletRequest request) {
  limits.check(request.getRemoteAddr());
  if(input.password().getBytes(java.nio.charset.StandardCharsets.UTF_8).length>72) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var rows=db.queryForList("SELECT account_id FROM email_actions WHERE token_hash=? AND purpose='reset'",String.class,Tokens.hash(input.code()));
  if(rows.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  String account=rows.getFirst();
  db.queryForList("SELECT id FROM accounts WHERE id=? FOR UPDATE",account);
  if(db.update("DELETE FROM email_actions WHERE account_id=? AND purpose='reset' AND token_hash=? AND expires_at>UTC_TIMESTAMP(6)",account,Tokens.hash(input.code()))!=1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  db.update("UPDATE accounts SET password_hash=?,email_verified=TRUE WHERE id=?",new BCryptPasswordEncoder(12).encode(input.password()),account);
  db.update("DELETE FROM account_sessions WHERE account_id=?",account);
 }
}
