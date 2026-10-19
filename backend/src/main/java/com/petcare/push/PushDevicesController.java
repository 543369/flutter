package com.petcare.push;
import com.petcare.shared.ApiSupport;
import com.petcare.auth.Tokens;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController @RequestMapping("/api/push")
public class PushDevicesController extends ApiSupport {
 private final boolean enabled;
 public PushDevicesController(JdbcTemplate db,@Value("${petcare.push.enabled:false}") boolean enabled){super(db);this.enabled=enabled;}
 public record Device(@Pattern(regexp="[a-fA-F0-9-]{36}") @NotBlank String installationId,@NotBlank @Size(max=512) String token) {}
 @GetMapping("/status") public Map<String,Boolean> status(){return Map.of("enabled",enabled);}
 @PutMapping("/devices") @Transactional
 public void register(Authentication auth,@RequestHeader("Authorization") String bearer,@Valid @RequestBody Device input) {
  permission(auth,"READ");
  // A rotating installation token may be rebound after signing in as another
  // account, but recipient selection is always joined to the exact live session.
  db.update("DELETE FROM push_devices WHERE installation_id=? OR fcm_token=?",input.installationId(),input.token());
  db.update("INSERT INTO push_devices(installation_id,account_id,session_hash,fcm_token) VALUES(?,?,?,?)",input.installationId(),auth.getName(),Tokens.hash(bearer.substring(7)),input.token());
 }
 @DeleteMapping("/devices/{installation}") @Transactional
 public void remove(Authentication auth,@PathVariable String installation){
  db.update("DELETE FROM push_devices WHERE installation_id=? AND account_id=?",installation,auth.getName());
 }
}
