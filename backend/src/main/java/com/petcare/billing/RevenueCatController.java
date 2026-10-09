package com.petcare.billing;

import com.petcare.shared.ApiSupport;
import com.petcare.benefits.HouseholdBenefits;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/billing/revenuecat")
public class RevenueCatController extends ApiSupport {
 private final RevenueCatSettings settings;private final RevenueCatSync sync;private final HouseholdBenefits benefits;private final TransactionTemplate tx;
 public RevenueCatController(JdbcTemplate db,RevenueCatSettings settings,RevenueCatSync sync,HouseholdBenefits benefits,PlatformTransactionManager manager){
  super(db);this.settings=settings;this.sync=sync;this.benefits=benefits;this.tx=new TransactionTemplate(manager);
 }
 @PostMapping("/session")
 public Map<String,Object> session(Authentication auth){
  if(!settings.enabled)return Map.of("enabled",false);
  return tx.execute(status->{
   String home=permission(auth,"READ");
   var account=db.queryForMap("SELECT password_hash,apple_subject,family_role FROM accounts WHERE id=?",auth.getName());
   if(account.get("password_hash")==null && account.get("apple_subject")==null)
    throw new ResponseStatusException(HttpStatus.CONFLICT,"REGISTER_BEFORE_PURCHASE");
   boolean admin="ADMIN".equals(account.get("family_role"));
   if(!admin && db.queryForObject("SELECT COUNT(*) FROM revenuecat_customers WHERE account_id=?",Integer.class,auth.getName())==0)
    throw new ResponseStatusException(HttpStatus.FORBIDDEN,"PERMISSION_DENIED");
   db.update("INSERT IGNORE INTO revenuecat_customers(account_id,app_user_id,household_id) VALUES (?,?,?)",auth.getName(),id(),home);
   var customer=db.queryForMap("SELECT app_user_id,household_id FROM revenuecat_customers WHERE account_id=?",auth.getName());
   return Map.of("enabled",true,"appUserId",customer.get("app_user_id"),"offeringId",settings.offering,
    "entitlementId",settings.entitlement,"products",settings.products,"sameHousehold",home.equals(customer.get("household_id")),"canPurchase",admin,"sandbox",settings.sandbox);
  });
 }
 @PostMapping("/sync")
 public Map<String,Object> refresh(Authentication auth){
  if(!settings.enabled)throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);
  var ids=db.queryForList("SELECT app_user_id FROM revenuecat_customers WHERE account_id=?",String.class,auth.getName());
  if(ids.isEmpty())throw new ResponseStatusException(HttpStatus.CONFLICT);
  try{sync.refresh(ids.getFirst());}catch(RuntimeException e){throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);}
  return tx.execute(status->benefits.status(permission(auth,"READ")));
 }
 @PostMapping("/webhook")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void webhook(@RequestHeader(value="Authorization",defaultValue="") String authorization,@RequestBody Map<String,Object> body){
  if(!settings.enabled || !MessageDigest.isEqual(settings.webhookAuthorization.getBytes(StandardCharsets.UTF_8),authorization.getBytes(StandardCharsets.UTF_8)))
   throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
  var event=RevenueCatClient.object(body.get("event"));
  if(!settings.appId.equals(event.get("app_id")))throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  if("TEST".equals(event.get("type")))return;
  String environment=settings.sandbox?"SANDBOX":"PRODUCTION";
  if(event.get("environment")!=null && !environment.equals(event.get("environment")))return;
  Set<String> ids=new HashSet<>();
  for(String key:List.of("app_user_id","original_app_user_id")){if(event.get(key) instanceof String s)ids.add(s);}
  for(String key:List.of("aliases","transferred_from","transferred_to")){if(event.get(key) instanceof List<?> values)for(Object value:values)if(value instanceof String s)ids.add(s);}
  if(ids.size()>100)throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  try{for(String id:ids)sync.refresh(id);}catch(RuntimeException e){throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);}
 }
}
