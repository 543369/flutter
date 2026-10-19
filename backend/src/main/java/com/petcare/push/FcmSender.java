package com.petcare.push;

import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.*;
import java.net.*;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.*;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.interfaces.RSAPrivateKey;
import java.time.*;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

@Component
public class FcmSender {
 private final ObjectMapper json;
 private final HttpClient http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
 private final boolean enabled;
 private String project,email,privateKey,accessToken;
 private Instant expires=Instant.EPOCH;
 public FcmSender(ObjectMapper json,@Value("${petcare.push.enabled:false}") boolean enabled,@Value("${petcare.push.credentials-file:}") String file) {
  this.json=json;this.enabled=enabled;
  if(enabled) {
   try {
    Map<?,?> credentials=json.readValue(Files.readString(Path.of(file)),Map.class);
    project=Objects.toString(credentials.get("project_id"),"");email=Objects.toString(credentials.get("client_email"),"");privateKey=Objects.toString(credentials.get("private_key"),"");
    if(!project.matches("[a-z][a-z0-9-]{4,61}[a-z0-9]") || !email.endsWith(".gserviceaccount.com") || privateKey.isBlank())throw new IllegalArgumentException();
   } catch(Exception e){throw new IllegalStateException("Push enabled but service-account credentials are missing or invalid");}
  }
 }
 public enum Result { SENT, INVALID_TOKEN, RETRY }
 public Result send(String token,String household,long revision) {
  if(!enabled)return Result.RETRY;
  try {
   String body=json.writeValueAsString(payload(token,household,revision));
   var request=HttpRequest.newBuilder(URI.create("https://fcm.googleapis.com/v1/projects/"+project+"/messages:send"))
    .timeout(Duration.ofSeconds(10)).header("Authorization","Bearer "+authorization()).header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString(body)).build();
   var response=http.send(request,HttpResponse.BodyHandlers.ofString());
   if(response.statusCode()==200)return Result.SENT;
   if(response.statusCode()==401)expires=Instant.EPOCH;
   var error=json.readTree(response.body()).path("error").path("details");
   for(var detail:error)if("UNREGISTERED".equals(detail.path("errorCode").asText()))return Result.INVALID_TOKEN;
  } catch(InterruptedException e){Thread.currentThread().interrupt();}
  catch(Exception ignored){ /* Never log tokens, credentials or response bodies. */ }
  return Result.RETRY;
 }
 public static Map<String,Object> payload(String token,String home,long revision) {
  return Map.of("message",Map.of(
   "token",token,"data",Map.of("type","CARE_CHANGED","householdId",home,"revision",Long.toString(revision)),
   "android",Map.of("priority","normal","collapse_key","care_sync","ttl","3600s"),
   "apns",Map.of("headers",Map.of("apns-push-type","background","apns-priority","5","apns-collapse-id","care_sync"),"payload",Map.of("aps",Map.of("content-available",1)))));
 }
 private synchronized String authorization() throws Exception {
  if(accessToken!=null && expires.isAfter(Instant.now().plusSeconds(60)))return accessToken;
  String pem=privateKey.replace("-----BEGIN PRIVATE KEY-----","").replace("-----END PRIVATE KEY-----","").replaceAll("\\s","");
  var key=(RSAPrivateKey)KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)));
  var claims=new JWTClaimsSet.Builder().issuer(email).audience("https://oauth2.googleapis.com/token")
   .claim("scope","https://www.googleapis.com/auth/firebase.messaging").issueTime(new Date()).expirationTime(Date.from(Instant.now().plusSeconds(3600))).build();
  var jwt=new SignedJWT(new JWSHeader(JWSAlgorithm.RS256),claims);jwt.sign(new RSASSASigner(key));
  String form="grant_type="+URLEncoder.encode("urn:ietf:params:oauth:grant-type:jwt-bearer",StandardCharsets.UTF_8)+"&assertion="+URLEncoder.encode(jwt.serialize(),StandardCharsets.UTF_8);
  var request=HttpRequest.newBuilder(URI.create("https://oauth2.googleapis.com/token")).timeout(Duration.ofSeconds(10)).header("Content-Type","application/x-www-form-urlencoded").POST(HttpRequest.BodyPublishers.ofString(form)).build();
  var response=http.send(request,HttpResponse.BodyHandlers.ofString());
  if(response.statusCode()!=200)throw new IllegalStateException("FCM authorization unavailable");
  var body=json.readTree(response.body());accessToken=body.path("access_token").asText();
  if(accessToken.isBlank())throw new IllegalStateException("FCM authorization unavailable");
  expires=Instant.now().plusSeconds(Math.min(3600,body.path("expires_in").asLong(3600)));return accessToken;
 }
}
