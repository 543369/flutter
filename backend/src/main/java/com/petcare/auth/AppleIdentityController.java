package com.petcare.auth;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/auth/apple")
class AppleIdentityController {
 private final JdbcTemplate db; private final AuthService auth; private final AuthRateLimiter limits;
 private final String clientId;
 private JwtDecoder decoder;
 @org.springframework.beans.factory.annotation.Autowired
 AppleIdentityController(JdbcTemplate db,AuthService auth,AuthRateLimiter limits,@Value("${petcare.apple.client-id:}") String clientId) {
  this.db=db;this.auth=auth;this.limits=limits;this.clientId=clientId;
  var decoder= NimbusJwtDecoder.withJwkSetUri("https://appleid.apple.com/auth/keys").build();
  decoder.setJwtValidator(JwtValidators.createDefaultWithIssuer("https://appleid.apple.com")); this.decoder=decoder;
 }
 AppleIdentityController(JdbcTemplate db,AuthService auth,AuthRateLimiter limits,String clientId,JwtDecoder decoder) {
  this(db,auth,limits,clientId);this.decoder=decoder;
 }
 private void enabled() {if(clientId.isBlank()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);}
 @PostMapping("/challenge") Map<String,String> challenge(HttpServletRequest request) {
  enabled();limits.check(request.getRemoteAddr());
  db.update("DELETE FROM apple_challenges WHERE expires_at<UTC_TIMESTAMP(6)");
  String nonce=Tokens.create();
  db.update("INSERT INTO apple_challenges VALUES (?,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 5 MINUTE))",Tokens.hash(nonce));
  return Map.of("nonce",nonce);
 }
 record Identity(@NotBlank @Size(max=8192) String identityToken,@NotBlank @Size(max=128) String nonce) {}
 @PostMapping("/login") @Transactional Map<String,String> login(@Valid @RequestBody Identity input,HttpServletRequest request) {
  enabled();limits.check(request.getRemoteAddr());
  Jwt jwt;
  try {jwt=decoder.decode(input.identityToken());} catch(JwtException e) {throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);}
  if(!jwt.getAudience().contains(clientId) || !input.nonce().equals(jwt.getClaimAsString("nonce")) || jwt.getSubject()==null || jwt.getSubject().isBlank() || jwt.getExpiresAt()==null)
   throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
  if(db.update("DELETE FROM apple_challenges WHERE token_hash=? AND expires_at>UTC_TIMESTAMP(6)",Tokens.hash(input.nonce()))!=1) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
  var rows=db.queryForList("SELECT id FROM accounts WHERE apple_subject=? FOR UPDATE",String.class,jwt.getSubject());
  String account;
  if(rows.isEmpty()) {
   account=UUID.randomUUID().toString();String home=UUID.randomUUID().toString();
   db.update("INSERT INTO households(id) VALUES (?)",home);
   // Apple subject is the identity. Email is not used to auto-link existing accounts.
   db.update("INSERT INTO accounts(id,token_hash,household_id,display_name,apple_subject) VALUES (?,?,?,?,?)",account,Tokens.hash(Tokens.create()),home,"Apple 家人",jwt.getSubject());
  } else account=rows.getFirst();
  return auth.session(account,"iOS Apple");
 }
}
