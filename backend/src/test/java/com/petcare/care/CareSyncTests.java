package com.petcare.care;
import java.util.*;
import java.time.Instant;
import java.sql.Timestamp;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest @Transactional
class CareSyncTests {
 @Autowired JdbcTemplate db;
 @Autowired CareSyncController sync;
 @Autowired CareQueries queries;
 String id(){return UUID.randomUUID().toString();}
 record Fixture(String home,String actor,String task) {}
 Fixture fixture() {
  String home=id(),actor=id(),pet=id(),task=id();
  db.update("INSERT INTO households(id) VALUES(?)",home);
  db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role) VALUES(?,?,?,?,'ADMIN')",actor,home,id(),"Sync tester");
  db.update("INSERT INTO pets(id,household_id,name,species) VALUES(?,?,?,'cat')",pet,home,"Mochi");
  db.update("INSERT INTO care_tasks(id,pet_id,title,due_at) VALUES(?,?,?,?)",task,pet,"Meal",Timestamp.from(Instant.now().plusSeconds(3600)));
  return new Fixture(home,actor,task);
 }
 CareSyncController.Operation op(Fixture f,String id,long rev,String parent,String action){return new CareSyncController.Operation(id,f.home,f.task,rev,parent,action,null,null,null,null);}
 Map<String,Object> apply(Fixture f,CareSyncController.Operation op){return sync.apply(new UsernamePasswordAuthenticationToken(f.actor,""),op);}
 @Test void lostAcknowledgmentReplaysWithoutDuplicateEventsAndChainsUndo() {
  var f=fixture();var first=op(f,id(),0,null,"COMPLETE");
  apply(f,first);apply(f,first);
  assertEquals(1,queries.recent(f.home,f.task).size());
  apply(f,op(f,id(),0,first.operationId(),"REOPEN"));
  assertEquals(false,queries.task(f.home,f.task).get("completed"));
  assertEquals(2,queries.recent(f.home,f.task).size());
  assertEquals(2,db.queryForObject("SELECT COUNT(*) FROM care_sync_receipts WHERE account_id=?",Integer.class,f.actor));
 }
 @Test void staleEditCannotOverwriteOtherDeviceAndReceiptsArePayloadBound() {
  var f=fixture();var complete=op(f,id(),0,null,"COMPLETE");apply(f,complete);
  var stale=new CareSyncController.Operation(id(),f.home,f.task,0,null,"RESCHEDULE",Instant.now().plusSeconds(7200),null,null,null);
  assertEquals("SYNC_CONFLICT",assertThrows(ResponseStatusException.class,()->apply(f,stale)).getReason());
  assertEquals("OPERATION_REUSED",assertThrows(ResponseStatusException.class,()->apply(f,op(f,complete.operationId(),0,null,"REOPEN"))).getReason());
  var other=fixture();
  assertEquals("HOUSEHOLD_CHANGED",assertThrows(ResponseStatusException.class,()->apply(other,complete)).getReason());
 }
 @Test void skippedSingleMedicalReminderPreservesEventAndNeverCountsAsDone() {
  var f=fixture();apply(f,op(f,id(),0,null,"SKIP"));
  assertEquals(false,queries.task(f.home,f.task).get("completed"));
  assertEquals(true,queries.task(f.home,f.task).get("skipped"));
  assertEquals("SKIPPED",queries.recent(f.home,f.task).getFirst().get("action"));
  assertTrue(queries.dashboardTasks(f.home).isEmpty());
  assertTrue(CareReminders.list(db,f.home).isEmpty());
 }
 @Test void legacyEndpointUpdatesRevisionAndDurablyInvalidatesHousehold() {
  var f=fixture();
  var controller=new CareController(db,new CarePlans(db));
  controller.complete(new UsernamePasswordAuthenticationToken(f.actor,""),f.task,new CareController.Completion(true));
  assertEquals(1L,queries.task(f.home,f.task).get("revision"));
  assertTrue(db.queryForObject("SELECT revision FROM push_outbox WHERE household_id=?",Long.class,f.home)>=1);
 }
}
