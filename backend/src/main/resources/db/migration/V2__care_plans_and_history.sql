ALTER TABLE accounts ADD COLUMN display_name VARCHAR(40) NOT NULL DEFAULT '家人';
UPDATE accounts SET display_name=CONCAT('家人-',LEFT(id,4));
CREATE TABLE care_plans (
 id CHAR(36) PRIMARY KEY,
 pet_id CHAR(36) NOT NULL,
 title VARCHAR(120) NOT NULL,
 frequency VARCHAR(10) NOT NULL,
 zone_id VARCHAR(80) NOT NULL,
 starts_at TIMESTAMP(6) NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE,
 FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
);
ALTER TABLE care_tasks
 ADD COLUMN cancelled BOOLEAN NOT NULL DEFAULT FALSE,
 ADD COLUMN plan_id CHAR(36) NULL,
 ADD CONSTRAINT fk_task_plan FOREIGN KEY (plan_id) REFERENCES care_plans(id) ON DELETE CASCADE,
 ADD UNIQUE KEY unique_plan_occurrence (plan_id, due_at);
CREATE TABLE care_events (
 id CHAR(36) PRIMARY KEY,
 task_id CHAR(36) NOT NULL,
 actor_id CHAR(36) NULL,
 action VARCHAR(16) NOT NULL,
 happened_at TIMESTAMP(6) NOT NULL,
 FOREIGN KEY (task_id) REFERENCES care_tasks(id) ON DELETE CASCADE,
 FOREIGN KEY (actor_id) REFERENCES accounts(id) ON DELETE SET NULL,
 INDEX idx_events_time (happened_at)
);
