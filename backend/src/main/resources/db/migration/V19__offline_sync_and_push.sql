ALTER TABLE care_tasks ADD COLUMN revision BIGINT NOT NULL DEFAULT 0;
CREATE TABLE care_sync_receipts (
 account_id VARCHAR(36) NOT NULL,
 operation_id VARCHAR(36) NOT NULL,
 household_id VARCHAR(36) NOT NULL,
 task_id VARCHAR(36) NOT NULL,
 request_hash CHAR(64) NOT NULL,
 revision BIGINT NOT NULL,
 created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 PRIMARY KEY(account_id,operation_id),
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE TABLE push_devices (
 installation_id VARCHAR(36) PRIMARY KEY,
 account_id VARCHAR(36) NOT NULL,
 session_hash CHAR(64) NOT NULL,
 fcm_token VARCHAR(512) NOT NULL,
 updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 UNIQUE KEY uq_push_token(fcm_token),
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE TABLE push_outbox (
 household_id VARCHAR(36) PRIMARY KEY,
 revision BIGINT NOT NULL DEFAULT 1,
 updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
);
