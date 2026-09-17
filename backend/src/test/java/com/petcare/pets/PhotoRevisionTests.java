package com.petcare.pets;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.transaction.annotation.Transactional;
@SpringBootTest @Transactional
class PhotoRevisionTests {
 @Autowired JdbcTemplate db;
 @Autowired PetController pets;
 @Test void versionChangesOnlyWhenGalleryChangesAndClearingInvalidatesCache() {
  String h=UUID.randomUUID().toString(),a=UUID.randomUUID().toString();
  db.update("INSERT INTO households(id) VALUES (?)",h);
  db.update("INSERT INTO accounts(id,household_id,token_hash,display_name,family_role) VALUES (?,?,?,?,?)",a,h,UUID.randomUUID().toString(),"Tester","ADMIN");
  var auth=new UsernamePasswordAuthenticationToken(a,"unused");
  String p=pets.addPet(auth,new PetController.PetInput("Pet","dog",null,"",null,List.of("AA=="))).get("id");
  long before=db.queryForObject("SELECT photo_revision FROM pets WHERE id=?",Long.class,p);
  pets.updatePet(auth,p,new PetController.PetInput("New name","dog",null,"",null,null));
  assertEquals(before,db.queryForObject("SELECT photo_revision FROM pets WHERE id=?",Long.class,p));
  pets.updatePet(auth,p,new PetController.PetInput("New name","dog",null,"",null,List.of()));
  assertEquals(before+1,db.queryForObject("SELECT photo_revision FROM pets WHERE id=?",Long.class,p));
  assertTrue(((List<?>)pets.photos(auth,p).get("photos")).isEmpty());
 }
}
