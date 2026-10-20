ALTER TABLE overdue_batches ADD COLUMN finished_at TIMESTAMP(6) NULL;
UPDATE overdue_batches SET finished_at=created_at WHERE state='COMPLETE';
