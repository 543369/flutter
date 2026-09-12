package com.petcare.care;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import com.petcare.shared.ApiSupport;
import com.petcare.care.CarePlans;
import com.petcare.auth.Tokens;

@RestController
@RequestMapping("/api")
class CareController extends ApiSupport {
 private final CarePlans plans;
 CareController(JdbcTemplate db, CarePlans plans) { super(db); this.plans=plans; }
 record TaskInput(@NotBlank String petId, @NotBlank @Size(max=120) String title, @NotNull Instant dueAt, @Pattern(regexp="NONE|DAILY|WEEKLY") String frequency, @Size(max=80) String zoneId,
                  @Pattern(regexp="FEEDING|DEWORMING|VACCINE|WALK|GROOMING|CUSTOM") String careType) {}
 record Completion(@NotNull Boolean completed) {}
 @PostMapping("/tasks") @ResponseStatus(HttpStatus.CREATED) @Transactional
 Map<String,String> addTask(Authentication auth, @Valid @RequestBody TaskInput input) {
  String home=household(auth), task=id();
  if (input.dueAt().isBefore(Instant.parse("2000-01-01T00:00:00Z")) || input.dueAt().isAfter(Instant.parse("2037-12-31T23:59:59Z")))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  String frequency = input.frequency() == null ? "NONE" : input.frequency();
  String careType = input.careType() == null ? "CUSTOM" : input.careType();
  if (!frequency.equals("NONE")) {
   if (input.dueAt().isBefore(Instant.now().minusSeconds(86400)) || input.dueAt().isAfter(Instant.now().plusSeconds(29*86400)))
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
   try { java.time.ZoneId.of(input.zoneId()); }
   catch (Exception e) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST); }
   String plan = id();
   require(db.update("INSERT INTO care_plans(id,pet_id,title,frequency,zone_id,starts_at,care_type) SELECT ?,id,?,?,?,?,? FROM pets WHERE id=? AND household_id=?",
    plan,input.title().strip(),frequency,input.zoneId(),Timestamp.from(input.dueAt()),careType,input.petId(),home));
   plans.materialize(home);
   String first = db.queryForObject("SELECT id FROM care_tasks WHERE plan_id=? ORDER BY due_at LIMIT 1",String.class,plan);
   return Map.of("id",first,"planId",plan);
  }
  require(db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,care_type) SELECT ?,id,?,?,? FROM pets WHERE id=? AND household_id=?",task,input.title().strip(),Timestamp.from(input.dueAt()),careType,input.petId(),home));
  return Map.of("id",task);
 }
 @PatchMapping("/tasks/{taskId}") @Transactional
 Map<String,Boolean> complete(Authentication auth, @PathVariable String taskId, @Valid @RequestBody Completion input) {
  String home = household(auth);
  var states = db.queryForList("SELECT t.completed FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE t.id=? AND p.household_id=? AND t.cancelled=FALSE FOR UPDATE",Boolean.class,taskId,home);
  if (states.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  if (!states.getFirst().equals(input.completed())) {
   db.update("UPDATE care_tasks SET completed=? WHERE id=?",input.completed(),taskId);
   db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,?)",id(),taskId,auth.getName(),input.completed()?"COMPLETED":"REOPENED",Timestamp.from(Instant.now()));
  }
  return Map.of("completed",input.completed());
 }
 @DeleteMapping("/plans/{planId}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void stopPlan(Authentication auth, @PathVariable String planId) {
  String home = household(auth);
  require(db.update("UPDATE care_plans c JOIN pets p ON p.id=c.pet_id SET c.active=FALSE WHERE c.id=? AND p.household_id=?",planId,home));
  // Preserve overdue occurrences and all completed care/history.
  db.update("UPDATE care_tasks SET cancelled=TRUE WHERE plan_id=? AND completed=FALSE AND due_at>?",planId,Timestamp.from(Instant.now()));
 }

}
