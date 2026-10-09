package com.petcare.auth;

import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import java.util.*;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.ObjectMapper;

@Component
class IdentityMailSender {
 private final String provider,apiKey,from;
 private final ObjectProvider<JavaMailSender> smtp;
 private final ObjectMapper json;
 private final HttpClient http;
 @Autowired
 IdentityMailSender(@Value("${petcare.mail.provider:resend}") String provider,
   @Value("${petcare.mail.resend-api-key:}") String apiKey,
   @Value("${petcare.mail.from:}") String from,ObjectProvider<JavaMailSender> smtp,ObjectMapper json) {
  this(provider,apiKey,from,smtp,json,HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
 }
 IdentityMailSender(String provider,String apiKey,String from,ObjectProvider<JavaMailSender> smtp,ObjectMapper json,HttpClient http) {
  if(!Set.of("resend","smtp").contains(provider))throw new IllegalArgumentException("Unsupported mail provider");
  this.provider=provider;this.apiKey=apiKey;this.from=from;this.smtp=smtp;this.json=json;this.http=http;
 }
 void requireConfigured(){
  if(from.isBlank() || (provider.equals("resend")?apiKey.isBlank():smtp.getIfAvailable()==null))
   throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"MAIL_NOT_CONFIGURED");
 }
 void send(String to,String subject,String text){
  requireConfigured();
  try {
   if(provider.equals("smtp")) {
    SimpleMailMessage message=new SimpleMailMessage();message.setFrom(from);message.setTo(to);message.setSubject(subject);message.setText(text);
    smtp.getObject().send(message);return;
   }
   var body=json.writeValueAsString(Map.of("from",from,"to",List.of(to),"subject",subject,"text",text));
   var request=HttpRequest.newBuilder(URI.create("https://api.resend.com/emails"))
    .timeout(Duration.ofSeconds(10)).header("Authorization","Bearer "+apiKey)
    .header("Content-Type","application/json").header("Accept","application/json")
    .POST(HttpRequest.BodyPublishers.ofString(body)).build();
   var response=http.send(request,HttpResponse.BodyHandlers.ofString());
   if(response.statusCode()!=200 && response.statusCode()!=201)throw new IllegalStateException();
   var result=json.readValue(response.body(),Map.class);
   if(!(result.get("id") instanceof String id) || id.isBlank())throw new IllegalStateException();
  } catch(InterruptedException e) {
   Thread.currentThread().interrupt();throw unavailable();
  } catch(Exception e) {
   // Never expose provider responses, credentials, recipients or verification tokens.
   throw unavailable();
  }
 }
 private ResponseStatusException unavailable(){return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"MAIL_DELIVERY_UNAVAILABLE");}
}
