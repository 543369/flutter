CREATE TABLE overdue_batches (
 id CHAR(36) PRIMARY KEY,
 account_id CHAR(36) NOT NULL,
 household_id CHAR(36) NOT NULL,
 pet_id CHAR(36) NOT NULL,
 state VARCHAR(12) NOT NULL DEFAULT 'PREVIEW',
 before_at TIMESTAMP(6) NOT NULL,
 created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 expires_at TIMESTAMP(6) NOT NULL,
 INDEX overdue_batch_owner(account_id,pet_id,created_at),
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE TABLE overdue_batch_items (
 batch_id CHAR(36) NOT NULL,
 task_id CHAR(36) NOT NULL,
 revision BIGINT NOT NULL,
 status VARCHAR(12) NOT NULL DEFAULT 'PENDING',
 PRIMARY KEY(batch_id,task_id),
 INDEX overdue_batch_pending(batch_id,status,task_id),
 FOREIGN KEY(batch_id) REFERENCES overdue_batches(id) ON DELETE CASCADE
);
CREATE INDEX overdue_pet_pending ON care_tasks(pet_id,completed,cancelled,skipped,due_at,id);
