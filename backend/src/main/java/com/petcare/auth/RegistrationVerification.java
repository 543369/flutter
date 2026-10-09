package com.petcare.auth;

import java.util.Locale;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.server.ResponseStatusException;

@Service
class RegistrationVerification {
 private final JdbcTemplate db; private final IdentityMailSender mail; private final AuthService auth;
 RegistrationVerification(JdbcTemplate db,IdentityMailSender mail,AuthService auth){this.db=db;this.mail=mail;this.auth=auth;}
 private String normalize(String email){return email.strip().toLowerCase(Locale.ROOT);}
 @Transactional
 public void request(String address){
  mail.requireConfigured();String email=normalize(address);
  db.update("INSERT IGNORE INTO registration_verifications(email) VALUES (?)",email);
  db.queryForMap("SELECT email FROM registration_verifications WHERE email=? FOR UPDATE",email);
  if(db.queryForObject("SELECT COUNT(*) FROM accounts WHERE email=?",Integer.class,email)>0)
   throw new ResponseStatusException(HttpStatus.CONFLICT);
  if(db.queryForObject("SELECT COUNT(*) FROM registration_verifications WHERE email=? AND sent_at>DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE)",Integer.class,email)>0)
   throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
  String code=Tokens.create();
  db.update("UPDATE registration_verifications SET token_hash=?,sent_at=UTC_TIMESTAMP(6),expires_at=DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 15 MINUTE) WHERE email=?",Tokens.hash(code),email);
  mail.send(email,"PetCare 注册邮箱验证 / Verify registration email","请在注册页面粘贴以下完整验证码，15 分钟内有效，仅可使用一次。\nPaste this code on the registration page. Expires in 15 minutes, single use.\n\n"+code+"\n\n如果不是你发起的请求，请忽略此邮件。 / Ignore this email if you did not request it.");
 }
 @Transactional
 public Map<String,String> register(String email,String code,String password,String name,Authentication user,String device){
  String address=normalize(email);
  if(code==null || code.isBlank() || db.update("DELETE FROM registration_verifications WHERE email=? AND token_hash=? AND expires_at>UTC_TIMESTAMP(6)",address,Tokens.hash(code.strip()))!=1)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"REGISTRATION_CODE_INVALID");
  var result=auth.register(address,password,name,user,device);
  db.update("UPDATE accounts SET email_verified=TRUE WHERE email=?",address);
  return result;
 }
 @Scheduled(fixedDelay=3600000,initialDelay=3600000)
 void cleanup(){db.update("DELETE FROM registration_verifications WHERE expires_at<DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 DAY) LIMIT 1000");}
}
