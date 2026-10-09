package com.petcare.billing;

import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.web.server.ResponseStatusException;
import com.petcare.benefits.HouseholdBenefits;

class RevenueCatTests {
 final Instant now=Instant.parse("2026-10-08T00:00:00Z");
 Map<String,Object> response(String expiry,String grace,boolean sandbox,String store,boolean refunded){
  Map<String,Object> grant=new HashMap<>();grant.put("product_identifier","family:monthly");grant.put("expires_date",expiry);grant.put("grace_period_expires_date",grace);
  Map<String,Object> subscription=new HashMap<>();subscription.put("is_sandbox",sandbox);subscription.put("store",store);subscription.put("refunded_at",refunded?now.toString():null);
  return Map.of("subscriber",Map.of("entitlements",Map.of("family_plus",grant),"subscriptions",Map.of("family:monthly",subscription)));
 }
 Instant parse(Map<String,Object> body){return RevenueCatClient.activeUntil(body,"family_plus",Set.of("family:monthly"),false,now);}
 @Test void paidSubscriptionGrantsUntilExpiry(){assertEquals(now.plusSeconds(3600),parse(response(now.plusSeconds(3600).toString(),null,false,"play_store",false)));}
 @Test void sandboxOtherStoreRefundAndExpiredDoNotGrant(){
  assertNull(parse(response(now.plusSeconds(3600).toString(),null,true,"play_store",false)));
  assertNull(parse(response(now.plusSeconds(3600).toString(),null,false,"app_store",false)));
  assertNull(parse(response(now.plusSeconds(3600).toString(),null,false,"play_store",true)));
  assertNull(parse(response(now.toString(),null,false,"play_store",false)));
 }
 @Test void gracePeriodKeepsAccess(){assertEquals(now.plusSeconds(3600),parse(response(now.minusSeconds(60).toString(),now.plusSeconds(3600).toString(),false,"play_store",false)));}
 @Test void malformedResponseDoesNotRevokeExistingAccess(){assertThrows(IllegalArgumentException.class,()->parse(Map.of()));}
 @Test void unrelatedEntitlementAndLifetimeDoNotGrant(){
  assertNull(parse(Map.of("subscriber",Map.of("entitlements",Map.of(),"subscriptions",Map.of()))));
  assertNull(parse(response(null,null,false,"play_store",false)));
 }
 RevenueCatSettings settings(){return new RevenueCatSettings(true,false,"secret","Bearer "+"x".repeat(40),"family_plus","default","app_test","family:monthly",1073741824,false);}
 @Test void enabledBillingRejectsPreviewAndMissingCredentials(){
  assertThrows(IllegalArgumentException.class,()->new RevenueCatSettings(true,false,"secret","Bearer "+"x".repeat(40),"family_plus","default","app_test","family:monthly",1,true));
  assertThrows(IllegalArgumentException.class,()->new RevenueCatSettings(true,false,"","","family_plus","default","","",1,false));
 }
 @Test void webhookRequiresSecretAndCorrectApp(){
  var sync=mock(RevenueCatSync.class);var db=mock(JdbcTemplate.class);var s=settings();
  var controller=new RevenueCatController(db,s,sync,mock(HouseholdBenefits.class),mock(PlatformTransactionManager.class));
  assertThrows(ResponseStatusException.class,()->controller.webhook("wrong",Map.of()));
  assertThrows(ResponseStatusException.class,()->controller.webhook(s.webhookAuthorization,Map.of("event",Map.of("app_id","other"))));
  controller.webhook(s.webhookAuthorization,Map.of("event",Map.of("app_id","app_test","environment","SANDBOX","app_user_id","buyer")));
  verifyNoInteractions(sync,db);
 }
 @Test void duplicateAndTransferEventsReconcileAllOwnersWithoutTrustingPayload(){
  var sync=mock(RevenueCatSync.class);var s=settings();
  var controller=new RevenueCatController(mock(JdbcTemplate.class),s,sync,mock(HouseholdBenefits.class),mock(PlatformTransactionManager.class));
  var event=Map.<String,Object>of("event",Map.of("app_id","app_test","environment","PRODUCTION","type","TRANSFER","transferred_from",List.of("old"),"transferred_to",List.of("new"),"expiration_at_ms",Long.MAX_VALUE));
  controller.webhook(s.webhookAuthorization,event);controller.webhook(s.webhookAuthorization,event);
  verify(sync,times(2)).refresh("old");verify(sync,times(2)).refresh("new");
 }
}
