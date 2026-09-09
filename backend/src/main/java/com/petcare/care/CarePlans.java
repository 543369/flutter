package com.petcare.care;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class CarePlans {
    private final JdbcTemplate db;
    CarePlans(JdbcTemplate db) { this.db = db; }

    // Caller holds the household lock inside a transaction. Keep history, and
    // replenish a rolling window when a member syncs without making duplicates.
    public void materialize(String household) {
        Instant now = Instant.now();
        Instant from = now.minus(30, ChronoUnit.DAYS);
        Instant through = now.plus(30, ChronoUnit.DAYS);
        Instant max = Instant.parse("2037-12-31T23:59:59Z");
        if (through.isAfter(max)) through = max;
        var plans = db.queryForList("SELECT c.* FROM care_plans c JOIN pets p ON p.id=c.pet_id WHERE p.household_id=? AND c.active=TRUE", household);
        for (var plan : plans) {
            var start = ((Timestamp) plan.get("starts_at")).toInstant();
            for (Instant due : Recurrence.between(start, (String) plan.get("zone_id"), (String) plan.get("frequency"), from, through)) {
                db.update("INSERT INTO care_tasks(id,pet_id,title,due_at,plan_id) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE plan_id=plan_id",
                    UUID.randomUUID().toString(), plan.get("pet_id"), plan.get("title"), Timestamp.from(due), plan.get("id"));
            }
        }
    }
}
