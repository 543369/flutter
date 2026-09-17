package com.petcare.care;

import java.sql.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CareQueries {
 private final JdbcTemplate db;
 public CareQueries(JdbcTemplate db) { this.db=db; }
 private static final String TASKS="SELECT t.*,p.name pet_name,(SELECT MAX(e.happened_at) FROM care_events e WHERE e.task_id=t.id AND e.action='COMPLETED') completed_at FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=?";
 private Map<String,Object> taskRow(ResultSet r,int n) throws SQLException {
  Map<String,Object> m=new LinkedHashMap<>();
  m.put("id",r.getString("id"));m.put("petId",r.getString("pet_id"));m.put("petName",r.getString("pet_name"));
  m.put("title",r.getString("title"));m.put("dueAt",r.getTimestamp("due_at").toInstant().toString());
  m.put("completedAt",r.getTimestamp("completed_at")==null?null:r.getTimestamp("completed_at").toInstant().toString());m.put("completed",r.getBoolean("completed"));m.put("cancelled",r.getBoolean("cancelled"));m.put("skipped",r.getBoolean("skipped"));
  m.put("planId",r.getString("plan_id"));m.put("careType",r.getString("care_type"));m.put("assignedTo",r.getString("assigned_to"));m.put("healthRecordId",r.getString("health_record_id"));return m;
 }
 public Map<String,Object> task(String home,String id) {
  var rows=db.query(TASKS+" AND t.id=?",this::taskRow,home,id);
  if(rows.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND);return rows.getFirst();
 }
 public List<Map<String,Object>> dashboardTasks(String home) {
  return db.query(TASKS+" AND t.cancelled=FALSE AND t.skipped=FALSE AND (t.completed=FALSE OR t.due_at>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 32 DAY) OR EXISTS(SELECT 1 FROM care_events e WHERE e.task_id=t.id AND e.action='COMPLETED' AND e.happened_at>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 DAY))) ORDER BY t.due_at,t.id",this::taskRow,home);
 }
 public Map<String,Object> tasks(String home,String pet,String state,int offset) {
  if(offset<0 || !Set.of("pending","completed","inactive","all").contains(state))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  String condition=switch(state){case "pending"->" AND t.completed=FALSE AND t.cancelled=FALSE AND t.skipped=FALSE";case "completed"->" AND t.completed=TRUE";case "inactive"->" AND (t.cancelled=TRUE OR t.skipped=TRUE)";default->"";};
  var rows=db.query(TASKS+" AND t.pet_id=?"+condition+" ORDER BY t.due_at,t.id LIMIT 31 OFFSET ?",this::taskRow,home,pet,offset);
  boolean more=rows.size()>30;return Map.of("items",rows.subList(0,Math.min(30,rows.size())),"hasMore",more);
 }
 private static final String EVENTS="SELECT e.id,e.task_id,e.action,e.happened_at,a.display_name,t.title,p.name,p.id,t.care_type FROM care_events e JOIN care_tasks t ON t.id=e.task_id JOIN pets p ON p.id=t.pet_id LEFT JOIN accounts a ON a.id=e.actor_id WHERE p.household_id=?";
 private Map<String,Object> eventRow(ResultSet r,int n)throws SQLException {
  Map<String,Object> m=new LinkedHashMap<>();m.put("id",r.getString(1));m.put("taskId",r.getString(2));m.put("action",r.getString(3));m.put("at",r.getTimestamp(4).toInstant().toString());m.put("actor",r.getString(5));m.put("title",r.getString(6));m.put("petName",r.getString(7));m.put("petId",r.getString(8));m.put("careType",r.getString(9));return m;
 }
 public List<Map<String,Object>> recent(String home,String task) {
  return db.query(EVENTS+" AND e.task_id=? ORDER BY e.happened_at DESC,e.id DESC LIMIT 30",this::eventRow,home,task);
 }
 public Map<String,Object> history(String home,String pet,String cursor) {
  List<Object> args=new ArrayList<>();args.add(home);String where="";
  if(pet!=null && !pet.isBlank()){where+=" AND p.id=?";args.add(pet);}
  if(cursor!=null && !cursor.isBlank()) {
   try {
    String[] parts=new String(Base64.getUrlDecoder().decode(cursor),java.nio.charset.StandardCharsets.UTF_8).split("\\|",2);
    var at=Timestamp.from(java.time.Instant.parse(parts[0]));String id=UUID.fromString(parts[1]).toString();
    where+=" AND (e.happened_at<? OR (e.happened_at=? AND e.id<?))";args.add(at);args.add(at);args.add(id);
   }catch(Exception e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST);}
  }
  var rows=db.query(EVENTS+where+" ORDER BY e.happened_at DESC,e.id DESC LIMIT 31",this::eventRow,args.toArray());
  boolean more=rows.size()>30;var items=rows.subList(0,Math.min(30,rows.size()));String next="";
  if(more){var last=items.getLast();next=Base64.getUrlEncoder().withoutPadding().encodeToString((last.get("at")+"|"+last.get("id")).getBytes(java.nio.charset.StandardCharsets.UTF_8));}
  return Map.of("items",items,"hasMore",more,"nextCursor",next);
 }
 public List<Map<String,Object>> homeHistory(String home) {
  return db.query("SELECT id,task_id,action,happened_at,display_name,title,pet_name,pet_id,care_type FROM (SELECT e.id,e.task_id,e.action,e.happened_at,a.display_name,t.title,p.name pet_name,p.id pet_id,t.care_type,ROW_NUMBER() OVER(PARTITION BY p.id ORDER BY e.happened_at DESC,e.id DESC) rn FROM care_events e JOIN care_tasks t ON t.id=e.task_id JOIN pets p ON p.id=t.pet_id LEFT JOIN accounts a ON a.id=e.actor_id WHERE p.household_id=?) recent WHERE rn<=2 ORDER BY happened_at DESC,id DESC",this::eventRow,home);
 }
 public Map<String,Object> mutation(String home,String id) {return Map.of("task",task(home,id),"events",recent(home,id));}
}
