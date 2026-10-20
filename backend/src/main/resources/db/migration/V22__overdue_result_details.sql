ALTER TABLE overdue_batch_items
 ADD COLUMN title VARCHAR(120) NULL,
 ADD COLUMN due_at TIMESTAMP(6) NULL,
 ADD COLUMN reason VARCHAR(40) NULL,
 ADD COLUMN attempts INT NOT NULL DEFAULT 0;
UPDATE overdue_batch_items i JOIN care_tasks t ON t.id=i.task_id
 SET i.title=t.title,i.due_at=t.due_at;
UPDATE overdue_batch_items SET reason='INTEGRITY_ERROR' WHERE status='FAILED';
UPDATE overdue_batch_items SET reason='STATE_CHANGED' WHERE status='CHANGED';
CREATE INDEX overdue_batch_history ON overdue_batches(account_id,household_id,pet_id,created_at,id);
