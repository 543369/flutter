package com.petcare.subjects;
import com.petcare.shared.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController @RequestMapping("/api/subjects")
public class SubjectController extends ApiSupport {
 public SubjectController(JdbcTemplate db){super(db);}
 public record Profile(@NotBlank @Size(max=60) String name,@NotBlank @Size(max=60) String relationship,@PastOrPresent LocalDate birthDate,@NotNull @Size(max=1000) String biography,
  @Pattern(regexp="SELF|REPRESENTATIVE") String consentBasis,boolean consentConfirmed,
  @Pattern(regexp="ELDER|CHILD|OTHER") String lifeStage,@Size(max=2) List<@NotNull @Pattern(regexp="DAILY|RECOVERY") String> careScenarios){
  public Profile(String name,String relationship,LocalDate birthDate,String biography,String consentBasis,boolean consentConfirmed){this(name,relationship,birthDate,biography,consentBasis,consentConfirmed,null,null);}
 }
 @PostMapping @Transactional
 public Map<String,String> create(Authentication auth,@Valid @RequestBody Profile input){
  String home=permission(auth,"PETS");consent(input.consentBasis,input.consentConfirmed);String subject=id();
  db.update("INSERT INTO pets(id,household_id,name,species,subject_type,relationship,subject_owner,birth_date,biography,consent_basis,consent_at) VALUES(?,?,?,'other','HUMAN',?,?,?,?,?,UTC_TIMESTAMP(6))",subject,home,input.name.strip(),input.relationship.strip(),auth.getName(),input.birthDate,input.biography,input.consentBasis);
  settings(subject,input,"OTHER","DAILY");audit(subject,auth,"CONSENT_GRANTED",input.consentBasis);return Map.of("id",subject);
 }
 @PatchMapping("/{subjectId}") @Transactional
 public Map<String,String> update(Authentication auth,@PathVariable String subjectId,@Valid @RequestBody Profile input){
  permission(auth,"READ");var row=SubjectAccess.require(db,auth,subjectId,"MANAGE");human(row);
  if(row.get("consent_revoked_at")!=null)throw new ResponseStatusException(HttpStatus.FORBIDDEN,"SUBJECT_CONSENT_REVOKED");
  db.update("UPDATE pets SET name=?,relationship=?,birth_date=?,biography=? WHERE id=?",input.name.strip(),input.relationship.strip(),input.birthDate,input.biography,subjectId);settings(subjectId,input,(String)row.get("life_stage"),(String)row.get("care_scenarios"));invalidate((String)row.get("household_id"));return Map.of("id",subjectId);
 }
 public record Consent(@Pattern(regexp="SELF|REPRESENTATIVE") String basis,Boolean confirmed,boolean revoke){}
 @PostMapping("/{subjectId}/consent") @Transactional
 public Map<String,Boolean> consent(Authentication auth,@PathVariable String subjectId,@Valid @RequestBody Consent input){
  permission(auth,"READ");var row=SubjectAccess.require(db,auth,subjectId,"MANAGE");human(row);
  if(input.revoke){db.update("UPDATE pets SET consent_revoked_at=UTC_TIMESTAMP(6) WHERE id=?",subjectId);db.update("DELETE FROM subject_grants WHERE subject_id=?",subjectId);}
  else{consent(input.basis,Boolean.TRUE.equals(input.confirmed));db.update("UPDATE pets SET consent_basis=?,consent_at=UTC_TIMESTAMP(6),consent_revoked_at=NULL WHERE id=?",input.basis,subjectId);}
  audit(subjectId,auth,input.revoke?"CONSENT_REVOKED":"CONSENT_GRANTED",input.basis);invalidate((String)row.get("household_id"));return Map.of("active",!input.revoke);
 }
 @GetMapping("/{subjectId}/access") @Transactional
 public Map<String,Object> access(Authentication auth,@PathVariable String subjectId){
  String home=permission(auth,"READ");var row=SubjectAccess.require(db,auth,subjectId,"MANAGE");human(row);
  var members=db.queryForList("SELECT a.id,a.display_name name,COALESCE(g.access_level,'NONE') accessLevel FROM accounts a LEFT JOIN subject_grants g ON g.account_id=a.id AND g.subject_id=? WHERE a.household_id=? AND a.id<>? AND (a.access_until IS NULL OR a.access_until>UTC_TIMESTAMP(6)) ORDER BY a.display_name,a.id",subjectId,home,auth.getName());
  return Map.of("members",members,"consentActive",row.get("consent_revoked_at")==null,"basis",row.get("consent_basis"),"events",db.queryForList("SELECT action,basis,happened_at FROM subject_consent_events WHERE subject_id=? ORDER BY happened_at DESC,id DESC LIMIT 20",subjectId));
 }
 public record Grant(@NotBlank @Pattern(regexp="READ|CARE|NONE") String level){}
 @PutMapping("/{subjectId}/access/{memberId}") @Transactional
 public Map<String,String> grant(Authentication auth,@PathVariable String subjectId,@PathVariable String memberId,@Valid @RequestBody Grant input){
  String home=permission(auth,"READ");var row=SubjectAccess.require(db,auth,subjectId,"MANAGE");human(row);
  if(row.get("consent_revoked_at")!=null)throw new ResponseStatusException(HttpStatus.CONFLICT,"SUBJECT_CONSENT_REVOKED");
  if(auth.getName().equals(memberId) || db.queryForObject("SELECT COUNT(*) FROM accounts WHERE id=? AND household_id=? AND (access_until IS NULL OR access_until>UTC_TIMESTAMP(6))",Integer.class,memberId,home)!=1)throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  if(input.level.equals("NONE"))db.update("DELETE FROM subject_grants WHERE subject_id=? AND account_id=?",subjectId,memberId);
  else db.update("INSERT INTO subject_grants(subject_id,account_id,access_level) VALUES(?,?,?) ON DUPLICATE KEY UPDATE access_level=VALUES(access_level)",subjectId,memberId,input.level);
  audit(subjectId,auth,"ACCESS_"+input.level,null);invalidate(home);return Map.of("level",input.level);
 }
 private void consent(String basis,boolean confirmed){if(!confirmed || basis==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"SUBJECT_CONSENT_REQUIRED");}
 private void human(Map<String,Object> row){if(!row.get("subject_type").equals("HUMAN"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);}
 private void audit(String subject,Authentication auth,String action,String basis){db.update("INSERT INTO subject_consent_events(id,subject_id,actor_id,action,basis) VALUES(?,?,?,?,?)",id(),subject,auth.getName(),action,basis);}
 private void invalidate(String home){db.update("INSERT INTO push_outbox(household_id) VALUES(?) ON DUPLICATE KEY UPDATE revision=revision+1,updated_at=UTC_TIMESTAMP(6)",home);}
 private void settings(String subject,Profile input,String oldStage,String oldScenarios){
  String stage=input.lifeStage==null?oldStage:input.lifeStage;
  if(!Set.of("ELDER","CHILD","OTHER").contains(stage))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_SUBJECT_SCENARIO");
  String scenarios=oldScenarios;
  if(input.careScenarios!=null){
   var selected=new HashSet<>(input.careScenarios);
   if(selected.isEmpty() || selected.size()!=input.careScenarios.size() || !Set.of("DAILY","RECOVERY").containsAll(selected))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"INVALID_SUBJECT_SCENARIO");
   scenarios=List.of("DAILY","RECOVERY").stream().filter(selected::contains).collect(java.util.stream.Collectors.joining(","));
  }
  db.update("UPDATE pets SET life_stage=?,care_scenarios=? WHERE id=?",stage,scenarios,subject);
 }
}
