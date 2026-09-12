package com.petcare.dashboard;

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
class DashboardController extends ApiSupport {
 private final CarePlans plans;
 DashboardController(JdbcTemplate db, CarePlans plans) { super(db); this.plans=plans; }

 @GetMapping("/dashboard") @Transactional
 Map<String,Object> dashboard(Authentication auth) {
  String home = household(auth);
  var pets = db.query("SELECT id,name,species,photo_data,biography,birth_date,created_at FROM pets WHERE household_id = ? ORDER BY name,id", (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("id",r.getString(1)); row.put("name",r.getString(2)); row.put("species",r.getString(3));
   row.put("photoData",r.getString(4)); row.put("biography",r.getString(5));
   row.put("birthDate",r.getDate(6)==null?null:r.getDate(6).toLocalDate().toString());
   row.put("createdAt",r.getTimestamp(7)==null?null:r.getTimestamp(7).toInstant().toString()); return row;
  }, home);
  plans.materialize(home);
  var tasks = db.query("SELECT t.id,t.pet_id,t.title,t.due_at,t.completed,p.name,t.plan_id,t.care_type FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=? AND t.cancelled=FALSE ORDER BY t.completed,t.due_at,t.id", (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("id",r.getString(1)); row.put("petId",r.getString(2)); row.put("title",r.getString(3));
   row.put("dueAt",r.getTimestamp(4).toInstant().toString()); row.put("completed",r.getBoolean(5));
   row.put("petName",r.getString(6)); row.put("planId",r.getString(7)); row.put("careType",r.getString(8)); return row;
  }, home);
  var history = db.query("SELECT e.id,e.task_id,e.action,e.happened_at,a.display_name,t.title,p.name,p.id,t.care_type FROM care_events e JOIN care_tasks t ON t.id=e.task_id JOIN pets p ON p.id=t.pet_id LEFT JOIN accounts a ON a.id=e.actor_id WHERE p.household_id=? ORDER BY e.happened_at DESC,e.id DESC LIMIT 100", (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("id",r.getString(1)); row.put("taskId",r.getString(2)); row.put("action",r.getString(3));
   row.put("at",r.getTimestamp(4).toInstant().toString()); row.put("actor",r.getString(5));
   row.put("title",r.getString(6)); row.put("petName",r.getString(7)); row.put("petId",r.getString(8)); row.put("careType",r.getString(9)); return row;
  }, home);
  var recurring = db.queryForList("SELECT c.id,c.title,c.frequency,c.zone_id AS zoneId,c.active,c.care_type AS careType,p.name AS petName,p.id AS petId FROM care_plans c JOIN pets p ON p.id=c.pet_id WHERE p.household_id=? ORDER BY c.active DESC,c.title,c.id",home);
  return Map.of("registered",db.queryForObject("SELECT (email IS NOT NULL OR apple_subject IS NOT NULL) FROM accounts WHERE id=?",Boolean.class,auth.getName()),"pets",pets,"tasks",tasks,"history",history,"plans",recurring,
   "me",db.queryForObject("SELECT display_name FROM accounts WHERE id=?",String.class,auth.getName()),
   "members",db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?", Integer.class, home));
 }

}
