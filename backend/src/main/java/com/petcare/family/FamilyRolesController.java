package com.petcare.family;
import com.petcare.shared.ApiSupport;
import com.petcare.benefits.HouseholdBenefits;
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
@RestController @RequestMapping("/api/family")
public class FamilyRolesController extends ApiSupport {
 private final HouseholdBenefits benefits;
 public FamilyRolesController(JdbcTemplate db,HouseholdBenefits benefits){super(db);this.benefits=benefits;}
 @GetMapping("/members") @Transactional
 public Map<String,Object> members(Authentication auth){
  String home=permission(auth,"READ");
  var rows=db.query("SELECT id,display_name,family_role,permissions,access_until FROM accounts WHERE household_id=? ORDER BY display_name,id",(r,n)->{
   Map<String,Object> row=new LinkedHashMap<>();row.put("id",r.getString(1));row.put("name",r.getString(2));row.put("role",r.getString(3));row.put("permissions",r.getString(4).isEmpty()?List.of():Arrays.asList(r.getString(4).split(",")));row.put("expiresAt",r.getTimestamp(5)==null?null:r.getTimestamp(5).toInstant().toString());row.put("isMe",auth.getName().equals(r.getString(1)));return row;
  },home);
  boolean admin=rows.stream().anyMatch(r->Boolean.TRUE.equals(r.get("isMe"))&&"ADMIN".equals(r.get("role")));
  return Map.of("items",rows,"canManage",admin,"advanced",benefits.access(home).extended());
 }
 public record RoleInput(@NotBlank String role,@Size(max=5) List<String> permissions,Instant expiresAt){}
 @PatchMapping("/members/{memberId}") @Transactional
 public Map<String,Boolean> role(Authentication auth,@PathVariable String memberId,@Valid @RequestBody RoleInput input){
  String home=permission(auth,"ADMIN");
  var roles=db.queryForList("SELECT family_role FROM accounts WHERE id=? AND household_id=?",String.class,memberId,home);
  if(roles.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  if(roles.getFirst().equals("ADMIN")&&!input.role().equals("ADMIN")&&db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=? AND family_role='ADMIN'",Integer.class,home)<=1)throw new ResponseStatusException(HttpStatus.CONFLICT,"LAST_ADMIN");
  String permissions=RoleRules.validate(input.role(),input.permissions(),input.expiresAt(),home,benefits);
  db.update("UPDATE accounts SET family_role=?,permissions=?,access_until=? WHERE id=?",input.role(),permissions,input.expiresAt()==null?null:Timestamp.from(input.expiresAt()),memberId);
  // An admin can revoke an unused invite after changing who is trusted.
  db.update("DELETE FROM invites WHERE household_id=?",home);
  return Map.of("saved",true);
 }
 @PostMapping("/leave") @Transactional
 public Map<String,Boolean> leave(Authentication auth){
  String home=household(auth);
  if(db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=?",Integer.class,home)==1)throw new ResponseStatusException(HttpStatus.CONFLICT);
  String role=db.queryForObject("SELECT family_role FROM accounts WHERE id=?",String.class,auth.getName());
  if(role.equals("ADMIN")&&db.queryForObject("SELECT COUNT(*) FROM accounts WHERE household_id=? AND family_role='ADMIN'",Integer.class,home)<=1)throw new ResponseStatusException(HttpStatus.CONFLICT,"LAST_ADMIN");
  String next=id();db.update("INSERT INTO households(id) VALUES (?)",next);
  db.update("UPDATE care_tasks SET assigned_to=NULL WHERE assigned_to=?",auth.getName());
  db.update("UPDATE accounts SET household_id=?,family_role='ADMIN',permissions=?,access_until=NULL WHERE id=?",next,RoleRules.FULL,auth.getName());return Map.of("left",true);
 }
}
