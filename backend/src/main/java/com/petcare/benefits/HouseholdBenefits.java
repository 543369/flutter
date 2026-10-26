package com.petcare.benefits;

import java.time.Instant;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class HouseholdBenefits {
 private final JdbcTemplate db;
 private final long freeBytes, previewBytes;
 private final boolean preview;
 @org.springframework.beans.factory.annotation.Autowired
 private com.petcare.billing.RevenueCatSettings billing;
 public HouseholdBenefits(JdbcTemplate db,
   @Value("${petcare.benefits.free-bytes:104857600}") long freeBytes,
   @Value("${petcare.benefits.preview-bytes:1073741824}") long previewBytes,
   @Value("${petcare.benefits.preview-enabled:true}") boolean preview) {
  if (freeBytes <= 0 || previewBytes < freeBytes) throw new IllegalArgumentException("Invalid storage quotas");
  this.db=db; this.freeBytes=freeBytes; this.previewBytes=previewBytes; this.preview=preview;
 }
 public record Access(String tier, long limitBytes, Instant expiresAt, boolean extended) {}
 public Access access(String home) {
  if(billing!=null && billing.enabled) {
   var subscriptions=db.query("SELECT MAX(active_until) FROM revenuecat_customers WHERE household_id=? AND active_until>UTC_TIMESTAMP(6) AND verified_at>DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 HOUR)",
    (r,n)->r.getTimestamp(1),home);
   if(!subscriptions.isEmpty() && subscriptions.getFirst()!=null)
    return new Access("FAMILY",Math.max(freeBytes,billing.storageBytes),subscriptions.getFirst().toInstant(),true);
  }
  var grants=db.query("SELECT storage_limit_bytes,expires_at FROM household_benefits WHERE household_id=? AND (expires_at IS NULL OR expires_at>CURRENT_TIMESTAMP(6))",
   (r,n)->new Access("FAMILY",Math.max(freeBytes,r.getLong(1)),r.getTimestamp(2)==null?null:r.getTimestamp(2).toInstant(),true),home);
  return grants.isEmpty()?new Access(preview?"PREVIEW":"FREE",preview?previewBytes:freeBytes,null,preview):grants.getFirst();
 }
 public Map<String,Object> memoryQuota(String home) {
  boolean unlimited=access(home).extended();
  long created=db.queryForObject("SELECT memory_created_count FROM households WHERE id=?",Long.class,home);
  var quota=new java.util.LinkedHashMap<String,Object>();
  quota.put("memoryCreatedCount",created);
  quota.put("memoryLimit",unlimited?null:10);
  quota.put("memoryRemaining",unlimited?null:Math.max(0,10-created));
  quota.put("canCreateMemory",unlimited || created<10);
  return quota;
 }
 // Call inside the write transaction. Lock the shared household counter so that
 // concurrent creations across members and profiles cannot exceed the limit.
 public void reserveMemory(String home) {
  long created=db.queryForObject("SELECT memory_created_count FROM households WHERE id=? FOR UPDATE",Long.class,home);
  if(!access(home).extended() && created>=10)
   throw new ResponseStatusException(HttpStatus.FORBIDDEN,"MEMORY_LIMIT_REACHED");
  db.update("UPDATE households SET memory_created_count=memory_created_count+1 WHERE id=?",home);
 }
 public long usedBytes(String home) {
  // Count decoded image bytes once; pets.photo_data mirrors the first gallery image.
  return db.queryForObject("SELECT COALESCE(SUM(bytes),0) FROM (SELECT OCTET_LENGTH(FROM_BASE64(f.photo_data)) bytes FROM pet_photos f JOIN pets p ON p.id=f.pet_id WHERE p.household_id=? UNION ALL SELECT OCTET_LENGTH(FROM_BASE64(f.photo_data)) bytes FROM pet_memory_photos f JOIN pet_memories m ON m.id=f.memory_id JOIN pets p ON p.id=m.pet_id WHERE p.household_id=? UNION ALL SELECT OCTET_LENGTH(FROM_BASE64(f.photo_data)) bytes FROM health_attachments f JOIN health_records h ON h.id=f.record_id JOIN pets p ON p.id=h.pet_id WHERE p.household_id=?) images",Long.class,home,home,home);
 }
 public long photoCount(String home) {
  return db.queryForObject("SELECT (SELECT COUNT(*) FROM pet_photos f JOIN pets p ON p.id=f.pet_id WHERE p.household_id=?)+(SELECT COUNT(*) FROM pet_memory_photos f JOIN pet_memories m ON m.id=f.memory_id JOIN pets p ON p.id=m.pet_id WHERE p.household_id=?)+(SELECT COUNT(*) FROM health_attachments f JOIN health_records h ON h.id=f.record_id JOIN pets p ON p.id=h.pet_id WHERE p.household_id=?)",Long.class,home,home,home);
 }
 public void checkGrowth(String home,long before) {
  long after=usedBytes(home);
  // Over-quota families can still remove photos and make size-neutral edits.
  if (after>before && after>access(home).limitBytes())
   throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"STORAGE_LIMIT_EXCEEDED");
 }
 public void requireExtended(String home) {
  if(!access(home).extended()) throw new ResponseStatusException(HttpStatus.FORBIDDEN,"BENEFIT_UNAVAILABLE");
 }
 public Map<String,Object> status(String home) {
  Access access=access(home);
  var result=new java.util.LinkedHashMap<String,Object>();
  result.put("tier",access.tier()); result.put("limitBytes",access.limitBytes());
  result.put("baseLimitBytes",freeBytes); result.put("usedBytes",usedBytes(home));
  result.put("photoCount",photoCount(home)); result.put("expiresAt",access.expiresAt());
  result.put("canExport",access.extended()); result.put("canReport",access.extended());
  result.put("canHealthTrends",access.extended()); result.put("canBatchOrganize",access.extended());
  result.put("canAdvancedRoles",access.extended()); result.put("healthAttachmentLimit",access.extended()?12:2);
  result.putAll(memoryQuota(home));
  result.put("billingEnabled",billing!=null && billing.enabled);
  return result;
 }
}
