package com.petcare.care;
import java.util.*;
import java.time.*;
import java.sql.Timestamp;
import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest @Transactional
class OverdueTests {
 @Autowired JdbcTemplate db;@Autowired OverdueController controller;
 String id(){return UUID.randomUUID().toString();}
 record Fixture(String home,String actor,String pet) {UsernamePasswordAuthenticationToken auth(){return new UsernamePasswordAuthenticationToken(actor,"");}}
 Fixture fixture(){String home=id(),actor=id(),pet=id();db.update("INSERT INTO households(id) VALUES(?)",home);db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role) VALUES(?,?,?,'Tester','ADMIN')",actor,home,id());db.update("INSERT INTO pets(id,household_id,name,species) VALUES(?,?,'Mochi','cat')",pet,home);return new Fixture(home,actor,pet);}
 String plan(Fixture f){String plan=id();db.update("INSERT INTO care_plans(id,pet_id,title,frequency,zone_id,starts_at,care_type) VALUES(?,?,'Walk','DAILY','Asia/Shanghai',UTC_TIMESTAMP(),'WALK')",plan,f.pet);return plan;}
 String task(Fixture f,String plan,int day){String task=id();db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,plan_id,care_type) VALUES(?,?,'Walk',?,?, 'WALK')",task,f.pet,Timestamp.from(Instant.now().minusSeconds(day*86400L)),plan);return task;}
 Instant before(){return LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC);}
 OverdueController.Selection selection(Fixture f,boolean all,List<String> groups,List<OverdueController.Ref> refs){return new OverdueController.Selection(f.pet,before(),null,null,Instant.now(),all,groups,List.of(),List.of(),refs);}
 @Test void groupsAndItemsPageByIdentityAndCountBeyondDashboardLimit(){
  var f=fixture();String p=plan(f);for(int i=0;i<331;i++)task(f,p,2+i);
  task(f,null,2);String other=plan(f);task(f,other,3);
  var summary=controller.groups(f.auth(),f.pet,before(),null,null,null,"");
  assertEquals(333L,((Number)summary.get("total")).longValue());assertEquals(2,((List<?>)summary.get("items")).size());
  Set<String> seen=new HashSet<>();String cursor="";
  do {
   var page=controller.items(f.auth(),f.pet,p,before(),null,null,null,cursor);
   for(var row:(List<Map<String,Object>>)page.get("items"))assertTrue(seen.add((String)row.get("id")));
   cursor=(String)page.get("nextCursor");
  }while(!cursor.isEmpty());assertEquals(331,seen.size());
 }
 @Test void groupPaginationAndDateBoundsAreScoped(){
  var f=fixture();for(int i=0;i<23;i++)task(f,plan(f),2);
  var first=controller.groups(f.auth(),f.pet,before(),null,null,null,"");assertEquals(20,((List<?>)first.get("items")).size());
  var last=controller.groups(f.auth(),f.pet,before(),null,null,Instant.parse((String)first.get("asOf")),(String)first.get("nextCursor"));assertEquals(3,((List<?>)last.get("items")).size());
  assertThrows(ResponseStatusException.class,()->controller.groups(fixture().auth(),f.pet,before(),null,null,null,""));
  assertThrows(ResponseStatusException.class,()->controller.groups(f.auth(),f.pet,before(),before().plusSeconds(1),null,null,""));
 }
 @Test void recurringSelectionExcludesOneOffsAndBatchesResumeWithoutDuplicateEvents(){
  var f=fixture();String p=plan(f);for(int i=0;i<205;i++)task(f,p,2+i);String medical=task(f,null,2);
  var preview=controller.preview(f.auth(),selection(f,true,List.of(),List.of()));assertEquals(205,((Number)preview.get("total")).intValue());String job=(String)preview.get("id");
  var progress=controller.apply(f.auth(),job);assertEquals(100,((Number)progress.get("success")).intValue());assertEquals(105,((Number)progress.get("remaining")).intValue());
  assertEquals(job,controller.current(f.auth(),f.pet).get("id"));
  controller.apply(f.auth(),job);var done=controller.apply(f.auth(),job);assertEquals(true,done.get("finished"));assertEquals(205,((Number)done.get("success")).intValue());
  controller.apply(f.auth(),job);
  assertEquals(205,db.queryForObject("SELECT COUNT(*) FROM care_events WHERE actor_id=? AND action='SKIPPED'",Integer.class,f.actor));
  assertFalse(db.queryForObject("SELECT skipped FROM care_tasks WHERE id=?",Boolean.class,medical));
 }
 @Test void changedDeletedAndCrossHouseholdEntriesCannotBeOverwritten(){
  var f=fixture();String p=plan(f),changed=task(f,p,2),deleted=task(f,p,3),normal=task(f,p,4),single=task(f,null,2);
  var preview=controller.preview(f.auth(),selection(f,true,List.of(),List.of(new OverdueController.Ref(single,0))));String job=(String)preview.get("id");
  db.update("UPDATE care_tasks SET completed=TRUE,revision=revision+1 WHERE id=?",changed);db.update("DELETE FROM care_tasks WHERE id=?",deleted);
  var result=controller.apply(f.auth(),job);assertEquals(2,((Number)result.get("changed")).intValue());assertEquals(2,((Number)result.get("success")).intValue());assertEquals(0,((Number)result.get("failed")).intValue());
  assertFalse(db.queryForObject("SELECT skipped FROM care_tasks WHERE id=?",Boolean.class,changed));assertTrue(db.queryForObject("SELECT skipped FROM care_tasks WHERE id=?",Boolean.class,normal));
  assertThrows(ResponseStatusException.class,()->controller.apply(fixture().auth(),job));
 }
 @Test void exclusionsAndExpiredPreviewsAreHonored(){
  var f=fixture();String p=plan(f),excluded=task(f,p,2);task(f,p,3);String p2=plan(f);task(f,p2,3);
  var input=new OverdueController.Selection(f.pet,before(),null,null,Instant.now(),true,List.of(),List.of(p2),List.of(excluded),List.of());
  var preview=controller.preview(f.auth(),input);assertEquals(1,((Number)preview.get("total")).intValue());String job=(String)preview.get("id");
  db.update("UPDATE overdue_batches SET expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE id=?",job);
  assertEquals("OVERDUE_PREVIEW_EXPIRED",assertThrows(ResponseStatusException.class,()->controller.apply(f.auth(),job)).getReason());
 }
}
