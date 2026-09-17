package com.petcare.care;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest @Transactional
class CareAdjustmentsTests {
 @Autowired JdbcTemplate db;
 @Autowired CareController controller;
 @Autowired CarePlans plans;
 String id(){return UUID.randomUUID().toString();}
 String home(){String h=id();db.update("INSERT INTO households(id) VALUES (?)",h);return h;}
 String account(String home){String a=id();db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role) VALUES (?,?,?,?,?)",a,home,id(),"Tester","ADMIN");return a;}
 String pet(String home){String p=id();db.update("INSERT INTO pets(id,household_id,name,species) VALUES (?,?,?,?)",p,home,"Pet","dog");return p;}
 UsernamePasswordAuthenticationToken auth(String id){return new UsernamePasswordAuthenticationToken(id,"unused");}
 @Test void skippedOccurrenceIsNotRecreatedAndDoesNotCountAsCompleted(){
  String h=home(),a=account(h),p=pet(h);
  var made=controller.addTask(auth(a),new CareController.TaskInput(p,"Walk",Instant.now().plusSeconds(3600),"DAILY","UTC","WALK"));
  String task=made.get("id");
  controller.dismiss(auth(a),task,new CareController.Dismissal("SKIPPED"));
  controller.dismiss(auth(a),task,new CareController.Dismissal("SKIPPED"));
  plans.materialize(h);
  var row=controller.getTask(auth(a),task);
  assertEquals(true,row.get("cancelled")); assertEquals(false,row.get("completed"));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM care_events WHERE task_id=? AND action='SKIPPED'",Integer.class,task));
  assertThrows(ResponseStatusException.class,()->controller.complete(auth(a),task,new CareController.Completion(true)));
 }
 @Test void reschedulingOneOccurrenceKeepsTombstoneAndScope(){
  String h=home(),a=account(h),p=pet(h);
  var made=controller.addTask(auth(a),new CareController.TaskInput(p,"Walk",Instant.now().plusSeconds(3600),"DAILY","UTC","WALK"));
  String task=made.get("id");
  var moved=controller.reschedule(auth(a),task,new CareController.Adjustment(Instant.now().plusSeconds(7200)));
  assertNotEquals(task,moved.get("id")); assertNull(moved.get("planId"));
  plans.materialize(h);
  assertEquals(true,controller.getTask(auth(a),task).get("cancelled"));
  String outsider=account(home());
  assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.getTask(auth(outsider),(String)moved.get("id"))).getStatusCode().value());
  assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.dismiss(auth(outsider),task,new CareController.Dismissal("CANCELLED"))).getStatusCode().value());
 }
 @Test void completionIsIdempotentAndReturnsActorForNotification(){
  String h=home(),a=account(h),p=pet(h);
  String task=controller.addTask(auth(a),new CareController.TaskInput(p,"Food",Instant.now().plusSeconds(3600),"NONE",null,"FEEDING")).get("id");
  var done=controller.complete(auth(a),task,new CareController.Completion(true));
  controller.complete(auth(a),task,new CareController.Completion(true));
  assertEquals(true,done.get("completed"));assertNotNull(done.get("lastEvent"));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM care_events WHERE task_id=?",Integer.class,task));
  assertThrows(ResponseStatusException.class,()->controller.reschedule(auth(a),task,new CareController.Adjustment(Instant.now().plusSeconds(7200))));
 }
 @Test void adjustingFuturePlanRetainsCompletedOccurrences(){
  String h=home(),a=account(h),p=pet(h);
  var made=controller.addTask(auth(a),new CareController.TaskInput(p,"Walk",Instant.now().plusSeconds(3600),"DAILY","UTC","WALK"));
  controller.complete(auth(a),made.get("id"),new CareController.Completion(true));
  var replacement=controller.adjustPlan(auth(a),made.get("planId"),new CareController.PlanAdjustment(Instant.now().plusSeconds(7200),"WEEKLY","UTC"));
  assertNotEquals(made.get("planId"),replacement.get("planId"));
  assertEquals(true,controller.getTask(auth(a),made.get("id")).get("completed"));
  assertEquals(false,db.queryForObject("SELECT active FROM care_plans WHERE id=?",Boolean.class,made.get("planId")));
 }
 @Test void completionRefillsTheSixtyFirstReminder() {
  String h=home(),a=account(h),p=pet(h),first=null;
  for(int n=0;n<61;n++) {
   String task=controller.addTask(auth(a),new CareController.TaskInput(p,"Care",Instant.now().plusSeconds(3600+n*60),"NONE",null,"CUSTOM")).get("id");
   if(n==0) first=task;
  }
  var done=controller.complete(auth(a),first,new CareController.Completion(true));
  assertEquals(60,((java.util.List<?>)done.get("reminderTasks")).size());
 }
}
