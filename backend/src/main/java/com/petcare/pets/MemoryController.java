package com.petcare.pets;

import com.petcare.shared.ApiSupport;
import com.petcare.benefits.HouseholdBenefits;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/pets/{petId}/memories")
class MemoryController extends ApiSupport {
 private final HouseholdBenefits benefits;
 MemoryController(JdbcTemplate db, HouseholdBenefits benefits) { super(db); this.benefits=benefits; }
 record MemoryInput(@NotBlank @Size(max=120) String title,
                    @NotBlank @Size(max=5000) String story,
                    @NotNull @PastOrPresent LocalDate happenedOn,
                    @NotNull @Size(max=6) List<@NotBlank @Size(max=1500000) String> photos) {}

 private String checkPet(Authentication auth, String petId) {
  String home = household(auth);
  if (db.queryForObject("SELECT COUNT(*) FROM pets WHERE id=? AND household_id=?", Integer.class, petId, home) != 1)
   throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  return home;
 }
 private Map<String,Object> summary(java.sql.ResultSet r, int n) throws java.sql.SQLException {
  Map<String,Object> row = new LinkedHashMap<>();
  row.put("id",r.getString("id")); row.put("petId",r.getString("pet_id"));
  row.put("title",r.getString("title")); row.put("story",r.getString("story"));
  row.put("happenedOn",r.getDate("happened_on").toLocalDate().toString());
  row.put("createdAt",r.getTimestamp("created_at").toInstant().toString());
  row.put("updatedAt",r.getTimestamp("updated_at").toInstant().toString());
  row.put("author",r.getString("display_name"));
  return row;
 }
 @GetMapping @Transactional
 Map<String,Object> list(Authentication auth, @PathVariable String petId,
                         @RequestParam(defaultValue="0") int offset) {
  checkPet(auth,petId);
  if(offset<0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  var items=db.query("SELECT m.*,a.display_name,(SELECT photo_data FROM pet_memory_photos WHERE memory_id=m.id ORDER BY position_index LIMIT 1) AS cover_data,(SELECT COUNT(*) FROM pet_memory_photos WHERE memory_id=m.id) AS photo_count FROM pet_memories m LEFT JOIN accounts a ON a.id=m.author_id WHERE m.pet_id=? ORDER BY m.happened_on DESC,m.created_at DESC,m.id DESC LIMIT 12 OFFSET ?",(r,n)->{
   var row=summary(r,n); row.put("coverData",r.getString("cover_data")); row.put("photoCount",r.getInt("photo_count")); return row;
  },petId,offset);
  int total=db.queryForObject("SELECT COUNT(*) FROM pet_memories WHERE pet_id=?",Integer.class,petId);
  return Map.of("items",items,"total",total,"hasMore",offset+items.size()<total);
 }
 @GetMapping("/{memoryId}") @Transactional
 Map<String,Object> get(Authentication auth,@PathVariable String petId,@PathVariable String memoryId) {
  checkPet(auth,petId);
  var items=db.query("SELECT m.*,a.display_name FROM pet_memories m LEFT JOIN accounts a ON a.id=m.author_id WHERE m.id=? AND m.pet_id=?",this::summary,memoryId,petId);
  if(items.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  var row=items.getFirst();
  row.put("photos",db.queryForList("SELECT photo_data FROM pet_memory_photos WHERE memory_id=? ORDER BY position_index",String.class,memoryId));
  return row;
 }
 private void savePhotos(String id, List<String> photos) {
  for(int i=0;i<photos.size();i++) {
   try {
    byte[] bytes=Base64.getDecoder().decode(photos.get(i));
    if(bytes.length==0) throw new IllegalArgumentException();
   } catch(IllegalArgumentException e) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST); }
   db.update("INSERT INTO pet_memory_photos(memory_id,position_index,photo_data) VALUES (?,?,?)",id,i,photos.get(i));
  }
 }
 @PostMapping @ResponseStatus(HttpStatus.CREATED) @Transactional
 Map<String,String> create(Authentication auth,@PathVariable String petId,@Valid @RequestBody MemoryInput input) {
  String home=checkPet(auth,petId); long before=benefits.usedBytes(home); String memory=id();
  db.update("INSERT INTO pet_memories(id,pet_id,author_id,title,story,happened_on) VALUES (?,?,?,?,?,?)",memory,petId,auth.getName(),input.title().strip(),input.story().strip(),input.happenedOn());
  savePhotos(memory,input.photos()); benefits.checkGrowth(home,before); return Map.of("id",memory);
 }
 @PatchMapping("/{memoryId}") @Transactional
 Map<String,String> update(Authentication auth,@PathVariable String petId,@PathVariable String memoryId,@Valid @RequestBody MemoryInput input) {
  String home=checkPet(auth,petId); long before=benefits.usedBytes(home);
  require(db.update("UPDATE pet_memories SET title=?,story=?,happened_on=?,updated_at=CURRENT_TIMESTAMP(6) WHERE id=? AND pet_id=?",input.title().strip(),input.story().strip(),input.happenedOn(),memoryId,petId));
  db.update("DELETE FROM pet_memory_photos WHERE memory_id=?",memoryId);
  savePhotos(memoryId,input.photos()); benefits.checkGrowth(home,before); return Map.of("id",memoryId);
 }
 @DeleteMapping("/{memoryId}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 void delete(Authentication auth,@PathVariable String petId,@PathVariable String memoryId) {
  checkPet(auth,petId);
  require(db.update("DELETE FROM pet_memories WHERE id=? AND pet_id=?",memoryId,petId));
 }
}
