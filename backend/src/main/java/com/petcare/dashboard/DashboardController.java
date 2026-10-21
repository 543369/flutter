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

 Map<String,Object> dashboard(Authentication auth,boolean compact){return dashboard(auth,compact,null);}
 @GetMapping("/dashboard") @Transactional
 Map<String,Object> dashboard(Authentication auth, @RequestParam(defaultValue="false") boolean compact,@RequestParam(required=false) Instant overdueBefore) {
  String home = permission(auth,"READ");
  Map<String,List<String>> photoGallery = new HashMap<>();
  if(!compact) db.query("SELECT f.pet_id,f.photo_data FROM pet_photos f JOIN pets p ON p.id=f.pet_id WHERE p.household_id=?"+com.petcare.shared.SubjectAccess.and("p")+" ORDER BY f.pet_id,f.position_index", r -> {
   photoGallery.computeIfAbsent(r.getString(1), ignored -> new ArrayList<>()).add(r.getString(2));
  }, home);
  var subjectGrants=new HashMap<String,String>();db.query("SELECT subject_id,access_level FROM subject_grants WHERE account_id=?",r->{subjectGrants.put(r.getString(1),r.getString(2));},auth.getName());
  var pets = db.query("SELECT id,name,species,"+(compact ? "NULL" : "photo_data")+",biography,birth_date,created_at,(SELECT COUNT(*) FROM pet_memories m WHERE m.pet_id=pets.id) AS memory_count, photo_revision AS photo_version,subject_type,relationship,life_stage,care_scenarios,subject_owner,consent_basis,consent_revoked_at FROM pets WHERE household_id = ?"+com.petcare.shared.SubjectAccess.and("pets")+" ORDER BY name,id", (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("subjectType",r.getString("subject_type"));row.put("lifeStage",r.getString("life_stage"));row.put("careScenarios",Arrays.asList(r.getString("care_scenarios").split(",")));row.put("relationship",r.getString("relationship"));row.put("canManageSubject",auth.getName().equals(r.getString("subject_owner")) || r.getString("subject_type").equals("PET"));row.put("consentActive",r.getTimestamp("consent_revoked_at")==null);row.put("canCareSubject",r.getString("subject_type").equals("PET") || (r.getTimestamp("consent_revoked_at")==null && (auth.getName().equals(r.getString("subject_owner")) || "CARE".equals(subjectGrants.get(r.getString(1))))));row.put("id",r.getString(1)); row.put("name",r.getString(2)); row.put("species",r.getString(3));
   if(!compact){row.put("photoData",r.getString(4)); row.put("photos",photoGallery.getOrDefault(r.getString(1),List.of()));} row.put("photoRevision",r.getLong(9)); row.put("biography",r.getString(5));
   row.put("birthDate",r.getDate(6)==null?null:r.getDate(6).toLocalDate().toString());
   row.put("createdAt",r.getTimestamp(7)==null?null:r.getTimestamp(7).toInstant().toString()); row.put("memoryCount",r.getInt(8)); row.put("photoVersion",r.getString(9)); return row;
  }, home);
  plans.materialize(home);
  if(overdueBefore!=null && (overdueBefore.isAfter(Instant.now().plusSeconds(2)) || overdueBefore.isBefore(Instant.parse("2000-01-01T00:00:00Z"))))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  Object[] taskArgs=overdueBefore==null?new Object[]{home}:new Object[]{home,Timestamp.from(overdueBefore)};
  var tasks = db.query("SELECT t.id,t.pet_id,t.title,t.due_at,t.completed,p.name,t.plan_id,t.care_type,t.assigned_to,t.skipped,t.health_record_id,(SELECT MAX(e.happened_at) FROM care_events e WHERE e.task_id=t.id AND e.action IN ('COMPLETED','MED_TAKEN')) completed_at,t.revision FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=?"+com.petcare.shared.SubjectAccess.and("p")+" AND t.cancelled=FALSE AND t.skipped=FALSE ORDER BY t.completed,"+(overdueBefore==null?"":"(t.due_at<?),")+"t.due_at,t.id"+(compact ? " LIMIT 301" : ""), (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("id",r.getString(1)); row.put("petId",r.getString(2)); row.put("title",r.getString(3));
   row.put("dueAt",r.getTimestamp(4).toInstant().toString()); row.put("completed",r.getBoolean(5));
   row.put("petName",r.getString(6)); row.put("planId",r.getString(7)); row.put("careType",r.getString(8)); row.put("assignedTo",r.getString(9)); row.put("skipped",r.getBoolean(10)); row.put("healthRecordId",r.getString(11)); row.put("revision",r.getLong(13)); row.put("completedAt",r.getTimestamp(12)==null?null:r.getTimestamp(12).toInstant().toString()); return row;
  }, taskArgs);
  var history = db.query("SELECT e.id,e.task_id,e.action,e.happened_at,a.display_name,t.title,p.name,p.id,t.care_type FROM care_events e JOIN care_tasks t ON t.id=e.task_id JOIN pets p ON p.id=t.pet_id LEFT JOIN accounts a ON a.id=e.actor_id WHERE p.household_id=?"+com.petcare.shared.SubjectAccess.and("p")+" ORDER BY e.happened_at DESC,e.id DESC LIMIT "+(compact ? 30 : 100), (r,n) -> {
   Map<String,Object> row = new LinkedHashMap<>();
   row.put("id",r.getString(1)); row.put("taskId",r.getString(2)); row.put("action",r.getString(3));
   row.put("at",r.getTimestamp(4).toInstant().toString()); row.put("actor",r.getString(5));
   row.put("title",r.getString(6)); row.put("petName",r.getString(7)); row.put("petId",r.getString(8)); row.put("careType",r.getString(9)); return row;
  }, home);
  var recurring = db.queryForList("SELECT c.id,c.title,c.frequency,c.zone_id AS zoneId,c.active,c.care_type AS careType,p.name AS petName,p.id AS petId FROM care_plans c JOIN pets p ON p.id=c.pet_id WHERE p.household_id=?"+com.petcare.shared.SubjectAccess.and("p")+" ORDER BY c.active DESC,c.title,c.id",home);
  var memberProfiles=db.query("SELECT id,display_name,avatar_data FROM accounts WHERE household_id=? ORDER BY display_name,id",(r,n)->{
   Map<String,Object> row=new LinkedHashMap<>();row.put("id",r.getString(1));row.put("name",r.getString(2));row.put("isMe",r.getString(1).equals(auth.getName()));row.put("avatarData",r.getString(3));return row;
  },home);
  var access=db.queryForMap("SELECT family_role AS role,permissions FROM accounts WHERE id=?",auth.getName());
  Map<String,Object> result = new LinkedHashMap<>(Map.of("access",access,"memberProfiles",memberProfiles,"registered",db.queryForObject("SELECT (email IS NOT NULL OR apple_subject IS NOT NULL) FROM accounts WHERE id=?",Boolean.class,auth.getName()),"pets",pets,"tasks",compact ? tasks.stream().limit(300).toList() : tasks,"history",history,"plans",recurring,
   "me",db.queryForObject("SELECT display_name FROM accounts WHERE id=?",String.class,auth.getName()),
   "members",db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?", Integer.class, home)));
  result.put("subjects",pets);result.put("householdId",home);
  result.put("accountId",auth.getName());
  result.put("reminderTasks",com.petcare.care.CareReminders.list(db,home));
  if(overdueBefore!=null) {
   var counts=db.query("SELECT t.pet_id,COUNT(*),COALESCE(SUM(t.plan_id IS NULL OR t.care_type='MEDICATION'),0) FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=?"+com.petcare.shared.SubjectAccess.and("p")+" AND t.completed=FALSE AND t.cancelled=FALSE AND t.skipped=FALSE AND t.due_at<? GROUP BY t.pet_id",(r,n)->Map.<String,Object>of("petId",r.getString(1),"count",r.getLong(2),"singleCount",r.getLong(3)),home,Timestamp.from(overdueBefore));
   result.put("overdueSummary",counts);
  }
  result.put("tasksTruncated",compact && tasks.size()>300);
  return result;
 }

}
