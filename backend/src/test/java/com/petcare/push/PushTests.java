package com.petcare.push;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import com.petcare.auth.Tokens;

@SpringBootTest @Transactional
class PushTests {
 @Autowired JdbcTemplate db;
 String id(){return UUID.randomUUID().toString();}
 @Test void payloadIsSilentAndContainsNoPetOrAccountContent() {
  var payload=FcmSender.payload("device-token","home",7);
  var message=(Map<?,?>)payload.get("message");
  assertFalse(message.containsKey("notification"));
  assertEquals(Map.of("type","CARE_CHANGED","householdId","home","revision","7"),message.get("data"));
  assertTrue(message.containsKey("apns"));
 }
 @Test void dispatcherHonorsSessionRevocationAndDoesNotLoseNewerInvalidation() {
  String home=id(),actor=id(),device=id(),token=Tokens.hash("session");
  db.update("INSERT INTO households(id) VALUES(?)",home);
  db.update("INSERT INTO accounts(id,household_id,token_hash,display_name) VALUES(?,?,?,'Tester')",actor,home,id());
  db.update("INSERT INTO account_sessions(token_hash,account_id,expires_at,session_id) VALUES(?,?,DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY),?)",token,actor,id());
  db.update("INSERT INTO push_devices(installation_id,account_id,session_hash,fcm_token) VALUES(?,?,?,'device-token')",device,actor,token);
  db.update("INSERT INTO push_outbox(household_id) VALUES(?)",home);
  FcmSender sender=mock(FcmSender.class);
  when(sender.send("device-token",home,1)).thenAnswer(call->{
   db.update("UPDATE push_outbox SET revision=revision+1 WHERE household_id=?",home);
   return FcmSender.Result.SENT;
  });
  var dispatcher=new PushDispatcher(db,sender,true);dispatcher.dispatch();
  assertEquals(2L,db.queryForObject("SELECT revision FROM push_outbox WHERE household_id=?",Long.class,home));
  db.update("DELETE FROM account_sessions WHERE token_hash=?",token);
  dispatcher.dispatch();
  verify(sender,times(1)).send(anyString(),anyString(),anyLong());
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM push_outbox WHERE household_id=?",Integer.class,home));
 }
}
