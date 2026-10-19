package com.petcare.care;

import com.petcare.shared.ApiSupport;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.nio.charset.StandardCharsets;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/care/overdue")
public class OverdueController extends ApiSupport {
 public OverdueController(JdbcTemplate db){super(db);}
 private record Scope(String sql,List<Object> args) {}
 private Scope scope(String home,String pet,Instant before,Instant from,Instant to,Instant asOf) {
  if(before==null || before.isAfter(Instant.now().plusSeconds(2)) || before.isBefore(Instant.parse("2000-01-01T00:00:00Z")) || (asOf!=null && asOf.isAfter(Instant.now().plusSeconds(2))))bad();
  Instant end=to!=null && to.isBefore(before)?to:before;
  if((from!=null && (!from.isBefore(end) || from.isBefore(Instant.parse("2000-01-01T00:00:00Z")))) || (to!=null && to.isBefore(Instant.parse("2000-01-01T00:00:00Z"))) || (asOf!=null && asOf.isBefore(Instant.parse("2000-01-01T00:00:00Z"))))bad();
  if(db.queryForObject("SELECT COUNT(*) FROM pets WHERE id=? AND household_id=?",Integer.class,pet,home)!=1)throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  var args=new ArrayList<Object>(List.of(home,pet,Timestamp.from(end)));
  String sql=" FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=? AND t.pet_id=? AND t.completed=FALSE AND t.cancelled=FALSE AND t.skipped=FALSE AND t.due_at<?";
  if(from!=null){sql+=" AND t.due_at>=?";args.add(Timestamp.from(from));}
  if(asOf!=null){sql+=" AND t.created_at<=?";args.add(Timestamp.from(asOf));}
  return new Scope(sql,args);
 }
 private void bad(){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_OVERDUE_FILTER");}
 @GetMapping("/groups") @Transactional
 public Map<String,Object> groups(Authentication auth,@RequestParam String petId,@RequestParam Instant before,
     @RequestParam(required=false) Instant from,@RequestParam(required=false) Instant to,
     @RequestParam(required=false) Instant asOf,@RequestParam(defaultValue="") String cursor) {
  String home=permission(auth,"READ");Instant snapshot=asOf==null?Instant.now():asOf;
  var s=scope(home,petId,before,from,to,snapshot);
  var totals=db.queryForMap("SELECT COUNT(*) total,COALESCE(SUM(t.plan_id IS NOT NULL),0) recurringTotal,COALESCE(SUM(t.plan_id IS NULL),0) singleTotal"+s.sql,s.args.toArray());
  if(!cursor.isEmpty())try{UUID.fromString(cursor);}catch(Exception e){bad();}
  var args=new ArrayList<>(s.args);args.add(cursor);
  var rows=db.query("SELECT t.plan_id,MIN(t.title) title,COUNT(*) count,MIN(t.due_at) first_at,MAX(t.due_at) last_at"+s.sql+" AND t.plan_id IS NOT NULL AND t.plan_id>? GROUP BY t.plan_id ORDER BY t.plan_id LIMIT 21",(r,n)->Map.<String,Object>of(
    "id",r.getString(1),"title",r.getString(2),"count",r.getLong(3),"firstAt",r.getTimestamp(4).toInstant().toString(),"lastAt",r.getTimestamp(5).toInstant().toString()),args.toArray());
  var result=new LinkedHashMap<String,Object>(totals);result.put("householdId",home);result.put("asOf",snapshot.toString());
  result.put("items",rows.stream().limit(20).toList());result.put("hasMore",rows.size()>20);result.put("nextCursor",rows.size()>20?rows.get(19).get("id"):"");
  return result;
 }
 @GetMapping("/items") @Transactional
 public Map<String,Object> items(Authentication auth,@RequestParam String petId,@RequestParam String groupId,@RequestParam Instant before,
     @RequestParam(required=false) Instant from,@RequestParam(required=false) Instant to,@RequestParam(required=false) Instant asOf,@RequestParam(defaultValue="") String cursor) {
  var s=scope(permission(auth,"READ"),petId,before,from,to,asOf);
  var args=new ArrayList<>(s.args);String where;
  if(groupId.equals("single"))where=" AND t.plan_id IS NULL";
  else{try{UUID.fromString(groupId);}catch(Exception e){bad();}where=" AND t.plan_id=?";args.add(groupId);}
  if(!cursor.isEmpty())try {
   var parts=new String(Base64.getUrlDecoder().decode(cursor),StandardCharsets.UTF_8).split("\\|",-1);
   if(parts.length!=2)throw new IllegalArgumentException();
   var at=Timestamp.from(Instant.parse(parts[0]));UUID.fromString(parts[1]);
   where+=" AND (t.due_at>? OR (t.due_at=? AND t.id>?))";args.add(at);args.add(at);args.add(parts[1]);
  }catch(Exception e){bad();}
  var rows=db.query("SELECT t.id,t.title,t.due_at,t.revision,t.plan_id,t.care_type,p.name,t.pet_id"+s.sql+where+" ORDER BY t.due_at,t.id LIMIT 31",(r,n)->{
   Map<String,Object> m=new LinkedHashMap<>();m.put("id",r.getString(1));m.put("title",r.getString(2));m.put("dueAt",r.getTimestamp(3).toInstant().toString());m.put("revision",r.getLong(4));m.put("planId",r.getString(5));m.put("careType",r.getString(6));m.put("petName",r.getString(7));m.put("petId",r.getString(8));m.put("completed",false);return m;
  },args.toArray());
  var visible=rows.stream().limit(30).toList();String next="";
  if(rows.size()>30){var last=visible.getLast();next=Base64.getUrlEncoder().withoutPadding().encodeToString((last.get("dueAt")+"|"+last.get("id")).getBytes(StandardCharsets.UTF_8));}
  return Map.of("items",visible,"hasMore",rows.size()>30,"nextCursor",next);
 }
 public record Ref(@NotBlank String id,@Min(0) long revision) {}
 public record Selection(@NotBlank String petId,@NotNull Instant before,Instant from,Instant to,@NotNull Instant asOf,
   boolean allRecurring,@Size(max=100) List<@NotBlank String> groupIds,@Size(max=100) List<@NotBlank String> excludedGroups,
   @Size(max=1000) List<@NotBlank String> excludedIds,@Size(max=1000) List<@Valid Ref> items) {}
 private static List<String> list(List<String> value){return value==null?List.of():value;}
 private static String marks(int n){return String.join(",",Collections.nCopies(n,"?"));}
 @PostMapping("/preview") @Transactional
 public Map<String,Object> preview(Authentication auth,@Valid @RequestBody Selection input) {
  String home=permission(auth,"CARE");var s=scope(home,input.petId,input.before,input.from,input.to,input.asOf);
  if(db.queryForObject("SELECT COUNT(*) FROM overdue_batches WHERE account_id=? AND created_at>DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE)",Integer.class,auth.getName())>=10)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
  String batch=id();db.update("INSERT INTO overdue_batches(id,account_id,household_id,pet_id,before_at,expires_at) VALUES(?,?,?,?,?,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 15 MINUTE))",batch,auth.getName(),home,input.petId,Timestamp.from(input.before));
  var groups=list(input.groupIds);var excludes=list(input.excludedGroups);var ids=list(input.excludedIds);
  if(input.allRecurring || !groups.isEmpty()) {
   String where=" AND t.plan_id IS NOT NULL";var args=new ArrayList<Object>();args.add(batch);args.addAll(s.args);
   if(!input.allRecurring){where+=" AND t.plan_id IN ("+marks(groups.size())+")";args.addAll(groups);}
   if(!excludes.isEmpty()){where+=" AND t.plan_id NOT IN ("+marks(excludes.size())+")";args.addAll(excludes);}
   if(!ids.isEmpty()){where+=" AND t.id NOT IN ("+marks(ids.size())+")";args.addAll(ids);}
   db.update("INSERT INTO overdue_batch_items(batch_id,task_id,revision) SELECT ?,t.id,t.revision"+s.sql+where+" LIMIT 5001",args.toArray());
  }
  // Individual selections (including one-off medical care) are explicit and keep
  // their observed version. Changed/deleted items still get an outcome on apply.
  for(var item:input.items==null?List.<Ref>of():input.items) {
   // A task must belong to this pet/home and be overdue at preview time.
   var args=new ArrayList<>(s.args);args.add(item.id);
   if(db.queryForObject("SELECT COUNT(*)"+s.sql+" AND t.id=?",Integer.class,args.toArray())==1)
    db.update("INSERT INTO overdue_batch_items(batch_id,task_id,revision) VALUES(?,?,?) ON DUPLICATE KEY UPDATE task_id=task_id",batch,item.id,item.revision);
  }
  int total=db.queryForObject("SELECT COUNT(*) FROM overdue_batch_items WHERE batch_id=?",Integer.class,batch);
  if(total>5000)throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"BATCH_TOO_LARGE");
  if(total==0)throw new ResponseStatusException(HttpStatus.CONFLICT,"OVERDUE_SELECTION_EMPTY");
  return stats(batch);
 }
 private Map<String,Object> stats(String batch) {
  var result=new LinkedHashMap<String,Object>(db.queryForMap("SELECT COUNT(*) total,COALESCE(SUM(status='SUCCESS'),0) success,COALESCE(SUM(status='CHANGED'),0) changed,COALESCE(SUM(status='FAILED'),0) failed,COALESCE(SUM(status='PENDING'),0) remaining FROM overdue_batch_items WHERE batch_id=?",batch));
  result.put("id",batch);String state=db.queryForObject("SELECT state FROM overdue_batches WHERE id=?",String.class,batch);result.put("state",state);result.put("finished",state.equals("COMPLETE"));return result;
 }
 @GetMapping("/batches/current") @Transactional
 public Map<String,Object> current(Authentication auth,@RequestParam String petId) {
  String home=permission(auth,"READ");var rows=db.queryForList("SELECT id FROM overdue_batches WHERE account_id=? AND household_id=? AND pet_id=? AND state IN ('RUNNING','COMPLETE') ORDER BY created_at DESC,id DESC LIMIT 1",String.class,auth.getName(),home,petId);
  return rows.isEmpty()?Map.of():stats(rows.getFirst());
 }
 @PostMapping("/batches/{batchId}/apply") @Transactional
 public Map<String,Object> apply(Authentication auth,@PathVariable String batchId) {
  String home=permission(auth,"CARE");
  var jobs=db.queryForList("SELECT * FROM overdue_batches WHERE id=? AND account_id=? AND household_id=? FOR UPDATE",batchId,auth.getName(),home);
  if(jobs.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  var job=jobs.getFirst();
  if(job.get("state").equals("PREVIEW") && ((Timestamp)job.get("expires_at")).toInstant().isBefore(Instant.now()))throw new ResponseStatusException(HttpStatus.CONFLICT,"OVERDUE_PREVIEW_EXPIRED");
  if(job.get("state").equals("COMPLETE"))return stats(batchId);
  db.update("UPDATE overdue_batches SET state='RUNNING' WHERE id=?",batchId);
  var entries=db.queryForList("SELECT task_id,revision FROM overdue_batch_items WHERE batch_id=? AND status='PENDING' ORDER BY task_id LIMIT 100 FOR UPDATE",batchId);
  for(var entry:entries) {
   String task=(String)entry.get("task_id");
   var tx=org.springframework.transaction.interceptor.TransactionAspectSupport.currentTransactionStatus();
   Object savepoint=tx.createSavepoint();String status;
   try {
    int changed=db.update("UPDATE care_tasks t JOIN pets p ON p.id=t.pet_id SET t.skipped=TRUE,t.revision=t.revision+1 WHERE t.id=? AND p.household_id=? AND t.pet_id=? AND t.revision=? AND t.completed=FALSE AND t.cancelled=FALSE AND t.skipped=FALSE AND t.due_at<?",task,home,job.get("pet_id"),entry.get("revision"),job.get("before_at"));
    if(changed==1)db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES(?,?,?,'SKIPPED',UTC_TIMESTAMP(6))",id(),task,auth.getName());
    status=changed==1?"SUCCESS":"CHANGED";
   } catch(org.springframework.dao.DataIntegrityViolationException e) {
    tx.rollbackToSavepoint(savepoint);status="FAILED";
   } finally {tx.releaseSavepoint(savepoint);}
   db.update("UPDATE overdue_batch_items SET status=? WHERE batch_id=? AND task_id=?",status,batchId,task);

  }
  if(db.queryForObject("SELECT COUNT(*) FROM overdue_batch_items WHERE batch_id=? AND status='PENDING'",Integer.class,batchId)==0)db.update("UPDATE overdue_batches SET state='COMPLETE' WHERE id=?",batchId);
  return stats(batchId);
 }
 @org.springframework.scheduling.annotation.Scheduled(cron="${petcare.overdue.cleanup-cron:0 0 * * * *}")
 @Transactional
 public void cleanup(){
  db.update("DELETE FROM overdue_batches WHERE state='PREVIEW' AND expires_at<UTC_TIMESTAMP(6)");
  db.update("DELETE FROM overdue_batches WHERE state='COMPLETE' AND created_at<DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 30 DAY)");
 }

}
