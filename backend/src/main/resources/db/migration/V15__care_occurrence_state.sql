ALTER TABLE care_tasks
 ADD COLUMN occurrence_at TIMESTAMP(6) NULL,
 ADD COLUMN skipped BOOLEAN NOT NULL DEFAULT FALSE,
 ADD COLUMN health_record_id CHAR(36) NULL,
 ADD CONSTRAINT fk_task_health FOREIGN KEY (health_record_id) REFERENCES health_records(id) ON DELETE SET NULL;
UPDATE care_tasks SET occurrence_at=due_at WHERE plan_id IS NOT NULL;
ALTER TABLE care_tasks DROP INDEX unique_plan_occurrence,
 ADD UNIQUE KEY unique_plan_occurrence (plan_id, occurrence_at),
 ADD INDEX idx_task_pet_due (pet_id, due_at, id);
ALTER TABLE care_events ADD INDEX idx_event_task_time (task_id, happened_at, id);
