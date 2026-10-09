package com.petcare.billing;

import java.sql.Timestamp;
import java.time.Instant;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RevenueCatSync {
 private final JdbcTemplate db; private final RevenueCatClient client;
 public RevenueCatSync(JdbcTemplate db,RevenueCatClient client){this.db=db;this.client=client;}
 @Transactional
 public void refresh(String appUserId){
  var rows=db.queryForList("SELECT app_user_id FROM revenuecat_customers WHERE app_user_id=? FOR UPDATE",String.class,appUserId);
  if(rows.isEmpty())return;
  // Serialize fetch + write, so delayed callbacks cannot overwrite newer state.
  Instant end=client.fetch(appUserId);
  db.update("UPDATE revenuecat_customers SET active_until=?,verified_at=UTC_TIMESTAMP(6),checked_at=UTC_TIMESTAMP(6) WHERE app_user_id=?",end==null?null:Timestamp.from(end),appUserId);
 }
}
