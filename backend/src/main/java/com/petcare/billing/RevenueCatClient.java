package com.petcare.billing;

import java.net.URI;
import java.net.http.*;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

@Component
public class RevenueCatClient {
 private final RevenueCatSettings settings;
 private final ObjectMapper json;
 private final HttpClient http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
 public RevenueCatClient(RevenueCatSettings settings,ObjectMapper json){this.settings=settings;this.json=json;}
 public Instant fetch(String appUserId) {
  // Only server-created UUIDs can enter the URL. No client-selected customer lookup.
  UUID.fromString(appUserId);
  try {
   var request=HttpRequest.newBuilder(URI.create("https://api.revenuecat.com/v1/subscribers/"+appUserId))
    .timeout(Duration.ofSeconds(8)).header("Authorization","Bearer "+settings.apiKey).header("Accept","application/json").GET().build();
   var response=http.send(request,HttpResponse.BodyHandlers.ofString());
   if(response.statusCode()!=200 && response.statusCode()!=201)throw new IllegalStateException("RevenueCat unavailable");
   return activeUntil(json.readValue(response.body(),Map.class),settings.entitlement,settings.products,settings.sandbox,Instant.now());
  } catch(InterruptedException e){Thread.currentThread().interrupt();throw new IllegalStateException("RevenueCat interrupted");}
  catch(Exception e){throw new IllegalStateException("RevenueCat verification failed");}
 }
 static Map<?,?> object(Object value){return value instanceof Map<?,?> m?m:Map.of();}
 public static Instant activeUntil(Map<?,?> body,String entitlement,Set<String> products,boolean sandbox,Instant now){
  if(!(body.get("subscriber") instanceof Map<?,?> subscriber) || !(subscriber.get("entitlements") instanceof Map<?,?> entitlements) || !(subscriber.get("subscriptions") instanceof Map<?,?> subscriptions))
   throw new IllegalArgumentException("Malformed customer response");
  var grant=object(entitlements.get(entitlement));
  String product=Objects.toString(grant.get("product_identifier"),"");
  if(!products.contains(product))return null;
  var subscription=object(subscriptions.get(product));
  if(!"play_store".equals(subscription.get("store")) || !Boolean.valueOf(sandbox).equals(subscription.get("is_sandbox")) || subscription.get("refunded_at")!=null)return null;
  // Only finite subscriptions are enabled; no promotional or lifetime grants.
  Instant end=date(grant.get("expires_date"));
  if(end==null)return null;
  Instant grace=date(grant.get("grace_period_expires_date"));
  if(grace!=null && grace.isAfter(end))end=grace;
  return end.isAfter(now)?end:null;
 }
 private static Instant date(Object value){return value==null?null:Instant.parse(value.toString());}
}
