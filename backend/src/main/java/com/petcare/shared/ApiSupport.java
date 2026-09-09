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
 protected void require(int changed) { if (changed != 1) throw new ResponseStatusException(HttpStatus.NOT_FOUND); }
}
