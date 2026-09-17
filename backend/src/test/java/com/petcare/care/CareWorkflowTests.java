package com.petcare.care;

import java.time.*;
import java.sql.Timestamp;
import java.util.*;
import com.petcare.health.HealthRecordController;
import com.petcare.benefits.HouseholdBenefits;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest @Transactional
class CareWorkflowTests {
 @Autowired JdbcTemplate db;
 @Autowired CarePlans plans;
 @Autowired CareQueries queries;
 String id(){return UUID.randomUUID().toString();}
 String home(){String id=id();db.update("INSERT INTO households(id) VALUES (?)",id);return id;}
 String owner(String home){String id=id();db.update("INSERT INTO accounts(id,household_id,token_hash,display_name) VALUES (?,?,?,?)",id,home,id,"Alex");return id;}
 String pet(String home){String id=id();db.update("INSERT INTO pets(id,household_id,name,species) VALUES (?,?,?,?)",id,home,"Mochi","cat");return id;}
 UsernamePasswordAuthenticationToken auth(String owner){return new UsernamePasswordAuthenticationToken(owner,"unused");}
 String task(String pet,Instant at){String id=id();db.update("INSERT INTO care_tasks(id,pet_id,title,due_at) VALUES (?,?,?,?)",id,pet,"Care",Timestamp.from(at));return id;}
 @Test void reschedulingAndSkippingDoNotRegenerateTheOriginalOccurrence(){
  String home=home(),owner=owner(home),pet=pet(home);var controller=new CareController(db,plans);
  Instant start=Instant.now().plusSeconds(3600).truncatedTo(java.time.temporal.ChronoUnit.SECONDS);
  var created=controller.addTask(auth(owner),new CareController.TaskInput(pet,"Meal",start,"DAILY","Asia/Shanghai","FEEDING"));
  String task=created.get("id"),plan=created.get("planId");
  int count=db.queryForObject("SELECT COUNT(*) FROM care_tasks WHERE plan_id=?",Integer.class,plan);
  // Can move onto another occurrence's scheduled time; original occurrence identity stays unique.
  controller.reschedule(auth(owner),task,new CareController.Schedule(start.plusSeconds(86400)));
  plans.materialize(home);
  assertEquals(count,db.queryForObject("SELECT COUNT(*) FROM care_tasks WHERE plan_id=?",Integer.class,plan));
  assertEquals(start,db.queryForObject("SELECT occurrence_at FROM care_tasks WHERE id=?",Timestamp.class,task).toInstant());
  controller.disposition(auth(owner),task,new CareController.Disposition("SKIPPED"));
  controller.disposition(auth(owner),task,new CareController.Disposition("SKIPPED"));
  plans.materialize(home);
  assertEquals(count,db.queryForObject("SELECT COUNT(*) FROM care_tasks WHERE plan_id=?",Integer.class,plan));
  assertEquals(2,queries.recent(home,task).size());
  assertEquals(true,queries.task(home,task).get("skipped"));
  assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.complete(auth(owner),task,new CareController.Completion(true))).getStatusCode().value());
 }
 @Test void mutationsAreScopedIdempotentAndReturnLocalState(){
  String home=home(),owner=owner(home),pet=pet(home),task=task(pet,Instant.now());var controller=new CareController(db,plans);
  var result=controller.complete(auth(owner),task,new CareController.Completion(true));
  assertEquals(true,((Map<?,?>)result.get("task")).get("completed"));
  controller.complete(auth(owner),task,new CareController.Completion(true));
  assertEquals(1,queries.recent(home,task).size());
  assertEquals(409,assertThrows(ResponseStatusException.class,()->controller.reschedule(auth(owner),task,new CareController.Schedule(Instant.now()))).getStatusCode().value());
  String outsider=owner(home());
  assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.get(auth(outsider),task)).getStatusCode().value());
  controller.complete(auth(owner),task,new CareController.Completion(false));
  controller.disposition(auth(owner),task,new CareController.Disposition("CANCELLED"));
  assertEquals(3,queries.recent(home,task).size());
  assertTrue(queries.dashboardTasks(home).isEmpty());
 }
 @Test void cursorHistorySurvivesConcurrentInsertAndIsPetScoped(){
  String home=home(),owner=owner(home),pet=pet(home),task=task(pet,Instant.now());
  Instant at=Instant.now();
  for(int i=0;i<65;i++)db.update("INSERT INTO care_events VALUES (?,?,?,?,?)",id(),task,owner,"COMPLETED",Timestamp.from(at.minusSeconds(i)));
  var first=queries.history(home,pet,null);
  assertEquals(30,((List<?>)first.get("items")).size());
  db.update("INSERT INTO care_events VALUES (?,?,?,?,?)",id(),task,owner,"REOPENED",Timestamp.from(at.plusSeconds(1)));
  Set<Object> seen=new HashSet<>();
  for(var row:(List<Map<String,Object>>)first.get("items"))assertTrue(seen.add(row.get("id")));
  var second=queries.history(home,pet,(String)first.get("nextCursor"));
  for(var row:(List<Map<String,Object>>)second.get("items"))assertTrue(seen.add(row.get("id")));
  var third=queries.history(home,pet,(String)second.get("nextCursor"));
  for(var row:(List<Map<String,Object>>)third.get("items"))assertTrue(seen.add(row.get("id")));
  assertEquals(65,seen.size());assertEquals(false,third.get("hasMore"));
  assertTrue(((List<?>)queries.history(home,pet(home),null).get("items")).isEmpty());
  assertThrows(ResponseStatusException.class,()->queries.history(home,pet,"invalid"));
 }
 @Test void healthReminderUpdatesExistingPendingAndKeepsCompletedCare(){
  String home=home(),owner=owner(home),pet=pet(home);
  var health=new HealthRecordController(db,new HouseholdBenefits(db,10000,100000,false));
  var care=new CareController(db,plans);
  String record=health.create(auth(owner),pet,new HealthRecordController.Input("VACCINE","Annual vaccine","",LocalDate.now(),null,List.of())).get("id");
  var reminder=new HealthRecordController.Reminder(Instant.now().plusSeconds(3600));
  var first=health.reminder(auth(owner),pet,record,reminder);
  String task=(String)((Map<?,?>)first.get("task")).get("id");
  assertEquals(task,((Map<?,?>)health.reminder(auth(owner),pet,record,reminder).get("task")).get("id"));
  care.complete(auth(owner),task,new CareController.Completion(true));
  var next=health.reminder(auth(owner),pet,record,reminder);
  assertNotEquals(task,((Map<?,?>)next.get("task")).get("id"));
  assertEquals(record,queries.task(home,task).get("healthRecordId"));
  health.delete(auth(owner),pet,record);
  assertNull(queries.task(home,task).get("healthRecordId"));
  assertEquals(true,queries.task(home,task).get("completed"));
 }
}
