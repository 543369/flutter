package com.petcare.health;
import com.petcare.benefits.HouseholdBenefits;
import com.petcare.family.FamilyRolesController;
import com.petcare.family.WeeklyReportController;
import java.time.*;
import java.sql.Timestamp;
import java.math.BigDecimal;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
@SpringBootTest @Transactional
class HealthAndRolesTests {
 @Autowired JdbcTemplate db;
 String id(){return UUID.randomUUID().toString();}
 String home(){String id=id();db.update("INSERT INTO households(id) VALUES (?)",id);return id;}
 String account(String home,String role,String permissions){String id=id();db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role,permissions) VALUES (?,?,?,?,?,?)",id,home,id,"家人",role,permissions);return id;}
 String pet(String home){String id=id();db.update("INSERT INTO pets(id,household_id,name,species) VALUES (?,?,?,?)",id,home,"豆包","dog");return id;}
 UsernamePasswordAuthenticationToken auth(String id){return new UsernamePasswordAuthenticationToken(id,"unused");}
 HouseholdBenefits benefits(boolean preview){return new HouseholdBenefits(db,10000,100000,preview);}
 @Test void freeHealthEntryPremiumTrendsAndPermissionBoundary(){
  String home=home(),owner=account(home,"ADMIN","CARE,HEALTH,MEMORIES,PETS,REPORTS"),pet=pet(home);
  var controller=new HealthRecordController(db,benefits(false));
  var input=new HealthRecordController.Input("WEIGHT","体重","",LocalDate.now(),new BigDecimal("4.500"),List.of());
  String record=controller.create(auth(owner),pet,input).get("id");
  assertEquals(new BigDecimal("4.500"),controller.get(auth(owner),pet,record).get("weightKg"));
  assertEquals(403,assertThrows(ResponseStatusException.class,()->controller.trend(auth(owner),pet)).getStatusCode().value());
  String guest=account(home,"TEMP","CARE");
  assertEquals(403,assertThrows(ResponseStatusException.class,()->controller.get(auth(guest),pet,record)).getStatusCode().value());
  String outsider=account(home(),"ADMIN","");
  assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.get(auth(outsider),pet,record)).getStatusCode().value());
  var advanced=new HealthRecordController(db,benefits(true));
  assertEquals(1,((List<?>)advanced.trend(auth(owner),pet).get("items")).size());
  advanced.organize(auth(owner),pet,new HealthRecordController.Batch(List.of(record),"2026 健康检查"));
  assertEquals("2026 健康检查",advanced.get(auth(owner),pet,record).get("folder"));
 }
 @Test void timelineIsChronologicalScopedAndFilteredWithoutPrivateFields(){
  String home=home(),owner=account(home,"ADMIN","CARE,HEALTH,MEMORIES,PETS,REPORTS"),pet=pet(home);
  var controller=new HealthRecordController(db,benefits(false));
  LocalDate today=LocalDate.now();
  controller.create(auth(owner),pet,new HealthRecordController.Input("WEIGHT","近期体重","",today,new BigDecimal("4.5"),List.of()));
  controller.create(auth(owner),pet,new HealthRecordController.Input("VACCINE","较早疫苗","医嘱",today.minusDays(10),null,List.of("AA==")));
  var timeline=controller.timeline(auth(owner),pet,null,null);
  var items=(List<Map<String,Object>>)timeline.get("items");
  assertEquals("较早疫苗",items.getFirst().get("title"));assertEquals(1,items.getFirst().get("attachmentCount"));
  assertFalse(items.getFirst().containsKey("photos"));assertFalse(((Map<?,?>)timeline.get("pet")).containsKey("phone"));
  assertEquals(1,((List<?>)controller.timeline(auth(owner),pet,today,today).get("items")).size());
  assertThrows(ResponseStatusException.class,()->controller.timeline(auth(owner),pet,today,today.minusDays(1)));
  String restricted=account(home,"TEMP","HEALTH");
  assertEquals(403,assertThrows(ResponseStatusException.class,()->controller.timeline(auth(restricted),pet,null,null)).getStatusCode().value());
  String other=account(home(),"ADMIN","");
  assertEquals(404,assertThrows(ResponseStatusException.class,()->controller.timeline(auth(other),pet,null,null)).getStatusCode().value());
 }
 @Test void roleExpiryLastAdminAndBasicRoleChanges(){
  String home=home(),owner=account(home,"ADMIN","CARE,HEALTH,MEMORIES,PETS,REPORTS"),member=account(home,"MEMBER","CARE,HEALTH,MEMORIES,PETS,REPORTS");
  var controller=new FamilyRolesController(db,benefits(true));
  assertEquals(409,assertThrows(ResponseStatusException.class,()->controller.role(auth(owner),owner,new FamilyRolesController.RoleInput("MEMBER",null,null))).getStatusCode().value());
  assertEquals(403,assertThrows(ResponseStatusException.class,()->controller.role(auth(member),owner,new FamilyRolesController.RoleInput("MEMBER",null,null))).getStatusCode().value());
  var free=new FamilyRolesController(db,benefits(false));
  assertThrows(ResponseStatusException.class,()->free.role(auth(owner),member,new FamilyRolesController.RoleInput("TEMP",List.of("CARE"),Instant.now().plusSeconds(3600))));
  controller.role(auth(owner),member,new FamilyRolesController.RoleInput("TEMP",List.of("CARE"),Instant.now().plusSeconds(3600)));
  assertEquals(false,controller.members(auth(member)).get("canManage"));
  db.update("UPDATE accounts SET access_until=? WHERE id=?",Timestamp.from(Instant.now().minusSeconds(1)),member);
  assertEquals("ACCESS_EXPIRED",assertThrows(ResponseStatusException.class,()->controller.members(auth(member))).getReason());
  assertEquals(true,controller.leave(auth(member)).get("left"));
  assertEquals("ADMIN",db.queryForObject("SELECT family_role FROM accounts WHERE id=?",String.class,member));
 }
 @Test void weeklyExcludesFutureCountsFinalCompletionAndSeparatesAssignments(){
  String home=home(),owner=account(home,"ADMIN","CARE,HEALTH,MEMORIES,PETS,REPORTS"),pet=pet(home);
  LocalDate start=LocalDate.now(ZoneId.of("Asia/Shanghai")).with(java.time.DayOfWeek.MONDAY).minusWeeks(1);
  Instant due=start.atStartOfDay(ZoneId.of("Asia/Shanghai")).toInstant().plusSeconds(3600);
  String done=id(),missed=id();
  for(String task:List.of(done,missed))db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,assigned_to) VALUES (?,?,?,?,?)",task,pet,"喂食",Timestamp.from(due),owner);
  for(int i=0;i<3;i++)db.update("INSERT INTO care_events VALUES (?,?,?,?,?)",id(),done,owner,i==1?"REOPENED":"COMPLETED",Timestamp.from(due.plusSeconds(i+1)));
  var report=new WeeklyReportController(db,benefits(true)).report(auth(owner),start,"Asia/Shanghai",true);
  assertEquals(2,report.get("due"));assertEquals(1,report.get("completed"));assertEquals(1,report.get("missed"));assertEquals(50.0,report.get("completionRate"));
  var members=(Collection<Map<String,Object>>)report.get("members");assertEquals(2,members.iterator().next().get("assigned"));
  assertEquals(8,((List<?>)report.get("trends")).size());
  assertThrows(ResponseStatusException.class,()->new WeeklyReportController(db,benefits(false)).report(auth(owner),start,"Asia/Shanghai",false));
 }
}
