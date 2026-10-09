package com.petcare.billing;

import com.petcare.benefits.HouseholdBenefits;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest(properties={"petcare.billing.enabled=true","petcare.billing.api-key=test-only","petcare.billing.webhook-authorization=Bearer-test-only-authorization-longer-than-32","petcare.billing.app-id=app_test","petcare.billing.products=family:monthly","petcare.benefits.preview-enabled=false"})
@Transactional
class RevenueCatIntegrationTests {
 @Autowired JdbcTemplate db;
 @Autowired RevenueCatController controller;
 @Autowired RevenueCatSync sync;
 @Autowired HouseholdBenefits benefits;
 @MockitoBean RevenueCatClient client;
 String id(){return UUID.randomUUID().toString();}
 String home(){String id=id();db.update("INSERT INTO households(id) VALUES (?)",id);return id;}
 String account(String home){String id=id();db.update("INSERT INTO accounts(id,token_hash,household_id,password_hash) VALUES (?,?,?,?)",id,id(),home,"test-only-hash");return id;}
 @Test void guestCannotBuyAndExistingBuyerCanRestoreAfterRoleChange(){
  String buyer=account(home());var auth=new UsernamePasswordAuthenticationToken(buyer,null,List.of());
  db.update("UPDATE accounts SET password_hash=NULL WHERE id=?",buyer);
  assertEquals(409,assertThrows(org.springframework.web.server.ResponseStatusException.class,()->controller.session(auth)).getStatusCode().value());
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM revenuecat_customers WHERE account_id=?",Integer.class,buyer));
  db.update("UPDATE accounts SET password_hash='test-only' WHERE id=?",buyer);
  var original=controller.session(auth);
  db.update("UPDATE accounts SET family_role='MEMBER' WHERE id=?",buyer);
  var restored=controller.session(auth);
  assertEquals(original.get("appUserId"),restored.get("appUserId"));
  assertEquals(false,restored.get("canPurchase"));
 }
 @Test void grantRefundAndHouseholdIsolation(){
  String home=home(),other=home(),buyer=account(home);
  var auth=new UsernamePasswordAuthenticationToken(buyer,null,List.of());
  var session=controller.session(auth);
  assertEquals(session.get("appUserId"),controller.session(auth).get("appUserId"));
  String customer=(String)session.get("appUserId");
  when(client.fetch(customer)).thenReturn(Instant.now().plusSeconds(3600));
  assertEquals("FAMILY",controller.refresh(auth).get("tier"));
  assertEquals("FREE",benefits.access(other).tier());
  db.update("UPDATE accounts SET household_id=? WHERE id=?",other,buyer);
  assertEquals(false,controller.session(auth).get("sameHousehold"));
  assertEquals("FREE",controller.refresh(auth).get("tier"));
  assertEquals("FAMILY",benefits.access(home).tier());
  when(client.fetch(customer)).thenReturn(null);
  sync.refresh(customer);
  assertEquals("FREE",benefits.access(home).tier());
 }
 @Test void staleOrExpiredCacheCannotGrantAndDeletionKeepsPurchaseIdentity(){
  String home=home(),buyer=account(home);
  var auth=new UsernamePasswordAuthenticationToken(buyer,null,List.of());
  String customer=(String)controller.session(auth).get("appUserId");
  when(client.fetch(customer)).thenReturn(Instant.now().plusSeconds(3600));sync.refresh(customer);
  db.update("UPDATE revenuecat_customers SET verified_at=? WHERE app_user_id=?",Timestamp.from(Instant.now().minusSeconds(3700)),customer);
  assertEquals("FREE",benefits.access(home).tier());
  sync.refresh(customer);
  db.update("UPDATE revenuecat_customers SET active_until=? WHERE app_user_id=?",Timestamp.from(Instant.now().minusSeconds(1)),customer);
  assertEquals("FREE",benefits.access(home).tier());
  db.update("DELETE FROM accounts WHERE id=?",buyer);db.update("DELETE FROM households WHERE id=?",home);
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM revenuecat_customers WHERE app_user_id=?",Integer.class,customer));
 }
}
