-- Stable pagination order must not move when a task is completed or rescheduled.
ALTER TABLE care_tasks ADD COLUMN created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6);
CREATE INDEX idx_care_created ON care_tasks (created_at, id);
