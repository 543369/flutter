CREATE TABLE email_change_requests (
 account_id CHAR(36) PRIMARY KEY,
 new_email VARCHAR(254) NOT NULL,
 old_email VARCHAR(254) NOT NULL,
 credential_hash CHAR(64) NOT NULL,
 session_hash CHAR(64) NOT NULL,
 token_hash CHAR(64) NOT NULL UNIQUE,
 expires_at TIMESTAMP(6) NOT NULL,
 sent_at TIMESTAMP(6) NOT NULL,
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE TABLE apple_link_challenges (
 token_hash CHAR(64) PRIMARY KEY,
 account_id CHAR(36) NOT NULL,
 session_hash CHAR(64) NOT NULL,
 credential_hash CHAR(64) NOT NULL,
 expires_at TIMESTAMP(6) NOT NULL,
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
