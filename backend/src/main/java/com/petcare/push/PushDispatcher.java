package com.petcare.push;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class PushDispatcher {
 private final JdbcTemplate db;private final FcmSender sender;private final boolean enabled;
 public PushDispatcher(JdbcTemplate db,FcmSender sender,@Value("${petcare.push.enabled:false}") boolean enabled){this.db=db;this.sender=sender;this.enabled=enabled;}
 @Scheduled(fixedDelayString="${petcare.push.interval-ms:15000}")
 public void dispatch() {
  if(!enabled)return;
  var batch=db.queryForList("SELECT household_id,revision FROM push_outbox ORDER BY updated_at LIMIT 20");
  for(var row:batch) {
   String home=(String)row.get("household_id");long revision=((Number)row.get("revision")).longValue();boolean retry=false;
   var devices=db.queryForList("SELECT d.installation_id,d.fcm_token FROM push_devices d JOIN accounts a ON a.id=d.account_id JOIN account_sessions s ON s.account_id=a.id AND s.token_hash=d.session_hash WHERE a.household_id=? AND s.expires_at>UTC_TIMESTAMP(6) AND (a.access_until IS NULL OR a.access_until>UTC_TIMESTAMP(6))",home);
   for(var device:devices) {
    var result=sender.send((String)device.get("fcm_token"),home,revision);
    if(result==FcmSender.Result.INVALID_TOKEN)db.update("DELETE FROM push_devices WHERE installation_id=? AND fcm_token=?",device.get("installation_id"),device.get("fcm_token"));
    if(result==FcmSender.Result.RETRY)retry=true;
   }
   // Compare-and-delete: a newer task commit must keep its invalidation.
   if(!retry)db.update("DELETE FROM push_outbox WHERE household_id=? AND revision=?",home,revision);
   else db.update("UPDATE push_outbox SET updated_at=UTC_TIMESTAMP(6) WHERE household_id=? AND revision=?",home,revision);
  }
 }
}
