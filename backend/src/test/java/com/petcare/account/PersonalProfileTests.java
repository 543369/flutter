package com.petcare.account;
import com.petcare.auth.DefaultNames;
import jakarta.validation.Validator;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest @Transactional
class PersonalProfileTests {
 @Autowired JdbcTemplate db;
 @Autowired Validator validator;
 @Test void profileIsPrivateAndCreationTimeIsImmutable() {
  String home=UUID.randomUUID().toString(),one=UUID.randomUUID().toString(),two=UUID.randomUUID().toString();
  db.update("INSERT INTO households(id) VALUES (?)",home);
  for(String id:new String[]{one,two}) db.update("INSERT INTO accounts(id,household_id,token_hash,display_name) VALUES (?,?,?,?)",id,home,id,"家人");
  var controller=new AccountController(db);
  var auth=new UsernamePasswordAuthenticationToken(one,"unused");
  Object created=controller.profile(auth).get("createdAt"); assertNotNull(created);
  var saved=controller.profile(auth,new AccountController.ProfileInput(" 小圆 ",LocalDate.of(2000,2,29),"+86 138 0000 0000"));
  assertEquals("小圆",saved.get("name")); assertEquals("2000-02-29",saved.get("birthDate"));
  assertEquals(created,saved.get("createdAt")); assertEquals(one,saved.get("id"));
  var other=controller.profile(new UsernamePasswordAuthenticationToken(two,"unused"));
  assertNull(other.get("phone")); assertNull(other.get("birthDate"));
  assertNull(controller.profile(auth,new AccountController.ProfileInput("小圆",null,"")).get("phone"));
 }
 @Test void validatesDatesPhonesAndLocaleNames() {
  assertFalse(validator.validate(new AccountController.ProfileInput(" ",LocalDate.now().plusDays(1),"bad-number")).isEmpty());
  assertTrue(validator.validate(new AccountController.ProfileInput("Sunny",LocalDate.of(1999,1,1),"+1 415 555 1234")).isEmpty());
  assertTrue(DefaultNames.forLocale("zh-CN").matches("[\\p{IsHan}]+[0-9]{4}"));
  assertTrue(DefaultNames.forLocale("en-US").matches("[A-Za-z]+[0-9]{4}"));
  assertNotNull(DefaultNames.forLocale("ja-JP"));
 }
}
