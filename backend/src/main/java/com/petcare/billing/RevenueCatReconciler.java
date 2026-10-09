package com.petcare.billing;

import org.springframework.stereotype.Component;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;

@Component
class RevenueCatReconciler {
 private final JdbcTemplate db;private final RevenueCatSync sync;private final RevenueCatSettings settings;
 RevenueCatReconciler(JdbcTemplate db,RevenueCatSync sync,RevenueCatSettings settings){this.db=db;this.sync=sync;this.settings=settings;}
 @Scheduled(fixedDelay=60000,initialDelay=60000)
 void reconcile(){
  if(!settings.enabled)return;
  var ids=db.queryForList("SELECT app_user_id FROM revenuecat_customers WHERE checked_at IS NULL OR checked_at<DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 10 MINUTE) ORDER BY checked_at LIMIT 50",String.class);
  for(String id:ids){try{sync.refresh(id);}catch(RuntimeException e){
   db.update("UPDATE revenuecat_customers SET checked_at=UTC_TIMESTAMP(6) WHERE app_user_id=?",id);
   org.slf4j.LoggerFactory.getLogger(getClass()).warn("RevenueCat reconciliation failed; will retry");
  }}
 }
}
