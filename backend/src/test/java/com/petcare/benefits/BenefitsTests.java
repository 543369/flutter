package com.petcare.benefits;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest
@Transactional
class BenefitsTests {
 @Autowired JdbcTemplate db;
 private String id() {return UUID.randomUUID().toString();}
 private String home() {String home=id();db.update("INSERT INTO households(id) VALUES (?)",home);return home;}
 @Test void expiryFallsBackWithoutBlockingStorageReduction() {
  String home=home(),pet=id();
  var benefits=new HouseholdBenefits(db,50,100,false);
  db.update("INSERT INTO pets(id,household_id,name,species) VALUES (?,?,?,?)",pet,home,"Test","cat");
  db.update("INSERT INTO pet_photos(pet_id,position_index,photo_data) VALUES (?,0,?)",pet,Base64.getEncoder().encodeToString(new byte[80]));
  db.update("INSERT INTO household_benefits(household_id,storage_limit_bytes,expires_at) VALUES (?,?,?)",home,200,Timestamp.from(Instant.now().plusSeconds(3600)));
  assertEquals("FAMILY",benefits.access(home).tier()); assertEquals(200,benefits.access(home).limitBytes());
  benefits.requireExtended(home);
  db.update("UPDATE household_benefits SET expires_at=? WHERE household_id=?",Timestamp.from(Instant.now().minusSeconds(60)),home);
  assertEquals("FREE",benefits.access(home).tier()); assertEquals(50,benefits.access(home).limitBytes());
  assertEquals(403,assertThrows(ResponseStatusException.class,()->benefits.requireExtended(home)).getStatusCode().value());
  assertDoesNotThrow(()->benefits.checkGrowth(home,80));
  db.update("INSERT INTO pet_photos(pet_id,position_index,photo_data) VALUES (?,1,?)",pet,Base64.getEncoder().encodeToString(new byte[1]));
  assertEquals(413,assertThrows(ResponseStatusException.class,()->benefits.checkGrowth(home,80)).getStatusCode().value());
  db.update("DELETE FROM pet_photos WHERE pet_id=? AND position_index=1",pet);
  assertDoesNotThrow(()->benefits.checkGrowth(home,81));
 }
 @Test void reportUsesLocalYearBoundaryAndYearEndState() {
  String home=home(),account=id(),pet=id();
  db.update("INSERT INTO accounts(id,household_id,token_hash) VALUES (?,?,?)",account,home,id());
  db.update("INSERT INTO pets(id,household_id,name,species) VALUES (?,?,?,?)",pet,home,"Test","cat");
  var controller=new BenefitsController(db,new HouseholdBenefits(db,100,200,true));
  var auth=new UsernamePasswordAuthenticationToken(account,"unused");
  String t1=task(pet),t2=task(pet),t3=task(pet);
  event(t1,account,"COMPLETED","2024-12-31T16:00:00Z");
  event(t1,account,"REOPENED","2026-01-01T00:00:00Z");
  event(t2,account,"COMPLETED","2025-03-01T00:00:00Z");
  event(t2,account,"REOPENED","2025-12-01T00:00:00Z");
  event(t3,account,"COMPLETED","2025-12-31T16:00:00Z");
  var report=controller.annual(auth,2025,"Asia/Shanghai");
  assertEquals(1,report.get("careCount")); assertEquals(1,((int[])report.get("monthlyCare"))[0]);
  assertEquals(1,report.get("activeDays"));
  var utc=controller.annual(auth,2025,"UTC");
  assertEquals(1,utc.get("careCount")); assertEquals(1,((int[])utc.get("monthlyCare"))[11]);
 }
 private String task(String pet) {
  String task=id();db.update("INSERT INTO care_tasks(id,pet_id,title,due_at) VALUES (?,?,?,?)",task,pet,"Test",Timestamp.from(Instant.parse("2025-01-01T00:00:00Z")));return task;
 }
 private void event(String task,String actor,String action,String at) {
  db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,?)",id(),task,actor,action,Timestamp.from(Instant.parse(at)));
 }
}
