package com.petcare.auth;

import com.petcare.shared.ApiSupport;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService extends ApiSupport {
 private final BCryptPasswordEncoder passwords = new BCryptPasswordEncoder(12);
 private final String dummy = passwords.encode("dummy-account-timing-password");
 public AuthService(JdbcTemplate db) { super(db); }
 private String email(String value) { return value.strip().toLowerCase(Locale.ROOT); }
 private void validatePassword(String password) {
  if(password.getBytes(StandardCharsets.UTF_8).length>72) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
 }
 Map<String,String> session(String account, String device) {
  String token=Tokens.create();
  db.update("INSERT INTO account_sessions(token_hash,account_id,expires_at,session_id,device_name,created_at,last_seen_at) VALUES (?,?,?,?,?,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",Tokens.hash(token),account,Timestamp.from(Instant.now().plusSeconds(30L*86400)),id(),device);
  return Map.of("token",token);
 }
 @Transactional
 public Map<String,String> register(String email,String password,String name,Authentication auth,String device) {
  validatePassword(password);
  String account;
  if(auth!=null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
   household(auth);
   account=auth.getName();
   if(Boolean.TRUE.equals(db.queryForObject("SELECT email IS NOT NULL FROM accounts WHERE id=?",Boolean.class,account)))
    throw new ResponseStatusException(HttpStatus.CONFLICT);
  } else {
   account=id(); String home=id();
   db.update("INSERT INTO households(id) VALUES (?)",home);
   db.update("INSERT INTO accounts(id,token_hash,household_id,display_name) VALUES (?,?,?,?)",account,Tokens.hash(Tokens.create()),home,name.strip());
  }
  try {
   db.update("UPDATE accounts SET email=?,password_hash=?,display_name=? WHERE id=?",email(email),passwords.encode(password),name.strip(),account);
  } catch(DuplicateKeyException e) { throw new ResponseStatusException(HttpStatus.CONFLICT); }
  // Upgrading a device identity keeps its household and pets but revokes old tokens.
  db.update("DELETE FROM account_sessions WHERE account_id=?",account);
  return session(account,device);
 }
 @Transactional
 public Map<String,String> login(String email,String password,String device) {
  validatePassword(password);
  var rows=db.queryForList("SELECT id,password_hash FROM accounts WHERE email=? FOR UPDATE",email(email));
  String hash=rows.isEmpty()?dummy:(String)rows.getFirst().get("password_hash");
  if(!passwords.matches(password,hash) || rows.isEmpty()) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
  return session((String)rows.getFirst().get("id"),device);
 }
 @Transactional
 public void logout(String token) {
  db.update("DELETE FROM account_sessions WHERE token_hash=?",Tokens.hash(token));
 }
 private void verifyCurrentSession(Authentication user,String token) {
  var accounts=db.queryForList("SELECT id FROM accounts WHERE id=? FOR UPDATE",String.class,user.getName());
  if(accounts.isEmpty() || db.queryForObject("SELECT COUNT(*) FROM account_sessions WHERE account_id=? AND token_hash=? AND expires_at>UTC_TIMESTAMP(6)",Integer.class,user.getName(),Tokens.hash(token))!=1)
   throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
 }
 @Transactional
 public void changePassword(Authentication user,String token,String oldPassword,String newPassword) {
  verifyCurrentSession(user,token);
  validatePassword(oldPassword); validatePassword(newPassword);
  String oldHash=db.queryForObject("SELECT password_hash FROM accounts WHERE id=?",String.class,user.getName());
  if(oldHash==null) throw new ResponseStatusException(HttpStatus.CONFLICT);
  if(!passwords.matches(oldPassword,oldHash)) throw new ResponseStatusException(HttpStatus.FORBIDDEN);
  if(passwords.matches(newPassword,oldHash)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  db.update("DELETE FROM email_actions WHERE account_id=? AND purpose='reset'",user.getName());
  db.update("UPDATE accounts SET password_hash=? WHERE id=?",passwords.encode(newPassword),user.getName());
  db.update("DELETE FROM account_sessions WHERE account_id=? AND token_hash<>?",user.getName(),Tokens.hash(token));
 }
 @Transactional
 public java.util.List<Map<String,Object>> sessions(Authentication user,String token) {
  verifyCurrentSession(user,token);
  String hash=Tokens.hash(token);
  return db.query("SELECT session_id,device_name,created_at,last_seen_at,expires_at,token_hash FROM account_sessions WHERE account_id=? AND expires_at>UTC_TIMESTAMP(6) ORDER BY created_at DESC,session_id",(rs,n)->{
   Map<String,Object> row=new java.util.LinkedHashMap<>();
   row.put("id",rs.getString(1)); row.put("deviceName",rs.getString(2));
   row.put("createdAt",rs.getTimestamp(3)==null?null:rs.getTimestamp(3).toInstant().toString());
   row.put("lastSeenAt",rs.getTimestamp(4)==null?null:rs.getTimestamp(4).toInstant().toString());
   row.put("expiresAt",rs.getTimestamp(5).toInstant().toString()); row.put("current",hash.equals(rs.getString(6)));
   return row;
  },user.getName());
 }
 @Transactional
 public void revokeSession(Authentication user,String token,String sessionId) {
  verifyCurrentSession(user,token);
  // Current session must use the ordinary logout flow, keeping client state consistent.
  var hashes=db.queryForList("SELECT token_hash FROM account_sessions WHERE session_id=? AND account_id=?",String.class,sessionId,user.getName());
  if(hashes.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  if(hashes.getFirst().equals(Tokens.hash(token))) throw new ResponseStatusException(HttpStatus.CONFLICT);
  db.update("DELETE FROM account_sessions WHERE session_id=? AND account_id=?",sessionId,user.getName());
 }
 @Transactional
 public void revokeOthers(Authentication user,String token) {
  verifyCurrentSession(user,token);
  db.update("DELETE FROM account_sessions WHERE account_id=? AND token_hash<>?",user.getName(),Tokens.hash(token));
 }

}
