package com.petcare.health;
import com.petcare.shared.ApiSupport;
import com.petcare.benefits.HouseholdBenefits;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.math.BigDecimal;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
@RestController @RequestMapping("/api/pets/{petId}/health")
public class HealthRecordController extends ApiSupport {
 private final HouseholdBenefits benefits;
 public HealthRecordController(JdbcTemplate db,HouseholdBenefits benefits){super(db);this.benefits=benefits;}
 public record Input(@NotBlank @Pattern(regexp="VACCINE|DEWORMING|MEDICATION|ALLERGY|WEIGHT|VISIT") String kind,
  @NotBlank @Size(max=120) String title,@NotNull @Size(max=5000) String notes,
  @NotNull @PastOrPresent LocalDate happenedOn,@DecimalMin("0.001") @DecimalMax("9999") BigDecimal weightKg,
  @NotNull @Size(max=12) List<@NotBlank @Size(max=1500000) String> photos) {}
 private String pet(Authentication auth,String pet) {
  String home=permission(auth,"HEALTH");
  if(db.queryForObject("SELECT COUNT(*) FROM pets WHERE id=? AND household_id=?",Integer.class,pet,home)!=1) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  return home;
 }
 private Map<String,Object> row(java.sql.ResultSet r,int n)throws java.sql.SQLException {
  Map<String,Object> m=new LinkedHashMap<>();
  for(String k:List.of("id","kind","title","notes","folder"))m.put(k,r.getString(k));
  m.put("happenedOn",r.getDate("happened_on").toString());m.put("weightKg",r.getBigDecimal("weight_kg"));
  m.put("createdAt",r.getTimestamp("created_at").toInstant().toString());m.put("updatedAt",r.getTimestamp("updated_at").toInstant().toString());return m;
 }
 @GetMapping @Transactional
 public Map<String,Object> list(Authentication auth,@PathVariable String petId,@RequestParam(defaultValue="0") int offset,@RequestParam(defaultValue="") String kind) {
  String home=pet(auth,petId);if(offset<0)throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var items=db.query("SELECT * FROM health_records WHERE pet_id=? AND (?='' OR kind=?) ORDER BY happened_on DESC,created_at DESC,id LIMIT 20 OFFSET ?",this::row,petId,kind,kind,offset);
  int total=db.queryForObject("SELECT COUNT(*) FROM health_records WHERE pet_id=? AND (?='' OR kind=?)",Integer.class,petId,kind,kind);
  return Map.of("items",items,"total",total,"hasMore",offset+items.size()<total,"advanced",benefits.access(home).extended(),"attachmentLimit",benefits.access(home).extended()?12:2);
 }
 @GetMapping("/timeline") @Transactional
 public Map<String,Object> timeline(Authentication auth,@PathVariable String petId,
   @RequestParam(required=false) LocalDate from,@RequestParam(required=false) LocalDate to) {
  pet(auth,petId);permission(auth,"REPORTS");
  if(from!=null && to!=null && from.isAfter(to))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var records=db.query("SELECT h.*,(SELECT COUNT(*) FROM health_attachments f WHERE f.record_id=h.id) attachment_count FROM health_records h WHERE pet_id=? AND (? IS NULL OR happened_on>=?) AND (? IS NULL OR happened_on<=?) ORDER BY happened_on,created_at,id",(r,n)->{
   var item=row(r,n);item.put("attachmentCount",r.getInt("attachment_count"));return item;
  },petId,from,from,to,to);
  var pet=db.queryForObject("SELECT id,name,species,birth_date FROM pets WHERE id=?",(r,n)->{
   Map<String,Object> value=new LinkedHashMap<>();value.put("id",r.getString(1));value.put("name",r.getString(2));value.put("species",r.getString(3));value.put("birthDate",r.getDate(4)==null?null:r.getDate(4).toString());return value;
  },petId);
  return Map.of("pet",pet,"items",records,"generatedAt",java.time.Instant.now().toString());
 }
 @GetMapping("/{recordId}") @Transactional
 public Map<String,Object> get(Authentication auth,@PathVariable String petId,@PathVariable String recordId) {
  pet(auth,petId);var rows=db.query("SELECT * FROM health_records WHERE id=? AND pet_id=?",this::row,recordId,petId);
  if(rows.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  var result=rows.getFirst();result.put("photos",db.queryForList("SELECT photo_data FROM health_attachments WHERE record_id=? ORDER BY position_index",String.class,recordId));result.put("careReminders",db.queryForList("SELECT id,due_at AS dueAt,completed,cancelled,skipped FROM care_tasks WHERE health_record_id=? ORDER BY due_at DESC LIMIT 10",recordId));return result;
 }
 private void photos(String home,String id,List<String> photos) {
  int old=db.queryForObject("SELECT COUNT(*) FROM health_attachments WHERE record_id=?",Integer.class,id);
  if(photos.size()>Math.max(old,benefits.access(home).extended()?12:2))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"BENEFIT_UNAVAILABLE");
  for(String photo:photos)try {if(Base64.getDecoder().decode(photo).length==0)throw new IllegalArgumentException();}catch(IllegalArgumentException e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST);}
  db.update("DELETE FROM health_attachments WHERE record_id=?",id);
  for(int i=0;i<photos.size();i++)db.update("INSERT INTO health_attachments VALUES (?,?,?)",id,i,photos.get(i));
 }
 private void validate(Input input) {
  if(input.kind().equals("WEIGHT")&&input.weightKg()==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"WEIGHT_REQUIRED");
  if(!input.kind().equals("WEIGHT")&&input.weightKg()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
 }
 @PostMapping @ResponseStatus(HttpStatus.CREATED) @Transactional
 public Map<String,String> create(Authentication auth,@PathVariable String petId,@Valid @RequestBody Input input){
  String home=pet(auth,petId);validate(input);long before=benefits.usedBytes(home);String id=id();
  db.update("INSERT INTO health_records(id,pet_id,author_id,kind,title,notes,happened_on,weight_kg) VALUES (?,?,?,?,?,?,?,?)",id,petId,auth.getName(),input.kind(),input.title().strip(),input.notes(),input.happenedOn(),input.weightKg());
  photos(home,id,input.photos());benefits.checkGrowth(home,before);return Map.of("id",id);
 }
 @PatchMapping("/{recordId}") @Transactional
 public Map<String,String> update(Authentication auth,@PathVariable String petId,@PathVariable String recordId,@Valid @RequestBody Input input){
  String home=pet(auth,petId);validate(input);long before=benefits.usedBytes(home);
  require(db.update("UPDATE health_records SET kind=?,title=?,notes=?,happened_on=?,weight_kg=?,updated_at=CURRENT_TIMESTAMP(6) WHERE id=? AND pet_id=?",input.kind(),input.title().strip(),input.notes(),input.happenedOn(),input.weightKg(),recordId,petId));
  photos(home,recordId,input.photos());benefits.checkGrowth(home,before);return Map.of("id",recordId);
 }
 @DeleteMapping("/{recordId}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 public void delete(Authentication auth,@PathVariable String petId,@PathVariable String recordId){pet(auth,petId);require(db.update("DELETE FROM health_records WHERE id=? AND pet_id=?",recordId,petId));}
 public record Reminder(@NotNull java.time.Instant dueAt) {}
 @PostMapping("/{recordId}/reminder") @Transactional
 public Map<String,Object> reminder(Authentication auth,@PathVariable String petId,@PathVariable String recordId,@Valid @RequestBody Reminder input) {
  String home=pet(auth,petId);permission(auth,"CARE");
  var records=db.queryForList("SELECT title,kind FROM health_records WHERE id=? AND pet_id=?",recordId,petId);
  if(records.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  if(!input.dueAt().isAfter(java.time.Instant.now())||input.dueAt().isAfter(java.time.Instant.parse("2037-12-31T23:59:59Z")))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var pending=db.queryForList("SELECT id FROM care_tasks WHERE health_record_id=? AND completed=FALSE AND cancelled=FALSE AND skipped=FALSE ORDER BY due_at,id LIMIT 1",String.class,recordId);
  String task=pending.isEmpty()?id():pending.getFirst();
  if(pending.isEmpty()) {
   String kind=(String)records.getFirst().get("kind");if(!Set.of("VACCINE","DEWORMING").contains(kind))kind="CUSTOM";
   db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,care_type,health_record_id) VALUES (?,?,?,?,?,?)",task,petId,records.getFirst().get("title"),java.sql.Timestamp.from(input.dueAt()),kind,recordId);
  }else {
   var old=db.queryForObject("SELECT due_at FROM care_tasks WHERE id=?",java.sql.Timestamp.class,task);
   if(!old.toInstant().equals(input.dueAt())) {
    db.update("UPDATE care_tasks SET due_at=? WHERE id=?",java.sql.Timestamp.from(input.dueAt()),task);
    db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,CURRENT_TIMESTAMP(6))",id(),task,auth.getName(),"RESCHEDULED");
   }
  }
  return new com.petcare.care.CareQueries(db).mutation(home,task);
 }
 public record Batch(@NotEmpty @Size(max=100) List<@NotBlank String> ids,@NotNull @Size(max=60) String folder){}
 @PostMapping("/organize") @Transactional
 public Map<String,Integer> organize(Authentication auth,@PathVariable String petId,@Valid @RequestBody Batch input){
  benefits.requireExtended(pet(auth,petId));int count=0;
  for(String id:new LinkedHashSet<>(input.ids())) {require(db.update("UPDATE health_records SET folder=?,updated_at=CURRENT_TIMESTAMP(6) WHERE id=? AND pet_id=?",input.folder().strip(),id,petId));count++;}
  return Map.of("updated",count);
 }
 @GetMapping("/trend") @Transactional
 public Map<String,Object> trend(Authentication auth,@PathVariable String petId){
  benefits.requireExtended(pet(auth,petId));
  var items=db.query("SELECT DATE_FORMAT(happened_on,'%Y-%m') month,AVG(weight_kg) weight,MIN(weight_kg) minimum,MAX(weight_kg) maximum,COUNT(*) count FROM health_records WHERE pet_id=? AND kind='WEIGHT' GROUP BY month ORDER BY month",(r,n)->Map.of("month",r.getString(1),"weightKg",r.getBigDecimal(2),"minKg",r.getBigDecimal(3),"maxKg",r.getBigDecimal(4),"count",r.getInt(5)),petId);
  return Map.of("items",items,"method","MONTHLY_MEAN");
 }
}
