package com.petcare.family;
import com.petcare.shared.ApiSupport;
import com.petcare.benefits.HouseholdBenefits;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
@RestController @RequestMapping("/api/family/weekly")
public class WeeklyReportController extends ApiSupport {
 private final HouseholdBenefits benefits;
 public WeeklyReportController(JdbcTemplate db,HouseholdBenefits benefits){super(db);this.benefits=benefits;}
 private List<Map<String,Object>> tasks(String home,Instant start,Instant end){
  return db.queryForList("SELECT t.id,t.pet_id,p.name pet_name,t.title,t.due_at,t.assigned_to,(SELECT e.action FROM care_events e WHERE e.task_id=t.id AND e.happened_at<? ORDER BY e.happened_at DESC,e.id DESC LIMIT 1) action,(SELECT e.actor_id FROM care_events e WHERE e.task_id=t.id AND e.happened_at<? ORDER BY e.happened_at DESC,e.id DESC LIMIT 1) actor FROM care_tasks t JOIN pets p ON p.id=t.pet_id WHERE p.household_id=? AND t.cancelled=FALSE AND t.due_at>=? AND t.due_at<? ORDER BY t.due_at,t.id",Timestamp.from(end),Timestamp.from(end),home,Timestamp.from(start),Timestamp.from(end));
 }
 private Map<String,Object> count(String name){var m=new LinkedHashMap<String,Object>();m.put("name",name);m.put("due",0);m.put("completed",0);m.put("missed",0);return m;}
 private void increment(Map<String,Object> row,String key){row.put(key,((Number)row.getOrDefault(key,0)).intValue()+1);}
 @GetMapping @Transactional
 public Map<String,Object> report(Authentication auth,@RequestParam(required=false) LocalDate start,@RequestParam(defaultValue="Asia/Shanghai") String zoneId,@RequestParam(defaultValue="false") boolean trends){
  String home=permission(auth,"REPORTS");ZoneId zone;
  try{zone=ZoneId.of(zoneId);}catch(Exception e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST);}
  LocalDate today=LocalDate.now(zone);LocalDate week=today.minusDays(today.getDayOfWeek().getValue()-1);
  if(start==null)start=week;
  if(start.getDayOfWeek()!=DayOfWeek.MONDAY||start.isAfter(week)||start.isBefore(LocalDate.of(2000,1,1)))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  if(trends||!start.equals(week))benefits.requireExtended(home);
  Instant end=start.plusDays(7).atStartOfDay(zone).toInstant();if(end.isAfter(Instant.now()))end=Instant.now();
  var rows=tasks(home,start.atStartOfDay(zone).toInstant(),end);
  var pets=new LinkedHashMap<String,Map<String,Object>>();
  db.query("SELECT id,name FROM pets WHERE household_id=? ORDER BY name,id",rs->{pets.put(rs.getString(1),count(rs.getString(2)));},home);
  var members=new LinkedHashMap<String,Map<String,Object>>();
  db.query("SELECT id,display_name FROM accounts WHERE household_id=? ORDER BY display_name,id",rs->{var m=count(rs.getString(2));m.put("assigned",0);members.put(rs.getString(1),m);},home);
  List<Map<String,Object>> missed=new ArrayList<>();int completed=0,unassigned=0;
  for(var task:rows){
   boolean done="COMPLETED".equals(task.get("action"));var pet=pets.get(task.get("pet_id"));increment(pet,"due");increment(pet,done?"completed":"missed");
   if(task.get("assigned_to")==null)unassigned++;else if(members.containsKey(task.get("assigned_to")))increment(members.get(task.get("assigned_to")),"assigned");
   if(done){completed++;String actor=(String)task.get("actor");if(!members.containsKey(actor)){var former=count("已离开的家人");former.put("assigned",0);members.put(actor,former);}increment(members.get(actor),"completed");}
   else if(missed.size()<50)missed.add(Map.of("id",task.get("id"),"title",task.get("title"),"petName",task.get("pet_name"),"dueAt",((Timestamp)task.get("due_at")).toInstant().toString()));
  }
  List<Map<String,Object>> history=new ArrayList<>();
  if(trends)for(int i=7;i>=0;i--){
   LocalDate from=start.minusWeeks(i);Instant until=from.plusDays(7).atStartOfDay(zone).toInstant();if(until.isAfter(Instant.now()))until=Instant.now();
   var period=tasks(home,from.atStartOfDay(zone).toInstant(),until);Map<String,Map<String,Object>> split=new LinkedHashMap<>();
   for(var entry:pets.entrySet())split.put(entry.getKey(),count((String)entry.getValue().get("name")));
   int done=0;for(var task:period){var pet=split.get(task.get("pet_id"));increment(pet,"due");if("COMPLETED".equals(task.get("action"))){done++;increment(pet,"completed");}}
   history.add(Map.of("start",from.toString(),"due",period.size(),"completed",done,"pets",split.values()));
  }
  Map<String,Object> result=new LinkedHashMap<>();result.put("start",start.toString());result.put("end",start.plusDays(6).toString());result.put("zoneId",zoneId);result.put("asOf",end.toString());
  result.put("due",rows.size());result.put("completed",completed);result.put("missed",rows.size()-completed);result.put("completionRate",rows.isEmpty()?null:100.0*completed/rows.size());result.put("unassigned",unassigned);
  result.put("pets",pets.values());result.put("members",members.values());result.put("missedTasks",missed);result.put("trends",history);result.put("advanced",benefits.access(home).extended());return result;
 }
}
