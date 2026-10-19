package com.petcare.care;

import com.petcare.shared.ApiSupport;
import com.petcare.auth.Tokens;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.ObjectMapper;

/** Versioned, replay-safe mutations. Never silently overwrite another device. */
@RestController @RequestMapping("/api/care/sync")
public class CareSyncController extends ApiSupport {
 private final CareQueries queries;
 private final ObjectMapper json;
 public CareSyncController(JdbcTemplate db,CareQueries queries,ObjectMapper json){super(db);this.queries=queries;this.json=json;}
 public record Operation(
  @NotBlank @Pattern(regexp="[a-fA-F0-9-]{36}") String operationId,
  @NotBlank String householdId,@NotBlank String taskId,@Min(0) long revision,
  @Pattern(regexp="[a-fA-F0-9-]{36}") String dependsOn,
  @NotBlank @Pattern(regexp="COMPLETE|REOPEN|RESCHEDULE|ASSIGN|SKIP|CANCEL|EDIT") String action,
  Instant dueAt,@Size(max=36) String memberId,@Size(min=1,max=120) String title,
  @Pattern(regexp="FEEDING|WATER|DEWORMING|VACCINE|WALK|GROOMING|CUSTOM") String careType) {}
 @PostMapping @Transactional
 public Map<String,Object> apply(Authentication auth,@Valid @RequestBody Operation op) {
  String home=permission(auth,"CARE");
  if(!home.equals(op.householdId()))throw new ResponseStatusException(HttpStatus.CONFLICT,"HOUSEHOLD_CHANGED");
  String hash=Tokens.hash(json.writeValueAsString(op));
  var receipts=db.queryForList("SELECT * FROM care_sync_receipts WHERE account_id=? AND operation_id=?",auth.getName(),op.operationId());
  if(!receipts.isEmpty()) {
   if(!hash.equals(receipts.getFirst().get("request_hash")))throw new ResponseStatusException(HttpStatus.CONFLICT,"OPERATION_REUSED");
   return result(home,op.taskId());
  }
  var task=queries.task(home,op.taskId());
  long expected=op.revision();
  if(op.dependsOn()!=null) {
   var parent=db.queryForList("SELECT revision FROM care_sync_receipts WHERE account_id=? AND operation_id=? AND household_id=? AND task_id=?",auth.getName(),op.dependsOn(),home,op.taskId());
   if(parent.isEmpty())throw new ResponseStatusException(HttpStatus.CONFLICT,"DEPENDENCY_MISSING");
   expected=((Number)parent.getFirst().get("revision")).longValue();
  }
  long actual=((Number)task.get("revision")).longValue();
  // A concurrent completion may already satisfy the same intention. Reopening,
  // editing, skipping and rescheduling always require the exact prior revision.
  boolean satisfied=op.action().equals("COMPLETE") && Boolean.TRUE.equals(task.get("completed"))
    && !Boolean.TRUE.equals(task.get("cancelled")) && !Boolean.TRUE.equals(task.get("skipped"));
  if(actual!=expected && !satisfied)throw new ResponseStatusException(HttpStatus.CONFLICT,"SYNC_CONFLICT");
  if(!satisfied) {
   if(Boolean.TRUE.equals(task.get("cancelled")) || Boolean.TRUE.equals(task.get("skipped")))throw new ResponseStatusException(HttpStatus.CONFLICT,"TASK_NOT_PENDING");
   if(!Set.of("REOPEN","COMPLETE").contains(op.action()) && Boolean.TRUE.equals(task.get("completed")))throw new ResponseStatusException(HttpStatus.CONFLICT,"TASK_NOT_PENDING");
   String event=op.action();
   switch(op.action()) {
    case "COMPLETE","REOPEN" -> {
     boolean done=op.action().equals("COMPLETE");
     if(Boolean.valueOf(done).equals(task.get("completed")))event=null;
     else db.update("UPDATE care_tasks SET revision=revision+1,completed=? WHERE id=?",done,op.taskId());
     if(event!=null)event=done?"COMPLETED":"REOPENED";
    }
    case "RESCHEDULE" -> {
     if(op.dueAt()==null || op.dueAt().isBefore(Instant.now()) || op.dueAt().isAfter(Instant.parse("2037-12-31T23:59:59Z")))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_CARE_TIME");
     db.update("UPDATE care_tasks SET revision=revision+1,due_at=? WHERE id=?",Timestamp.from(op.dueAt()),op.taskId());event="RESCHEDULED";
    }
    case "ASSIGN" -> {
     if(op.memberId()!=null && db.queryForObject("SELECT COUNT(*) FROM accounts WHERE id=? AND household_id=? AND (access_until IS NULL OR access_until>UTC_TIMESTAMP(6)) AND (family_role='ADMIN' OR FIND_IN_SET('CARE',permissions)>0)",Integer.class,op.memberId(),home)!=1)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_ASSIGNEE");
     db.update("UPDATE care_tasks SET revision=revision+1,assigned_to=? WHERE id=?",op.memberId(),op.taskId());event=null;
    }
    case "SKIP","CANCEL" -> {
     db.update("UPDATE care_tasks SET revision=revision+1,skipped=?,cancelled=? WHERE id=?",op.action().equals("SKIP"),op.action().equals("CANCEL"),op.taskId());event=op.action().equals("SKIP")?"SKIPPED":"CANCELLED";
    }
    case "EDIT" -> {
     if(op.title()==null || op.title().isBlank())throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
     db.update("UPDATE care_tasks SET revision=revision+1,title=?,care_type=COALESCE(?,care_type) WHERE id=?",op.title().strip(),op.careType(),op.taskId());event=null;
    }
   }
   if(event!=null)db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES(?,?,?,?,UTC_TIMESTAMP(6))",id(),op.taskId(),auth.getName(),event);
  }
  long revision=((Number)queries.task(home,op.taskId()).get("revision")).longValue();
  db.update("INSERT INTO care_sync_receipts(account_id,operation_id,household_id,task_id,request_hash,revision) VALUES(?,?,?,?,?,?)",auth.getName(),op.operationId(),home,op.taskId(),hash,revision);
  return result(home,op.taskId());
 }
 private Map<String,Object> result(String home,String task) {
  var result=new LinkedHashMap<>(queries.mutation(home,task));
  result.put("reminderTasks",CareReminders.list(db,home));return result;
 }
}
