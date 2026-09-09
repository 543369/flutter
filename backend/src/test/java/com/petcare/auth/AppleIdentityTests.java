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
 private Jwt jwt(String subject,String nonce,String audience) {
  return Jwt.withTokenValue("signed-token").header("alg","RS256").subject(subject).issuer("https://appleid.apple.com").audience(List.of(audience)).claim("nonce",nonce).issuedAt(Instant.now()).expiresAt(Instant.now().plusSeconds(300)).build();
 }
}
