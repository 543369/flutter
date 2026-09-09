package com.petcare.auth;
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

@SpringBootTest(properties="petcare.mail.from=test@example.com")
@Transactional
class EmailIdentityTests {
 @MockitoBean JavaMailSender mail;
 @Autowired EmailIdentityController controller;
 @Autowired AuthService auth;
 @Autowired JdbcTemplate db;
 @Test void verificationAndResetAreSingleUseAndRevokeSessions() {
  String email="identity-"+java.util.UUID.randomUUID()+"@example.com";
  String token=auth.register(email,"Original-password-42","Test",null,"test").get("token");
  String account=db.queryForObject("SELECT account_id FROM account_sessions WHERE token_hash=?",String.class,Tokens.hash(token));
  var user=new UsernamePasswordAuthenticationToken(account,null,java.util.List.of());
  var request=new MockHttpServletRequest();request.setRemoteAddr("email-test");
  controller.requestVerification(user,request);
  var messages=ArgumentCaptor.forClass(SimpleMailMessage.class);
  verify(mail).send(messages.capture());
  String code=messages.getValue().getText().split("\n\n")[1];
  controller.verify(user,new EmailIdentityController.Code(code),request);
  assertEquals(true,controller.status(user).get("verified"));
  assertThrows(ResponseStatusException.class,()->controller.verify(user,new EmailIdentityController.Code(code),request));
  reset(mail);
  controller.recovery(new EmailIdentityController.Email(email),request);
  verify(mail).send(messages.capture());
  String recovery=messages.getValue().getText().split("\n\n")[1];
  controller.reset(new EmailIdentityController.Reset(recovery,"Changed-password-43"),request);
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM account_sessions WHERE account_id=?",Integer.class,account));
  assertThrows(ResponseStatusException.class,()->controller.reset(new EmailIdentityController.Reset(recovery,"Another-password-44"),request));
  assertThrows(ResponseStatusException.class,()->auth.login(email,"Original-password-42","test"));
  assertNotNull(auth.login(email,"Changed-password-43","test").get("token"));
 }
 @Test void unknownEmailDoesNotSendMail() {
  var request=new MockHttpServletRequest();request.setRemoteAddr("unknown-test");
  controller.recovery(new EmailIdentityController.Email("missing-"+java.util.UUID.randomUUID()+"@example.com"),request);
  verifyNoInteractions(mail);
 }
}
