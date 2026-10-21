package com.petcare.subjects;
import com.petcare.shared.*;
import com.petcare.auth.Tokens;
import com.petcare.care.CareQueries;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.sql.Timestamp;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController @RequestMapping("/api/tasks/{taskId}/medication")
public class MedicationController extends ApiSupport {
 public MedicationController(JdbcTemplate db){super(db);}
 public record Log(@NotBlank @Pattern(regexp="[a-fA-F0-9-]{36}") String requestId,@Min(0) long revision,
  @NotBlank @Pattern(regexp="TAKEN|NOT_TAKEN|REFUSED|HELD") String outcome,@NotNull Instant actualAt,
  @NotBlank @Size(max=120) String medication,@NotBlank @Size(max=120) String dose,@NotNull @Size(max=1000) String notes){}
 @GetMapping @Transactional
 public Map<String,Object> list(Authentication auth,@PathVariable String taskId){
  permission(auth,"HEALTH");SubjectAccess.task(db,auth,taskId,"READ");
  var rows=db.query("SELECT id,outcome,actual_at,medication,dose,notes,created_at FROM medication_logs WHERE task_id=? ORDER BY created_at DESC,id DESC LIMIT 50",(r,n)->Map.<String,Object>of("id",r.getString(1),"outcome",r.getString(2),"actualAt",r.getTimestamp(3).toInstant().toString(),"medication",r.getString(4),"dose",r.getString(5),"notes",r.getString(6),"createdAt",r.getTimestamp(7).toInstant().toString()),taskId);
  return Map.of("items",rows);
 }
 @PostMapping @Transactional
 public Map<String,Object> log(Authentication auth,@PathVariable String taskId,@Valid @RequestBody Log input){
  String home=permission(auth,"CARE");permission(auth,"HEALTH");SubjectAccess.task(db,auth,taskId,"CARE");
  if(input.actualAt.isAfter(Instant.now().plusSeconds(60)) || input.actualAt.isBefore(Instant.parse("2000-01-01T00:00:00Z")))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var actual=input.actualAt.truncatedTo(ChronoUnit.MICROS);
  String hash=Tokens.hash(new tools.jackson.databind.ObjectMapper().writeValueAsString(List.of(taskId,auth.getName(),input.revision,input.outcome,actual.toString(),input.medication,input.dose,input.notes)));
  var old=db.queryForList("SELECT request_hash FROM medication_logs WHERE request_id=?",input.requestId);
  if(!old.isEmpty()){
   if(!hash.equals(old.getFirst().get("request_hash")))throw new ResponseStatusException(HttpStatus.CONFLICT,"OPERATION_REUSED");
   return new CareQueries(db).mutation(home,taskId);
  }
  var task=db.queryForMap("SELECT * FROM care_tasks WHERE id=? FOR UPDATE",taskId);
  if(!task.get("care_type").equals("MEDICATION"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  if(((Number)task.get("revision")).longValue()!=input.revision || Boolean.TRUE.equals(task.get("completed")) || Boolean.TRUE.equals(task.get("skipped")) || Boolean.TRUE.equals(task.get("cancelled")))throw new ResponseStatusException(HttpStatus.CONFLICT,"SYNC_CONFLICT");
  db.update("INSERT INTO medication_logs(id,task_id,actor_id,request_id,request_hash,outcome,actual_at,medication,dose,notes) VALUES(?,?,?,?,?,?,?,?,?,?)",id(),taskId,auth.getName(),input.requestId,hash,input.outcome,Timestamp.from(actual),input.medication.strip(),input.dose.strip(),input.notes.strip());
  boolean taken=input.outcome.equals("TAKEN");
  db.update("UPDATE care_tasks SET revision=revision+1,completed=?,skipped=? WHERE id=?",taken,!taken,taskId);
  db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES(?,?,?,?,?)",id(),taskId,auth.getName(),"MED_"+input.outcome,Timestamp.from(actual));
  return new CareQueries(db).mutation(home,taskId);
 }
}
