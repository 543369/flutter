package com.petcare.subjects;
import com.petcare.shared.SubjectAccess;
import com.petcare.care.CareQueries;
import com.petcare.care.CareReminders;
import com.petcare.auth.Tokens;
import java.time.*;
import java.sql.Timestamp;
import java.util.*;
import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @Transactional
class SubjectTests {
 @Autowired JdbcTemplate db;@Autowired SubjectController subjects;@Autowired MedicationController medication;@Autowired WebApplicationContext context;
 String id(){return UUID.randomUUID().toString();}
 String home(){String h=id();db.update("INSERT INTO households(id) VALUES(?)",h);return h;}
 String account(String h){String a=id();db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role) VALUES(?,?,?,'Tester','ADMIN')",a,h,id());return a;}
 UsernamePasswordAuthenticationToken auth(String a){var auth=new UsernamePasswordAuthenticationToken(a,null,List.of());SecurityContextHolder.getContext().setAuthentication(auth);return auth;}
 String token(String a){String token=Tokens.create();db.update("INSERT INTO account_sessions(token_hash,account_id,expires_at,session_id) VALUES(?,?,?,?)",Tokens.hash(token),a,Timestamp.from(Instant.now().plusSeconds(3600)),id());return token;}
 String human(String owner){return subjects.create(auth(owner),new SubjectController.Profile("妈妈","母亲",LocalDate.of(1960,1,1),"Care notes","REPRESENTATIVE",true)).get("id");}
 String task(String p,String kind){String t=id();db.update("INSERT INTO care_tasks(id,pet_id,title,care_type,due_at) VALUES(?,?,'Private care',?,?)",t,p,kind,Timestamp.from(Instant.now().plusSeconds(3600)));return t;}
 @AfterEach void clear(){SecurityContextHolder.clearContext();}
 @Test void legacyPetsRemainVisibleAndPeopleRequireExplicitAccess(){
  String h=home(),owner=account(h),other=account(h),p=id();db.update("INSERT INTO pets(id,household_id,name,species) VALUES(?,?,'KiMi','dog')",p,h);
  String human=human(owner),t=task(human,"MEAL"),petTask=task(p,"WALK");
  auth(other);assertEquals(1,CareReminders.list(db,h).size());assertThrows(ResponseStatusException.class,()->SubjectAccess.require(db,auth(other),human,"READ"));
  subjects.grant(auth(owner),human,other,new SubjectController.Grant("READ"));
  assertNotNull(SubjectAccess.require(db,auth(other),human,"READ"));assertThrows(ResponseStatusException.class,()->SubjectAccess.require(db,auth(other),human,"CARE"));
  auth(other);assertEquals(2,new CareQueries(db).dashboardTasks(h).size());assertEquals(1,CareReminders.list(db,h).size());
  subjects.grant(auth(owner),human,other,new SubjectController.Grant("CARE"));auth(other);assertEquals(2,CareReminders.list(db,h).size());
  subjects.grant(auth(owner),human,other,new SubjectController.Grant("NONE"));auth(other);assertEquals(1,new CareQueries(db).dashboardTasks(h).size());
  assertEquals("PET",db.queryForObject("SELECT subject_type FROM pets WHERE id=?",String.class,p));
 }
 @Test void consentRevokesAllGrantsAndDoesNotSilentlyRestoreThem(){
  String h=home(),owner=account(h),other=account(h),p=human(owner);task(p,"DRINK");
  subjects.grant(auth(owner),p,other,new SubjectController.Grant("CARE"));subjects.consent(auth(owner),p,new SubjectController.Consent(null,false,true));
  assertThrows(ResponseStatusException.class,()->SubjectAccess.require(db,auth(other),p,"READ"));assertThrows(ResponseStatusException.class,()->SubjectAccess.require(db,auth(owner),p,"CARE"));
  assertNotNull(SubjectAccess.require(db,auth(owner),p,"READ"));auth(owner);assertTrue(CareReminders.list(db,h).isEmpty());
  subjects.consent(auth(owner),p,new SubjectController.Consent("REPRESENTATIVE",true,false));assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM subject_grants WHERE subject_id=?",Integer.class,p));
  assertEquals(4,db.queryForObject("SELECT COUNT(*) FROM subject_consent_events WHERE subject_id=?",Integer.class,p));
  assertThrows(ResponseStatusException.class,()->subjects.create(auth(owner),new SubjectController.Profile("No consent","父亲",null,"",null,false)));
 }
 @Test void medicationOutcomesAreVersionedIdempotentAndNotOrdinaryCompletion(){
  String h=home(),owner=account(h),other=account(h),p=human(owner),t=task(p,"MEDICATION");
  var input=new MedicationController.Log(id(),0,"NOT_TAKEN",Instant.now().minusSeconds(60),"Prescribed medicine","as prescribed","Observed not taken");
  medication.log(auth(owner),t,input);medication.log(auth(owner),t,input);
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM medication_logs WHERE task_id=?",Integer.class,t));
  assertFalse(db.queryForObject("SELECT completed FROM care_tasks WHERE id=?",Boolean.class,t));assertTrue(db.queryForObject("SELECT skipped FROM care_tasks WHERE id=?",Boolean.class,t));
  assertThrows(ResponseStatusException.class,()->medication.log(auth(owner),t,new MedicationController.Log(id(),0,"TAKEN",Instant.now(),"Other","1 unit","")));
  assertThrows(ResponseStatusException.class,()->medication.list(auth(other),t));
  String taken=task(p,"MEDICATION");medication.log(auth(owner),taken,new MedicationController.Log(id(),0,"TAKEN",Instant.now().minusSeconds(30),"Prescribed medicine","as prescribed",""));
  assertTrue(db.queryForObject("SELECT completed FROM care_tasks WHERE id=?",Boolean.class,taken));
  assertNotNull(new CareQueries(db).task(h,taken).get("completedAt"));
 }
 @Test void httpEndpointsFilterEveryReadAndProtectLegacyWrites()throws Exception{
  String h=home(),owner=account(h),other=account(h),p=human(owner),t=task(p,"MEDICATION");String ownerToken=token(owner),otherToken=token(other);
  db.update("INSERT INTO health_records(id,pet_id,kind,title,notes,happened_on) VALUES(?,?,'VISIT','Private visit','',CURRENT_DATE)",id(),p);
  MockMvc mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
  String header="Bearer "+otherToken;
  mvc.perform(get("/api/dashboard").header("Authorization",header)).andExpect(status().isOk()).andExpect(jsonPath("$.pets.length()").value(0)).andExpect(jsonPath("$.tasks.length()").value(0));
  mvc.perform(get("/api/tasks").param("petId",p).header("Authorization",header)).andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(0));
  mvc.perform(get("/api/tasks/"+t).header("Authorization",header)).andExpect(status().isNotFound());
  mvc.perform(get("/api/pets/"+p+"/photos").header("Authorization",header)).andExpect(status().isForbidden());
  mvc.perform(get("/api/pets/"+p+"/health").header("Authorization",header)).andExpect(status().isForbidden());
  mvc.perform(get("/api/pets/"+p+"/memories").header("Authorization",header)).andExpect(status().isForbidden());
  mvc.perform(get("/api/benefits/annual").param("year","2026").header("Authorization",header)).andExpect(status().isOk()).andExpect(jsonPath("$.pets.length()").value(0));
  mvc.perform(patch("/api/tasks/"+t).contentType("application/json").content("{\"completed\":true}").header("Authorization","Bearer "+ownerToken)).andExpect(status().isConflict());
  auth(owner);subjects.grant(auth(owner),p,other,new SubjectController.Grant("READ"));
  String memory=id();db.update("INSERT INTO pet_memories(id,pet_id,title,story,happened_on) VALUES(?,?,'Private memory','Story',CURRENT_DATE)",memory,p);
  mvc.perform(delete("/api/pets/"+p+"/memories/"+memory).header("Authorization",header)).andExpect(status().isForbidden());
  mvc.perform(get("/api/dashboard").header("Authorization",header)).andExpect(status().isOk()).andExpect(jsonPath("$.pets[0].subjectType").value("HUMAN"));
  mvc.perform(get("/api/dashboard").header("Authorization",header)).andExpect(jsonPath("$.pets[0].lifeStage").value("OTHER")).andExpect(jsonPath("$.pets[0].careScenarios[0]").value("DAILY"));
  mvc.perform(patch("/api/tasks/"+t).contentType("application/json").content("{\"completed\":true}").header("Authorization",header)).andExpect(status().isForbidden());
  mvc.perform(post("/api/subjects/"+p+"/consent").contentType("application/json").content("{\"revoke\":true}").header("Authorization","Bearer "+ownerToken)).andExpect(status().isOk());
  mvc.perform(get("/api/dashboard").header("Authorization",header)).andExpect(status().isOk()).andExpect(jsonPath("$.pets.length()").value(0));
 }

 @Test void stageAndScenesPersistAndRemovingAScenePreservesExistingCare(){
  String h=home(),owner=account(h);
  String p=subjects.create(auth(owner),new SubjectController.Profile("Child","Child",null,"","REPRESENTATIVE",true,"CHILD",List.of("RECOVERY","DAILY"))).get("id");
  assertEquals("CHILD",db.queryForObject("SELECT life_stage FROM pets WHERE id=?",String.class,p));assertEquals("DAILY,RECOVERY",db.queryForObject("SELECT care_scenarios FROM pets WHERE id=?",String.class,p));
  String existing=task(p,"REHAB");subjects.update(auth(owner),p,new SubjectController.Profile("Child","Child",null,"","REPRESENTATIVE",true,"CHILD",List.of("DAILY")));
  assertEquals("DAILY",db.queryForObject("SELECT care_scenarios FROM pets WHERE id=?",String.class,p));assertFalse(db.queryForObject("SELECT cancelled FROM care_tasks WHERE id=?",Boolean.class,existing));
  subjects.update(auth(owner),p,new SubjectController.Profile("Child","Child",null,"",null,false));
  assertEquals("CHILD",db.queryForObject("SELECT life_stage FROM pets WHERE id=?",String.class,p));assertEquals("DAILY",db.queryForObject("SELECT care_scenarios FROM pets WHERE id=?",String.class,p));
  assertThrows(ResponseStatusException.class,()->subjects.update(auth(owner),p,new SubjectController.Profile("Child","Child",null,"",null,false,"CHILD",List.of())));
 }
}
