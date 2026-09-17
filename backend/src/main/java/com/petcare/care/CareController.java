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
 private final CareQueries queries;
 CareController(JdbcTemplate db, CarePlans plans) { super(db); this.plans=plans; this.queries=new CareQueries(db); }
 record TaskInput(@NotBlank String petId, @NotBlank @Size(max=120) String title, @NotNull Instant dueAt, @Pattern(regexp="NONE|DAILY|WEEKLY") String frequency, @Size(max=80) String zoneId,
                  @Pattern(regexp="FEEDING|WATER|DEWORMING|VACCINE|WALK|GROOMING|CUSTOM") String careType) {}
 record Completion(@NotNull Boolean completed) {}
 @PostMapping("/tasks") @ResponseStatus(HttpStatus.CREATED) @Transactional
 Map<String,String> addTask(Authentication auth, @Valid @RequestBody TaskInput input) {
  String home=permission(auth,"CARE"), task=id();
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
 Map<String,Object> complete(Authentication auth, @PathVariable String taskId, @Valid @RequestBody Completion input) {
  String home = permission(auth,"CARE");
  var states = db.queryForList("SELECT t.completed FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE t.id=? AND p.household_id=? AND t.cancelled=FALSE AND t.skipped=FALSE FOR UPDATE",Boolean.class,taskId,home);
  if (states.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  if (!states.getFirst().equals(input.completed())) {
   db.update("UPDATE care_tasks SET completed=? WHERE id=?",input.completed(),taskId);
   db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,?)",id(),taskId,auth.getName(),input.completed()?"COMPLETED":"REOPENED",Timestamp.from(Instant.now()));
  }
  var result=task(home,taskId);
  result.put("reminderTasks",CareReminders.list(db,home));
  return result;
 }

 private Map<String,Object> task(String home,String taskId) {
  var rows=db.query("SELECT t.id,t.pet_id,t.title,t.due_at,t.completed,p.name,t.plan_id,t.care_type,t.assigned_to,t.cancelled FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE t.id=? AND p.household_id=?",(r,n)-> {
   Map<String,Object> row=new LinkedHashMap<>();
   row.put("id",r.getString(1));row.put("petId",r.getString(2));row.put("title",r.getString(3));row.put("dueAt",r.getTimestamp(4).toInstant().toString());row.put("completed",r.getBoolean(5));row.put("petName",r.getString(6));row.put("planId",r.getString(7));row.put("careType",r.getString(8));row.put("assignedTo",r.getString(9));row.put("cancelled",r.getBoolean(10));return row;
  },taskId,home);
  if(rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  var row=rows.getFirst();
  var events=db.query("SELECT e.id,e.action,e.happened_at,a.display_name FROM care_events e LEFT JOIN accounts a ON a.id=e.actor_id WHERE e.task_id=? ORDER BY e.happened_at DESC,e.id DESC LIMIT 1",(r,n)-> {
   Map<String,Object> e=new LinkedHashMap<>();e.put("id",r.getString(1));e.put("action",r.getString(2));e.put("at",r.getTimestamp(3).toInstant().toString());e.put("actor",r.getString(4));return e;
  },taskId);
  if(!events.isEmpty()) row.put("lastEvent",events.getFirst());
  return row;
 }
 @GetMapping("/tasks/{taskId}") @Transactional
 Map<String,Object> getTask(Authentication auth,@PathVariable String taskId) {
  return task(permission(auth,"READ"),taskId);
 }
 record Adjustment(@NotNull Instant dueAt) {}
 @PatchMapping("/tasks/{taskId}/time") @Transactional
 Map<String,Object> reschedule(Authentication auth,@PathVariable String taskId,@Valid @RequestBody Adjustment input) {
  String home=permission(auth,"CARE");
  if(input.dueAt().isBefore(Instant.now()) || input.dueAt().isAfter(Instant.parse("2037-12-31T23:59:59Z"))) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var old=task(home,taskId);
  if(Boolean.TRUE.equals(old.get("completed")) || Boolean.TRUE.equals(old.get("cancelled"))) throw new ResponseStatusException(HttpStatus.CONFLICT,"TASK_NOT_PENDING");
  String next=taskId;
  if(old.get("planId")!=null) {
   // Keep the original occurrence as a tombstone so materialize cannot recreate it.
   db.update("UPDATE care_tasks SET cancelled=TRUE WHERE id=?",taskId);
   next=id();
   db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,care_type,assigned_to) VALUES (?,?,?,?,?,?)",next,old.get("petId"),old.get("title"),Timestamp.from(input.dueAt()),old.get("careType"),old.get("assignedTo"));
  } else db.update("UPDATE care_tasks SET due_at=? WHERE id=?",Timestamp.from(input.dueAt()),taskId);
  db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,?)",id(),taskId,auth.getName(),"RESCHEDULED",Timestamp.from(Instant.now()));
  return task(home,next);
 }
 record Dismissal(@NotBlank @Pattern(regexp="SKIPPED|CANCELLED") String action) {}
 @PostMapping("/tasks/{taskId}/dismiss") @Transactional
 Map<String,Object> dismiss(Authentication auth,@PathVariable String taskId,@Valid @RequestBody Dismissal input) {
  String home=permission(auth,"CARE");var old=task(home,taskId);
  if(Boolean.TRUE.equals(old.get("completed"))) throw new ResponseStatusException(HttpStatus.CONFLICT,"TASK_NOT_PENDING");
  if(!Boolean.TRUE.equals(old.get("cancelled"))) {
   db.update("UPDATE care_tasks SET cancelled=TRUE WHERE id=?",taskId);
   db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,?)",id(),taskId,auth.getName(),input.action(),Timestamp.from(Instant.now()));
  }
  return task(home,taskId);
 }
 record PlanAdjustment(@NotNull Instant dueAt,@NotBlank @Pattern(regexp="DAILY|WEEKLY") String frequency,@NotBlank String zoneId) {}
 @PatchMapping("/plans/{planId}/future") @Transactional
 Map<String,String> adjustPlan(Authentication auth,@PathVariable String planId,@Valid @RequestBody PlanAdjustment input) {
  String home=permission(auth,"CARE");
  if(!input.dueAt().isAfter(Instant.now())) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var rows=db.queryForList("SELECT c.* FROM care_plans c JOIN pets p ON p.id=c.pet_id WHERE c.id=? AND p.household_id=? AND c.active=TRUE",planId,home);
  if(rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  var old=rows.getFirst();
  // New plan identity preserves old history and occurrence uniqueness.
  var result=addTask(auth,new TaskInput((String)old.get("pet_id"),(String)old.get("title"),input.dueAt(),input.frequency(),input.zoneId(),(String)old.get("care_type")));
  stopPlan(auth,planId);
  return result;
 }
 record Assignment(String memberId) {}
 @PatchMapping("/tasks/{taskId}/assignment") @Transactional
 Map<String,Object> assign(Authentication auth,@PathVariable String taskId,@RequestBody Assignment input) {
  String home=permission(auth,"CARE");
  if(input.memberId()!=null && db.queryForObject("SELECT COUNT(*) FROM accounts WHERE id=? AND household_id=? AND (access_until IS NULL OR access_until>CURRENT_TIMESTAMP(6)) AND (family_role='ADMIN' OR FIND_IN_SET('CARE',permissions)>0)",Integer.class,input.memberId(),home)!=1)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_ASSIGNEE");
  require(db.update("UPDATE care_tasks t JOIN pets p ON p.id=t.pet_id SET t.assigned_to=? WHERE t.id=? AND p.household_id=? AND t.cancelled=FALSE",input.memberId(),taskId,home));
  return queries.mutation(home,taskId);
 }
 @GetMapping("/tasks/{taskId}") @Transactional
 Map<String,Object> get(Authentication auth,@PathVariable String taskId) {return queries.mutation(permission(auth,"READ"),taskId);}
 @GetMapping("/tasks") @Transactional
 Map<String,Object> list(Authentication auth,@RequestParam String petId,@RequestParam(defaultValue="pending") String state,@RequestParam(defaultValue="0") int offset) {return queries.tasks(permission(auth,"READ"),petId,state,offset);}
 @GetMapping("/care/history") @Transactional
 Map<String,Object> history(Authentication auth,@RequestParam(required=false) String petId,@RequestParam(required=false) String cursor) {return queries.history(permission(auth,"READ"),petId,cursor);}
 record Schedule(@NotNull Instant dueAt) {}
 @PatchMapping("/tasks/{taskId}/schedule") @Transactional
 Map<String,Object> reschedule(Authentication auth,@PathVariable String taskId,@Valid @RequestBody Schedule input) {
  String home=permission(auth,"CARE");var task=queries.task(home,taskId);editable(task);
  if(input.dueAt().isBefore(Instant.parse("2000-01-01T00:00:00Z"))||input.dueAt().isAfter(Instant.parse("2037-12-31T23:59:59Z")))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  if(!Instant.parse((String)task.get("dueAt")).equals(input.dueAt())) {
   db.update("UPDATE care_tasks SET due_at=? WHERE id=?",Timestamp.from(input.dueAt()),taskId);event(auth,taskId,"RESCHEDULED");
  }
  return queries.mutation(home,taskId);
 }
 record Disposition(@NotBlank @Pattern(regexp="CANCELLED|SKIPPED") String action) {}
 @PatchMapping("/tasks/{taskId}/disposition") @Transactional
 Map<String,Object> disposition(Authentication auth,@PathVariable String taskId,@Valid @RequestBody Disposition input) {
  String home=permission(auth,"CARE");var task=queries.task(home,taskId);
  boolean skip=input.action().equals("SKIPPED");
  if(Boolean.TRUE.equals(task.get(skip?"skipped":"cancelled")))return queries.mutation(home,taskId);
  editable(task);if(skip && task.get("planId")==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"RECURRING_REQUIRED");
  db.update("UPDATE care_tasks SET cancelled=?,skipped=? WHERE id=?",!skip,skip,taskId);event(auth,taskId,input.action());return queries.mutation(home,taskId);
 }
 private void editable(Map<String,Object> task) {
  if(Boolean.TRUE.equals(task.get("completed"))||Boolean.TRUE.equals(task.get("cancelled"))||Boolean.TRUE.equals(task.get("skipped")))throw new ResponseStatusException(HttpStatus.CONFLICT,"TASK_NOT_PENDING");
 }
 private void event(Authentication auth,String task,String action) {db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,?)",id(),task,auth.getName(),action,Timestamp.from(Instant.now()));}
 @DeleteMapping("/plans/{planId}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void stopPlan(Authentication auth, @PathVariable String planId) {
  String home = permission(auth,"CARE");
  require(db.update("UPDATE care_plans c JOIN pets p ON p.id=c.pet_id SET c.active=FALSE WHERE c.id=? AND p.household_id=?",planId,home));
  // Preserve overdue occurrences and all completed care/history.
  db.update("UPDATE care_tasks SET cancelled=TRUE WHERE plan_id=? AND completed=FALSE AND due_at>?",planId,Timestamp.from(Instant.now()));
 }

}
