package com.petcare.auth;

import java.net.http.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Flow;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.ObjectMapper;

class IdentityMailSenderTests {
 final HttpClient http=mock(HttpClient.class);
 final ObjectMapper json=new ObjectMapper();
 IdentityMailSender sender(String key){return new IdentityMailSender("resend",key,"PetCare <noreply@example.com>",mock(ObjectProvider.class),json,http);}
 void response(int status,String body)throws Exception{
  HttpResponse<String> response=mock(HttpResponse.class);
  when(response.statusCode()).thenReturn(status);when(response.body()).thenReturn(body);
  when(http.send(any(HttpRequest.class),any(HttpResponse.BodyHandler.class))).thenReturn(response);
 }
 @Test void resendRequestUsesPrivateKeyAndPlainTextCode()throws Exception{
  response(200,"{\"id\":\"test-email-id\"}");
  sender("re_test_only").send("user@example.com","邮箱验证","验证码\n\ntest-token");
  var request=ArgumentCaptor.forClass(HttpRequest.class);verify(http).send(request.capture(),any(HttpResponse.BodyHandler.class));
  var r=request.getValue();assertEquals("https://api.resend.com/emails",r.uri().toString());assertEquals("POST",r.method());
  assertEquals("Bearer re_test_only",r.headers().firstValue("Authorization").orElseThrow());assertTrue(r.timeout().orElseThrow().toSeconds()<=10);
  var bytes=new java.io.ByteArrayOutputStream();
  r.bodyPublisher().orElseThrow().subscribe(new Flow.Subscriber<ByteBuffer>(){
   public void onSubscribe(Flow.Subscription s){s.request(Long.MAX_VALUE);}public void onNext(ByteBuffer b){byte[] part=new byte[b.remaining()];b.get(part);bytes.writeBytes(part);}
   public void onError(Throwable t){fail(t);}public void onComplete(){}
  });
  var payload=json.readTree(bytes.toString(StandardCharsets.UTF_8));
  assertEquals("user@example.com",payload.get("to").get(0).asText());assertEquals("验证码\n\ntest-token",payload.get("text").asText());
  assertEquals("PetCare <noreply@example.com>",payload.get("from").asText());
 }
 @Test void missingConfigurationMakesNoNetworkRequest(){
  var e=assertThrows(ResponseStatusException.class,()->sender("").send("user@example.com","subject","code"));
  assertEquals(503,e.getStatusCode().value());assertEquals("MAIL_NOT_CONFIGURED",e.getReason());verifyNoInteractions(http);
 }
 @Test void providerFailuresAreSanitized()throws Exception{
  for(int status:new int[]{401,403,429,500}){
   response(status,"private-provider-error-with-token");
   var e=assertThrows(ResponseStatusException.class,()->sender("re_test_only").send("user@example.com","subject","code"));
   assertEquals(503,e.getStatusCode().value());assertEquals("MAIL_DELIVERY_UNAVAILABLE",e.getReason());assertNull(e.getCause());
  }
 }
 @Test void malformedSuccessAndTimeoutDoNotPretendToSend()throws Exception{
  for(String body:new String[]{"{}","not-json","{\"id\":\"\"}"}){
   response(200,body);assertThrows(ResponseStatusException.class,()->sender("re_test_only").send("a@example.com","subject","code"));
  }
  when(http.send(any(HttpRequest.class),any(HttpResponse.BodyHandler.class))).thenThrow(new HttpTimeoutException("private-detail"));
  assertThrows(ResponseStatusException.class,()->sender("re_test_only").send("a@example.com","subject","code"));
 }
}
