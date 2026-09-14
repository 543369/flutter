package com.petcare.benefits;

import com.petcare.shared.ApiSupport;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/benefits")
class BenefitsController extends ApiSupport {
 private final HouseholdBenefits benefits;
 BenefitsController(JdbcTemplate db,HouseholdBenefits benefits) {super(db);this.benefits=benefits;}
 @GetMapping @Transactional
 Map<String,Object> status(Authentication auth) {return benefits.status(household(auth));}

 @GetMapping("/memories/{petId}") @Transactional
 Map<String,Object> export(Authentication auth,@PathVariable String petId,@RequestParam(defaultValue="0") int offset) {
  String home=household(auth); benefits.requireExtended(home);
  if(offset<0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  if(db.queryForObject("SELECT COUNT(*) FROM pets WHERE id=? AND household_id=?",Integer.class,petId,home)!=1)
   throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  // Small pages bound memory and HTTP payloads even with six photos per story.
  var items=db.query("SELECT m.*,a.display_name FROM pet_memories m LEFT JOIN accounts a ON a.id=m.author_id WHERE m.pet_id=? ORDER BY m.happened_on,m.created_at,m.id LIMIT 3 OFFSET ?",(r,n)->{
   Map<String,Object> item=new LinkedHashMap<>();
   item.put("id",r.getString("id")); item.put("title",r.getString("title")); item.put("story",r.getString("story"));
   item.put("happenedOn",r.getDate("happened_on").toString()); item.put("createdAt",r.getTimestamp("created_at").toInstant().toString());
   item.put("author",r.getString("display_name")); return item;
  },petId,offset);
  for(var item:items) item.put("photos",db.queryForList("SELECT photo_data FROM pet_memory_photos WHERE memory_id=? ORDER BY position_index",String.class,item.get("id")));
  int total=db.queryForObject("SELECT COUNT(*) FROM pet_memories WHERE pet_id=?",Integer.class,petId);
  return Map.of("items",items,"total",total,"hasMore",offset+items.size()<total);
 }

 @GetMapping("/annual") @Transactional
 Map<String,Object> annual(Authentication auth,@RequestParam int year,@RequestParam(defaultValue="Asia/Shanghai") String zoneId) {
  String home=household(auth); benefits.requireExtended(home);
  ZoneId zone;
  try {zone=ZoneId.of(zoneId);} catch(DateTimeException e) {throw new ResponseStatusException(HttpStatus.BAD_REQUEST);}
  if(year<1900 || year>LocalDate.now(zone).getYear()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  Instant start=LocalDate.of(year,1,1).atStartOfDay(zone).toInstant();
  Instant end=LocalDate.of(year+1,1,1).atStartOfDay(zone).toInstant();
  var pets=db.query("SELECT id,name,species,birth_date FROM pets WHERE household_id=? ORDER BY name,id",(r,n)->{
   Map<String,Object> p=new LinkedHashMap<>();p.put("id",r.getString(1));p.put("name",r.getString(2));p.put("species",r.getString(3));
   p.put("birthDate",r.getDate(4)==null?null:r.getDate(4).toString()); p.put("careCount",0);p.put("memoryCount",0); return p;
  },home);
  var byPet=new HashMap<String,Map<String,Object>>();for(var p:pets)byPet.put((String)p.get("id"),p);
  int[] monthlyCare=new int[12],monthlyMemories=new int[12];
  Map<String,Integer> types=new TreeMap<>(); Set<String> caregivers=new HashSet<>(); Set<LocalDate> activeDays=new HashSet<>();
  // As-of-year-end state: completed/reopened/recompleted counts only once per task.
  var events=db.queryForList("SELECT * FROM (SELECT t.pet_id,t.care_type,e.action,e.actor_id,e.happened_at,ROW_NUMBER() OVER(PARTITION BY e.task_id ORDER BY e.happened_at DESC,e.id DESC) rn FROM care_events e JOIN care_tasks t ON t.id=e.task_id JOIN pets p ON p.id=t.pet_id WHERE p.household_id=? AND e.happened_at<?) ranked WHERE rn=1 AND action='COMPLETED' AND happened_at>=?",home,Timestamp.from(end),Timestamp.from(start));
  for(var event:events) {
   LocalDate day=((Timestamp)event.get("happened_at")).toInstant().atZone(zone).toLocalDate();
   monthlyCare[day.getMonthValue()-1]++;activeDays.add(day);
   if(event.get("actor_id")!=null)caregivers.add((String)event.get("actor_id"));
   types.merge((String)event.get("care_type"),1,Integer::sum);
   var p=byPet.get(event.get("pet_id"));p.put("careCount",(int)p.get("careCount")+1);
  }
  var memories=db.query("SELECT pet_id,happened_on FROM pet_memories m JOIN pets p ON p.id=m.pet_id WHERE p.household_id=? AND happened_on>=? AND happened_on<?",(r,n)->Map.of("petId",r.getString(1),"date",r.getDate(2).toLocalDate()),home,LocalDate.of(year,1,1),LocalDate.of(year+1,1,1));
  for(var memory:memories) {
   monthlyMemories[((LocalDate)memory.get("date")).getMonthValue()-1]++;
   var p=byPet.get(memory.get("petId"));p.put("memoryCount",(int)p.get("memoryCount")+1);
  }
  var result=new LinkedHashMap<String,Object>();result.put("year",year);result.put("zoneId",zoneId);
  result.put("generatedAt",Instant.now().toString());result.put("careCount",events.size());result.put("memoryCount",memories.size());
  result.put("activeDays",activeDays.size());result.put("caregiverCount",caregivers.size());result.put("monthlyCare",monthlyCare);
  result.put("monthlyMemories",monthlyMemories);result.put("careTypes",types);result.put("pets",pets);
  return result;
 }
}
