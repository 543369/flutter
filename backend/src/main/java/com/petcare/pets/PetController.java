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
 record PetInput(@NotBlank @Size(max=60) String name, @Pattern(regexp="cat|dog|other") @NotNull String species) {}
 @PostMapping("/pets") @ResponseStatus(HttpStatus.CREATED) @Transactional
 Map<String,String> addPet(Authentication auth, @Valid @RequestBody PetInput input) {
  String pet = id(); db.update("INSERT INTO pets(id,household_id,name,species) VALUES (?,?,?,?)",pet,household(auth),input.name().strip(),input.species());
  return Map.of("id",pet);
 }
 @DeleteMapping("/pets/{petId}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void deletePet(Authentication auth, @PathVariable String petId) {
  require(db.update("DELETE FROM pets WHERE id=? AND household_id=?", petId, household(auth)));
 }

}
