package com.petcare.pets;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import com.petcare.shared.ApiSupport;
import com.petcare.care.CarePlans;
import com.petcare.auth.Tokens;

@RestController
@RequestMapping("/api")
class PetController extends ApiSupport {
 PetController(JdbcTemplate db) { super(db); }
 record PetInput(@NotBlank @Size(max=60) String name,
                 @Pattern(regexp="cat|dog|other") @NotNull String species,
                 @Size(max=1500000) String photoData) {}
 @PostMapping("/pets") @ResponseStatus(HttpStatus.CREATED) @Transactional
 Map<String,String> addPet(Authentication auth, @Valid @RequestBody PetInput input) {
  String pet = id(); db.update("INSERT INTO pets(id,household_id,name,species,photo_data) VALUES (?,?,?,?,?)",pet,household(auth),input.name().strip(),input.species(),input.photoData());
  return Map.of("id",pet);
 }
 @PatchMapping("/pets/{petId}") @Transactional
 Map<String,String> updatePet(Authentication auth, @PathVariable String petId,
                              @Valid @RequestBody PetInput input) {
  require(db.update("UPDATE pets SET name=?,species=?,photo_data=? WHERE id=? AND household_id=?",
    input.name().strip(),input.species(),input.photoData(),petId,household(auth)));
  return Map.of("id",petId);
 }
 @DeleteMapping("/pets/{petId}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void deletePet(Authentication auth, @PathVariable String petId) {
  require(db.update("DELETE FROM pets WHERE id=? AND household_id=?", petId, household(auth)));
 }

}
