package com.petcare.auth;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.util.List;

@SpringBootTest
@Transactional
class AppleIdentityTests {
 @Autowired JdbcTemplate db;
 @Autowired AuthService auth;
 @Autowired AuthRateLimiter limits;
 @Test void audienceNonceAndReplayAreRejectedAndSubjectIsStable() {
  JwtDecoder decoder=mock(JwtDecoder.class);
  var controller=new AppleIdentityController(db,auth,limits,"test.bundle",decoder);
  var request=new MockHttpServletRequest();request.setRemoteAddr("apple-test");
  String nonce=controller.challenge(request).get("nonce");
  String subject="test-"+java.util.UUID.randomUUID();
  var identity=new AppleIdentityController.Identity("signed-token",nonce);
  when(decoder.decode(anyString())).thenReturn(jwt(subject,nonce,"wrong.bundle"));
  assertThrows(ResponseStatusException.class,()->controller.login(identity,request));
  when(decoder.decode(anyString())).thenReturn(jwt(subject,"wrong-nonce","test.bundle"));
  assertThrows(ResponseStatusException.class,()->controller.login(identity,request));
  when(decoder.decode(anyString())).thenReturn(jwt(subject,nonce,"test.bundle"));
  String token=controller.login(identity,request).get("token");
  assertNotNull(token);
  assertThrows(ResponseStatusException.class,()->controller.login(identity,request));
  String second=controller.challenge(request).get("nonce");
  when(decoder.decode(anyString())).thenReturn(jwt(subject,second,"test.bundle"));
  controller.login(new AppleIdentityController.Identity("signed-token",second),request);
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM accounts WHERE apple_subject=?",Integer.class,subject));
  when(decoder.decode(anyString())).thenThrow(new BadJwtException("invalid signature"));
  assertThrows(ResponseStatusException.class,()->controller.login(identity,request));
 }
 @Test void linkingRequiresPasswordAndAccountBoundNonceAndKeepsTheSameIdentity() {
  JwtDecoder decoder=mock(JwtDecoder.class);
  var controller=new AppleIdentityController(db,auth,limits,"test.bundle",decoder);
  var request=new MockHttpServletRequest();request.setRemoteAddr("apple-link-"+java.util.UUID.randomUUID());
  String email=java.util.UUID.randomUUID()+"@example.com",password="Original-password-42";
  String token=auth.register(email,password,"Test",null,"test").get("token");
  String account=db.queryForObject("SELECT account_id FROM account_sessions WHERE token_hash=?",String.class,Tokens.hash(token));
  db.update("UPDATE accounts SET email_verified=TRUE WHERE id=?",account);
  String home=db.queryForObject("SELECT household_id FROM accounts WHERE id=?",String.class,account);
  var user=new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(account,"");
  assertThrows(ResponseStatusException.class,()->controller.linkChallenge(user,"Bearer "+token,new AppleIdentityController.Password("wrong"),request));
  String nonce=controller.linkChallenge(user,"Bearer "+token,new AppleIdentityController.Password(password),request).get("nonce");
  String otherSession=auth.login(email,password,"other").get("token");
  assertThrows(ResponseStatusException.class,()->controller.link(user,"Bearer "+otherSession,new AppleIdentityController.Identity("signed-token",nonce),request));
  String subject="linked-"+java.util.UUID.randomUUID();
  when(decoder.decode(anyString())).thenReturn(jwt(subject,nonce,"wrong.bundle"));
  var identity=new AppleIdentityController.Identity("signed-token",nonce);
  assertThrows(ResponseStatusException.class,()->controller.link(user,"Bearer "+token,identity,request));
  when(decoder.decode(anyString())).thenReturn(jwt(subject,nonce,"test.bundle"));
  controller.link(user,"Bearer "+token,identity,request);
  assertEquals(subject,db.queryForObject("SELECT apple_subject FROM accounts WHERE id=?",String.class,account));
  assertEquals(home,db.queryForObject("SELECT household_id FROM accounts WHERE id=?",String.class,account));
  assertThrows(ResponseStatusException.class,()->controller.link(user,"Bearer "+token,identity,request));
  String loginNonce=controller.challenge(request).get("nonce");
  when(decoder.decode(anyString())).thenReturn(jwt(subject,loginNonce,"test.bundle"));
  String appleToken=controller.login(new AppleIdentityController.Identity("signed-token",loginNonce),request).get("token");
  assertEquals(account,db.queryForObject("SELECT account_id FROM account_sessions WHERE token_hash=?",String.class,Tokens.hash(appleToken)));
 }
 @Test void linkingCannotTakeOverAnotherAppleAccountOrUseLoginNonce() {
  JwtDecoder decoder=mock(JwtDecoder.class);
  var controller=new AppleIdentityController(db,auth,limits,"test.bundle",decoder);
  var request=new MockHttpServletRequest();request.setRemoteAddr("apple-collision-"+java.util.UUID.randomUUID());
  String nonce=controller.challenge(request).get("nonce"),subject="taken-"+java.util.UUID.randomUUID();
  when(decoder.decode(anyString())).thenReturn(jwt(subject,nonce,"test.bundle"));
  controller.login(new AppleIdentityController.Identity("token",nonce),request);
  String token=auth.register(java.util.UUID.randomUUID()+"@example.com","Original-password-42","Test",null,"test").get("token");
  String account=db.queryForObject("SELECT account_id FROM account_sessions WHERE token_hash=?",String.class,Tokens.hash(token));
  db.update("UPDATE accounts SET email_verified=TRUE WHERE id=?",account);
  var user=new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(account,"");
  assertThrows(ResponseStatusException.class,()->controller.link(user,"Bearer "+token,new AppleIdentityController.Identity("token",nonce),request));
  String linking=controller.linkChallenge(user,"Bearer "+token,new AppleIdentityController.Password("Original-password-42"),request).get("nonce");
  when(decoder.decode(anyString())).thenReturn(jwt(subject,linking,"test.bundle"));
  assertEquals("APPLE_ALREADY_LINKED",assertThrows(ResponseStatusException.class,()->controller.link(user,"Bearer "+token,new AppleIdentityController.Identity("token",linking),request)).getReason());
  assertNull(db.queryForObject("SELECT apple_subject FROM accounts WHERE id=?",String.class,account));
 }
 private Jwt jwt(String subject,String nonce,String audience) {
  return Jwt.withTokenValue("signed-token").header("alg","RS256").subject(subject).issuer("https://appleid.apple.com").audience(List.of(audience)).claim("nonce",nonce).issuedAt(Instant.now()).expiresAt(Instant.now().plusSeconds(300)).build();
 }
}
