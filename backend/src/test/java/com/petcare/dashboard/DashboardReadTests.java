package com.petcare.dashboard;
import java.util.*;
import java.sql.Timestamp;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
@SpringBootTest @Transactional
class DashboardReadTests {
 @Autowired JdbcTemplate db;
 @Autowired DashboardController dashboard;
 @Autowired CareReadController reads;
 String id(){return UUID.randomUUID().toString();}
 @Test void dashboardRetainsHealthLinksAndExcludesSkippedTasks(){
  String h=id(),a=id(),p=id(),record=id(),task=id(),skipped=id();
  db.update("INSERT INTO households(id) VALUES (?)",h);
  db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role) VALUES (?,?,?,?,?)",a,h,id(),"Tester","ADMIN");
  db.update("INSERT INTO pets(id,household_id,name,species) VALUES (?,?,?,?)",p,h,"Pet","cat");
  db.update("INSERT INTO health_records(id,pet_id,kind,title,notes,happened_on) VALUES (?,?,?,?,'',CURRENT_DATE)",record,p,"VACCINE","Follow up");
  db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,health_record_id) VALUES (?,?,?,?,?)",task,p,"Care",Timestamp.from(Instant.now()),record);
  db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,skipped) VALUES (?,?,?,?,TRUE)",skipped,p,"Skipped",Timestamp.from(Instant.now()));
  var auth=new UsernamePasswordAuthenticationToken(a,"unused");
  for(boolean compact:List.of(true,false)) {
   var tasks=(List<Map<String,Object>>)dashboard.dashboard(auth,compact).get("tasks");
   assertEquals(1,tasks.size());assertEquals(record,tasks.getFirst().get("healthRecordId"));
  }
  assertEquals(1,((List<?>)reads.tasks(auth,p,null).get("items")).size());
 }
 @Test void compactBoundsPayloadAndPaginationRetainsAllTasks(){
  String h=id(),a=id(),p=id();
  db.update("INSERT INTO households(id) VALUES (?)",h);
  db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role) VALUES (?,?,?,?,?)",a,h,id(),"Tester","ADMIN");
  db.update("INSERT INTO pets(id,household_id,name,species,photo_data) VALUES (?,?,?,?,?)",p,h,"Pet","dog","photo-data");
  var auth=new UsernamePasswordAuthenticationToken(a,"unused");
  for(int n=0;n<305;n++) db.update("INSERT INTO care_tasks(id,pet_id,title,due_at) VALUES (?,?,?,?)",id(),p,"Task "+n,Timestamp.from(Instant.now().plusSeconds(n<301 ? -3600-n : 3600+n)));
  var compact=dashboard.dashboard(auth,true);
  assertEquals(300,((List<?>)compact.get("tasks")).size());
  assertEquals(true,compact.get("tasksTruncated"));
  var pet=(Map<?,?>)((List<?>)compact.get("pets")).getFirst();
  assertNull(pet.get("photoData"));assertNotNull(pet.get("photoVersion"));
  assertEquals(0L,pet.get("photoRevision"));
  db.update("UPDATE pets SET photo_revision=7 WHERE id=?",p);
  var updatedPet=(Map<?,?>)((List<?>)dashboard.dashboard(auth,true).get("pets")).getFirst();
  assertEquals(7L,updatedPet.get("photoRevision"));
  assertEquals(305,((List<?>)dashboard.dashboard(auth,false).get("tasks")).size());
  assertEquals(4,((List<?>)compact.get("reminderTasks")).size());
  Set<Object> ids=new HashSet<>();
  String cursor=null;
  for(int offset=0;offset<305;offset+=50){
   var page=reads.tasks(auth,p,cursor);
   cursor=(String)page.get("nextCursor");
   if(offset==0) db.update("UPDATE care_tasks SET due_at=? WHERE pet_id=?",Timestamp.from(Instant.now().minusSeconds(86400)),p);
   for(var item:(List<Map<String,Object>>)page.get("items")) assertTrue(ids.add(item.get("id")));
  }
  assertEquals(305,ids.size());
  String task=db.queryForObject("SELECT id FROM care_tasks WHERE pet_id=? LIMIT 1",String.class,p);
  var at=Timestamp.from(Instant.now());
  for(int n=0;n<52;n++) db.update("INSERT INTO care_events(id,task_id,actor_id,action,happened_at) VALUES (?,?,?,?,?)",id(),task,a,"COMPLETED",at);
  var first=reads.care_history(auth,p,null);
  var second=reads.care_history(auth,p,(String)first.get("nextCursor"));
  assertEquals(50,((List<?>)first.get("items")).size());
  assertEquals(2,((List<?>)second.get("items")).size());
  Set<Object> eventIds=new HashSet<>();
  for(var page:List.of(first,second)) for(var event:(List<Map<String,Object>>)page.get("items")) assertTrue(eventIds.add(event.get("id")));
  assertTrue(((List<?>)reads.tasks(auth,id(),null).get("items")).isEmpty());
 }
}
