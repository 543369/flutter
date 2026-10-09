package com.petcare.auth;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;
@SpringBootTest @Transactional
class DefaultNameRegistrationTests {
 @Autowired AuthController controller;
 @Autowired JdbcTemplate db;
 @Test void registrationGeneratesRegionalNameAndKeepsChosenName() {
  for(String locale:new String[]{"zh-CN","en-US"}) {
   var request=new MockHttpServletRequest();request.setRemoteAddr(UUID.randomUUID().toString());
   String email=UUID.randomUUID()+"@example.com";
   seed(email);
   controller.register(new AuthController.Registration(email,"Strong-password-123",null,locale,"fixture-code"),null,request);
   String name=db.queryForObject("SELECT display_name FROM accounts WHERE email=?",String.class,email);
   assertTrue(name.matches(locale.startsWith("zh")?"[\\p{IsHan}]+[0-9]{4}":"[A-Za-z]+[0-9]{4}"));
   assertNotNull(db.queryForObject("SELECT created_at FROM accounts WHERE email=?",java.sql.Timestamp.class,email));
  }
  String email=UUID.randomUUID()+"@example.com";
  var request=new MockHttpServletRequest();request.setRemoteAddr(UUID.randomUUID().toString());
  seed(email);
  controller.register(new AuthController.Registration(email,"Strong-password-123","Junny","zh-CN","fixture-code"),null,request);
  assertEquals("Junny",db.queryForObject("SELECT display_name FROM accounts WHERE email=?",String.class,email));
 }
 void seed(String email){db.update("INSERT INTO registration_verifications(email,token_hash,sent_at,expires_at) VALUES (?,?,UTC_TIMESTAMP(6),DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 15 MINUTE))",email,Tokens.hash("fixture-code"));}

}
