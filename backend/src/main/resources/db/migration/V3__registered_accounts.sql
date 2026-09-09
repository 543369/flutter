ALTER TABLE accounts
 ADD COLUMN email VARCHAR(254) NULL,
 ADD COLUMN password_hash VARCHAR(100) NULL,
 ADD UNIQUE KEY unique_account_email (email);
CREATE TABLE account_sessions (
 token_hash CHAR(64) PRIMARY KEY,
 account_id CHAR(36) NOT NULL,
 expires_at TIMESTAMP(6) NOT NULL,
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE,
 INDEX idx_session_expiry (expires_at)
);
INSERT INTO account_sessions(token_hash,account_id,expires_at)
 SELECT token_hash,id,DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 30 DAY) FROM accounts;
