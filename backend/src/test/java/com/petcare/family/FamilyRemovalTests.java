package com.petcare.family;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest @Transactional
class FamilyRemovalTests {
 @Autowired JdbcTemplate db;@Autowired FamilyRolesController controller;
 String id(){return UUID.randomUUID().toString();}
 String home(){String id=id();db.update("INSERT INTO households(id) VALUES(?)",id);return id;}
 String account(String home,String role){String id=id();db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role,permissions) VALUES(?,?,?,'Tester',?,?)",id,home,id(),role,RoleRules.FULL);return id;}
 UsernamePasswordAuthenticationToken auth(String id){return new UsernamePasswordAuthenticationToken(id,"");}
 @Test void adminRemovalPreservesSharedHistoryAndSeparatesAccountWithoutDeletingIt() {
  String home=home(),admin=account(home,"ADMIN"),member=account(home,"MEMBER"),pet=id(),task=id(),event=id();
  db.update("INSERT INTO pets(id,household_id,name,species) VALUES(?,?,?,'cat')",pet,home,"Mochi");
  db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,assigned_to) VALUES(?,?,?,UTC_TIMESTAMP(),?)",task,pet,"Meal",member);
  db.update("INSERT INTO care_events VALUES(?,?,?,'COMPLETED',UTC_TIMESTAMP())",event,task,member);
  db.update("INSERT INTO account_sessions(token_hash,account_id,expires_at,session_id) VALUES(?,?,DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY),?)",id(),member,id());
  assertEquals(true,controller.remove(auth(admin),member).get("removed"));
  String next=db.queryForObject("SELECT household_id FROM accounts WHERE id=?",String.class,member);
  assertNotEquals(home,next);
  assertEquals(404,assertThrows(ResponseStatusException.class,()->new com.petcare.care.CareQueries(db).task(next,task)).getStatusCode().value());
  assertEquals("ADMIN",db.queryForObject("SELECT family_role FROM accounts WHERE id=?",String.class,member));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM pets WHERE household_id=?",Integer.class,home));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM care_events WHERE id=?",Integer.class,event));
  assertNull(db.queryForObject("SELECT assigned_to FROM care_tasks WHERE id=?",String.class,task));
  assertEquals(1L,db.queryForObject("SELECT revision FROM care_tasks WHERE id=?",Long.class,task));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM account_sessions WHERE account_id=?",Integer.class,member));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM push_outbox WHERE household_id=?",Integer.class,next));
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM pets WHERE household_id=?",Integer.class,next));
 }
 @Test void nonAdminCrossHouseholdAndSelfRemovalAreRejected() {
  String home=home(),admin=account(home,"ADMIN"),member=account(home,"MEMBER"),outsider=account(home(),"ADMIN");
  assertEquals("PERMISSION_DENIED",assertThrows(ResponseStatusException.class,()->controller.remove(auth(member),admin)).getReason());
  assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.remove(auth(admin),outsider)).getStatusCode().value());
  assertEquals("USE_LEAVE_HOUSEHOLD",assertThrows(ResponseStatusException.class,()->controller.remove(auth(admin),admin)).getReason());
  assertEquals(home,db.queryForObject("SELECT household_id FROM accounts WHERE id=?",String.class,admin));
 }
}
