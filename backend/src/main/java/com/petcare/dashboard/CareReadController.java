package com.petcare.dashboard;
import java.util.*;
import java.time.Instant;
import java.sql.Timestamp;
import java.nio.charset.StandardCharsets;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import com.petcare.shared.ApiSupport;
@RestController @RequestMapping("/api")
class CareReadController extends ApiSupport {
 CareReadController(JdbcTemplate db){super(db);}
 @GetMapping("/tasks") @Transactional
 Map<String,Object> tasks(Authentication auth,@RequestParam(required=false) String petId,@RequestParam(required=false) String cursor) {
  var after=decode(cursor);
  String home=permission(auth,"READ");
  var items = db.query("SELECT t.id,t.pet_id,t.title,t.due_at,t.completed,p.name,t.plan_id,t.care_type,t.assigned_to,t.created_at FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=? AND t.cancelled=FALSE AND t.skipped=FALSE AND (? IS NULL OR t.pet_id=?) AND (? IS NULL OR t.created_at<? OR (t.created_at=? AND t.id<?)) ORDER BY t.created_at DESC,t.id DESC LIMIT 51", (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("id",r.getString(1)); row.put("petId",r.getString(2)); row.put("title",r.getString(3));
   row.put("dueAt",r.getTimestamp(4).toInstant().toString()); row.put("completed",r.getBoolean(5));
   row.put("petName",r.getString(6)); row.put("planId",r.getString(7)); row.put("careType",r.getString(8)); row.put("assignedTo",r.getString(9)); row.put("createdAt",r.getTimestamp(10).toInstant().toString()); return row;
  }, home,petId,petId,after.time(),after.time(),after.time(),after.id());
  return page(items,"createdAt");
 }
 @GetMapping("/care-history") @Transactional
 Map<String,Object> care_history(Authentication auth,@RequestParam(required=false) String petId,@RequestParam(required=false) String cursor) {
  var after=decode(cursor);
  String home=permission(auth,"READ");
  var items = db.query("SELECT e.id,e.task_id,e.action,e.happened_at,a.display_name,t.title,p.name,p.id,t.care_type FROM care_events e JOIN care_tasks t ON t.id=e.task_id JOIN pets p ON p.id=t.pet_id LEFT JOIN accounts a ON a.id=e.actor_id WHERE p.household_id=? AND (? IS NULL OR p.id=?) AND (? IS NULL OR e.happened_at<? OR (e.happened_at=? AND e.id<?)) ORDER BY e.happened_at DESC,e.id DESC LIMIT 51", (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("id",r.getString(1)); row.put("taskId",r.getString(2)); row.put("action",r.getString(3));
   row.put("at",r.getTimestamp(4).toInstant().toString()); row.put("actor",r.getString(5));
   row.put("title",r.getString(6)); row.put("petName",r.getString(7)); row.put("petId",r.getString(8)); row.put("careType",r.getString(9)); return row;
  }, home,petId,petId,after.time(),after.time(),after.time(),after.id());
  return page(items,"at");
 }
 private record Cursor(Timestamp time,String id) {}
 private Cursor decode(String cursor) {
  if(cursor==null || cursor.isEmpty()) return new Cursor(null,"");
  try {
   if(cursor.length()>200) throw new IllegalArgumentException();
   String[] parts=new String(Base64.getUrlDecoder().decode(cursor),StandardCharsets.UTF_8).split("\\|",-1);
   if(parts.length!=2) throw new IllegalArgumentException();
   UUID.fromString(parts[1]);
   return new Cursor(Timestamp.from(Instant.parse(parts[0])),parts[1]);
  } catch(Exception e) {throw new ResponseStatusException(HttpStatus.BAD_REQUEST);}
 }
 private Map<String,Object> page(List<Map<String,Object>> rows,String timeKey) {
  var items=rows.stream().limit(50).toList();
  String cursor="";
  if(rows.size()>50) {
   var last=items.getLast();
   cursor=Base64.getUrlEncoder().withoutPadding().encodeToString((last.get(timeKey)+"|"+last.get("id")).getBytes(StandardCharsets.UTF_8));
  }
  return Map.of("items",items,"hasMore",rows.size()>50,"nextCursor",cursor);
 }
}
