package com.petcare.care;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.slf4j.LoggerFactory;

@Component
class PlanScheduler {
    private final JdbcTemplate db;
    private final CarePlans plans;
    private final TransactionTemplate transaction;
    PlanScheduler(JdbcTemplate db, CarePlans plans, PlatformTransactionManager manager) {
        this.db = db;
        this.plans = plans;
        this.transaction = new TransactionTemplate(manager);
    }
    @Scheduled(fixedDelay = 3600000, initialDelay = 10000)
    void replenish() {
        var homes = db.queryForList("SELECT DISTINCT p.household_id FROM care_plans c JOIN pets p ON p.id=c.pet_id WHERE c.active=TRUE", String.class);
        for (String home : homes) {
            try {
                transaction.executeWithoutResult(status -> {
                    var exists = db.queryForList("SELECT id FROM households WHERE id=? FOR UPDATE",String.class,home);
                    if (!exists.isEmpty()) plans.materialize(home);
                });
            } catch (RuntimeException e) {
                LoggerFactory.getLogger(PlanScheduler.class).warn("Could not replenish household plans; next sync or scheduled run will retry", e);
            }
        }
    }
}
