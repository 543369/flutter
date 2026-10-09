package com.petcare.auth;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.mockito.ArgumentCaptor;

@SpringBootTest @Transactional
class RegistrationVerificationTests {
 @Autowired RegistrationVerification registration;
 @Autowired JdbcTemplate db;
 @MockitoBean IdentityMailSender mail;
 String email(){return java.util.UUID.randomUUID()+"@example.com";}
 String send(String email){
  registration.request(email);
  var text=ArgumentCaptor.forClass(String.class);verify(mail).send(eq(email),anyString(),text.capture());
  return text.getValue().split("\n\n")[1];
 }
 @Test void codeIsBoundToEmailAndConsumedOnlyOnSuccessfulRegistration(){
  String email=email(),code=send(email);
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM accounts WHERE email=?",Integer.class,email));
  assertThrows(ResponseStatusException.class,()->registration.register(email,"wrong","Strong-password-123","Test",null,"test"));
  assertThrows(ResponseStatusException.class,()->registration.register(email(),code,"Strong-password-123","Test",null,"test"));
  var result=registration.register(email.toUpperCase(),code,"Strong-password-123","Test",null,"test");
  assertNotNull(result.get("token"));
  assertTrue(db.queryForObject("SELECT email_verified FROM accounts WHERE email=?",Boolean.class,email));
  assertThrows(ResponseStatusException.class,()->registration.register(email,code,"Strong-password-123","Test",null,"test"));
 }
 @Test void missingExpiredAndReplacedCodesCannotRegister(){
  String email=email(),code=send(email);
  assertThrows(ResponseStatusException.class,()->registration.register(email,null,"Strong-password-123","Test",null,"test"));
  db.update("UPDATE registration_verifications SET expires_at=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 SECOND),sent_at=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 2 MINUTE) WHERE email=?",email);
  assertThrows(ResponseStatusException.class,()->registration.register(email,code,"Strong-password-123","Test",null,"test"));
  reset(mail);String replacement=send(email);
  assertNotEquals(code,replacement);
  assertThrows(ResponseStatusException.class,()->registration.register(email,code,"Strong-password-123","Test",null,"test"));
  assertNotNull(registration.register(email,replacement,"Strong-password-123","Test",null,"test").get("token"));
 }
 @Test void resendIsRateLimited(){String email=email();send(email);assertEquals(429,assertThrows(ResponseStatusException.class,()->registration.request(email)).getStatusCode().value());verify(mail,times(1)).send(anyString(),anyString(),anyString());}
 @Test void verifiedRegistrationUpgradesGuestWithoutMovingHousehold(){
  String email=email(),code=send(email),home=java.util.UUID.randomUUID().toString(),account=java.util.UUID.randomUUID().toString();
  db.update("INSERT INTO households(id) VALUES (?)",home);
  db.update("INSERT INTO accounts(id,token_hash,household_id) VALUES (?,?,?)",account,Tokens.hash(Tokens.create()),home);
  var user=new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(account,null,java.util.List.of());
  registration.register(email,code,"Strong-password-123","Test",user,"test");
  assertEquals(home,db.queryForObject("SELECT household_id FROM accounts WHERE email=?",String.class,email));
  assertEquals(account,db.queryForObject("SELECT id FROM accounts WHERE email=? AND email_verified=TRUE",String.class,email));
 }
 @Test @Transactional(propagation=org.springframework.transaction.annotation.Propagation.NOT_SUPPORTED)
 void sendingFailureRollsBackPendingCode(){
  String email=email();
  doThrow(new ResponseStatusException(org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE)).when(mail).send(anyString(),anyString(),anyString());
  assertThrows(ResponseStatusException.class,()->registration.request(email));
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM registration_verifications WHERE email=?",Integer.class,email));
 }

}
