package com.petcare.pets;

import com.petcare.benefits.HouseholdBenefits;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
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
 private final HouseholdBenefits benefits;
 PetController(JdbcTemplate db, HouseholdBenefits benefits) { super(db); this.benefits=benefits; }
 record PetInput(@NotBlank @Size(max=60) String name,
                 @Pattern(regexp="cat|dog|other") @NotNull String species,
                 @Size(max=1500000) String photoData,
                 @Size(max=1000) String biography,
                 @PastOrPresent LocalDate birthDate,
                 @Size(max=5) List<@NotBlank @Size(max=1500000) String> photos) {}
 @PostMapping("/pets") @ResponseStatus(HttpStatus.CREATED) @Transactional
 Map<String,String> addPet(Authentication auth, @Valid @RequestBody PetInput input) {
  String home=permission(auth,"PETS"); long before=benefits.usedBytes(home);
  String pet = id(); db.update("INSERT INTO pets(id,household_id,name,species,photo_data,biography,birth_date) VALUES (?,?,?,?,?,?,?)",pet,home,input.name().strip(),input.species(),input.photoData(),input.biography(),input.birthDate());
  savePhotos(pet, input.photos() != null ? input.photos() :
    input.photoData() == null || input.photoData().isEmpty() ? List.of() : List.of(input.photoData()));
  benefits.checkGrowth(home,before);
  return Map.of("id",pet);
 }
 @PatchMapping("/pets/{petId}") @Transactional
 Map<String,String> updatePet(Authentication auth, @PathVariable String petId,
                              @Valid @RequestBody PetInput input) {
  String home=permission(auth,"PETS"); long before=benefits.usedBytes(home);
  require(db.update("UPDATE pets SET name=?,species=?,biography=?,birth_date=? WHERE id=? AND household_id=?",
    input.name().strip(),input.species(),input.biography(),input.birthDate(),petId,home));
  if (input.photos() != null) {
   savePhotos(petId, input.photos());
  } else if (input.photoData() != null && !input.photoData().isEmpty()) {
   // Older clients can replace the cover without losing the remaining photos.
   var photos = new ArrayList<>(db.queryForList("SELECT photo_data FROM pet_photos WHERE pet_id=? ORDER BY position_index",String.class,petId));
   if (photos.isEmpty()) photos.add(input.photoData()); else photos.set(0,input.photoData());
   savePhotos(petId,photos);
  }
  benefits.checkGrowth(home,before);
  return Map.of("id",petId);
 }
 private void savePhotos(String petId, List<String> photos) {
  for (String photo : photos) {
   try {
    if (Base64.getDecoder().decode(photo).length == 0) throw new IllegalArgumentException();
   } catch (IllegalArgumentException e) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST); }
  }
  db.update("DELETE FROM pet_photos WHERE pet_id=?",petId);
  for (int i=0;i<photos.size();i++)
   db.update("INSERT INTO pet_photos(pet_id,position_index,photo_data) VALUES (?,?,?)",petId,i,photos.get(i));
  db.update("UPDATE pets SET photo_data=? WHERE id=?",photos.isEmpty()?null:photos.getFirst(),petId);
 }
 @DeleteMapping("/pets/{petId}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void deletePet(Authentication auth, @PathVariable String petId) {
  require(db.update("DELETE FROM pets WHERE id=? AND household_id=?", petId, permission(auth,"PETS")));
 }

}
