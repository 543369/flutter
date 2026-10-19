package com.petcare.auth;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.mockito.ArgumentCaptor;

@SpringBootTest(properties={"petcare.mail.from=test@example.com","petcare.mail.provider=smtp"}) @Transactional
class EmailChangeTests {
 @MockitoBean JavaMailSender mail;
 @Autowired EmailChangeController controller;@Autowired AuthService auth;@Autowired JdbcTemplate db;
 static final String PASSWORD="Original-password-42";
 String id(){return UUID.randomUUID().toString();}
 record User(String id,String email,String token,String home) {
  UsernamePasswordAuthenticationToken auth(){return new UsernamePasswordAuthenticationToken(id,"");}
  String bearer(){return "Bearer "+token;}
 }
 User user(){String email=id()+"@example.com";String token=auth.register(email,PASSWORD,"Test",null,"test").get("token");String account=db.queryForObject("SELECT account_id FROM account_sessions WHERE token_hash=?",String.class,Tokens.hash(token));db.update("UPDATE accounts SET email_verified=TRUE WHERE id=?",account);return new User(account,email,token,db.queryForObject("SELECT household_id FROM accounts WHERE id=?",String.class,account));}
 MockHttpServletRequest request(){var r=new MockHttpServletRequest();r.setRemoteAddr(id());return r;}
 String start(User user,String email){controller.request(user.auth(),user.bearer(),new EmailChangeController.Request(email,PASSWORD),request());var messages=ArgumentCaptor.forClass(SimpleMailMessage.class);verify(mail,atLeastOnce()).send(messages.capture());return messages.getValue().getText().split("\n\n")[1];}
 @Test void changeRequiresBothProofsAndKeepsCurrentAccountAndSession() {
  var user=user();var outsider=user();String next=id()+"@example.com";
  String otherToken=auth.login(user.email,PASSWORD,"other device").get("token");
  String code=start(user,next.toUpperCase(Locale.ROOT));
  assertThrows(ResponseStatusException.class,()->controller.confirm(outsider.auth(),outsider.bearer(),new EmailChangeController.Confirm(code),request()));
  assertThrows(ResponseStatusException.class,()->controller.confirm(user.auth(),"Bearer "+otherToken,new EmailChangeController.Confirm(code),request()));
  controller.confirm(user.auth(),user.bearer(),new EmailChangeController.Confirm(code),request());
  assertEquals(next,db.queryForObject("SELECT email FROM accounts WHERE id=?",String.class,user.id));
  assertEquals(user.home,db.queryForObject("SELECT household_id FROM accounts WHERE id=?",String.class,user.id));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM account_sessions WHERE account_id=?",Integer.class,user.id));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM account_sessions WHERE token_hash=?",Integer.class,Tokens.hash(user.token)));
  verify(mail,times(2)).send(any(SimpleMailMessage.class));
  assertThrows(ResponseStatusException.class,()->controller.confirm(user.auth(),user.bearer(),new EmailChangeController.Confirm(code),request()));
  assertThrows(ResponseStatusException.class,()->auth.login(user.email,PASSWORD,"test"));
  assertNotNull(auth.login(next,PASSWORD,"test").get("token"));
 }
 @Test void incorrectPasswordCooldownExpiryAndCredentialChangesRejectOldProof() {
  var user=user();String next=id()+"@example.com";
  assertEquals("CURRENT_PASSWORD_INVALID",assertThrows(ResponseStatusException.class,()->controller.request(user.auth(),user.bearer(),new EmailChangeController.Request(next,"wrong"),request())).getReason());
  verifyNoInteractions(mail);
  String code=start(user,next);
  assertEquals(429,assertThrows(ResponseStatusException.class,()->controller.request(user.auth(),user.bearer(),new EmailChangeController.Request(next,PASSWORD),request())).getStatusCode().value());
  db.update("UPDATE email_change_requests SET expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE account_id=?",user.id);
  assertThrows(ResponseStatusException.class,()->controller.confirm(user.auth(),user.bearer(),new EmailChangeController.Confirm(code),request()));
  db.update("UPDATE email_change_requests SET expires_at=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 MINUTE) WHERE account_id=?",user.id);
  auth.changePassword(user.auth(),user.token,PASSWORD,"Changed-password-43");
  assertThrows(ResponseStatusException.class,()->controller.confirm(user.auth(),user.bearer(),new EmailChangeController.Confirm(code),request()));
 }
 @Test void occupiedEmailCannotBeClaimedAtRequestOrConfirmation() {
  var user=user();var occupied=user();
  assertEquals("EMAIL_IN_USE",assertThrows(ResponseStatusException.class,()->controller.request(user.auth(),user.bearer(),new EmailChangeController.Request(occupied.email,PASSWORD),request())).getReason());
  String next=id()+"@example.com",code=start(user,next);
  db.update("UPDATE accounts SET email=? WHERE id=?",next,occupied.id);
  assertEquals("EMAIL_IN_USE",assertThrows(ResponseStatusException.class,()->controller.confirm(user.auth(),user.bearer(),new EmailChangeController.Confirm(code),request())).getReason());
  assertEquals(user.email,db.queryForObject("SELECT email FROM accounts WHERE id=?",String.class,user.id));
 }
 @Test @Transactional(propagation=org.springframework.transaction.annotation.Propagation.NOT_SUPPORTED)
 void mailFailureDoesNotCommitEmailOrConsumeProof() {
  var user=user();
  try {
   doThrow(new org.springframework.mail.MailSendException("unavailable")).when(mail).send(any(SimpleMailMessage.class));
   assertThrows(ResponseStatusException.class,()->start(user,id()+"@example.com"));
   assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM email_change_requests WHERE account_id=?",Integer.class,user.id));
   reset(mail);String code=start(user,id()+"@example.com");
   doThrow(new org.springframework.mail.MailSendException("unavailable")).when(mail).send(any(SimpleMailMessage.class));
   assertThrows(ResponseStatusException.class,()->controller.confirm(user.auth(),user.bearer(),new EmailChangeController.Confirm(code),request()));
   assertEquals(user.email,db.queryForObject("SELECT email FROM accounts WHERE id=?",String.class,user.id));
   assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM email_change_requests WHERE account_id=?",Integer.class,user.id));
  } finally {db.update("DELETE FROM accounts WHERE id=?",user.id);db.update("DELETE FROM households WHERE id=?",user.home);}
 }
}
