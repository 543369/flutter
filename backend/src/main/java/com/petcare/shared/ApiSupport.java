package com.petcare.shared;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
public abstract class ApiSupport {
 protected final JdbcTemplate db;
 protected ApiSupport(JdbcTemplate db) { this.db=db; }
 protected String id() { return UUID.randomUUID().toString(); }
 protected String household(Authentication auth) {
  var rows = db.queryForList("SELECT household_id FROM accounts WHERE id = ? FOR UPDATE", String.class, auth.getName());
  if (rows.isEmpty()) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
  String home = rows.getFirst();
  db.queryForObject("SELECT id FROM households WHERE id=? FOR UPDATE", String.class, home);
  return home;
 }
 protected String permission(Authentication auth,String permission) {
  String home=household(auth);
  var row=db.queryForMap("SELECT family_role,permissions,access_until FROM accounts WHERE id=?",auth.getName());
  var until=(java.sql.Timestamp)row.get("access_until");
  if(until!=null && !until.toInstant().isAfter(java.time.Instant.now()))
   throw new ResponseStatusException(HttpStatus.FORBIDDEN,"ACCESS_EXPIRED");
  boolean admin="ADMIN".equals(row.get("family_role"));
  if(!admin && !permission.equals("READ") && (permission.equals("ADMIN") || !java.util.Arrays.asList(((String)row.get("permissions")).split(",")).contains(permission)))
   throw new ResponseStatusException(HttpStatus.FORBIDDEN,"PERMISSION_DENIED");
  return home;
 }
 protected void require(int changed) { if (changed != 1) throw new ResponseStatusException(HttpStatus.NOT_FOUND); }
}
