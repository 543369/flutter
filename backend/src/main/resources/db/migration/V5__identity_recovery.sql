ALTER TABLE accounts ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE, ADD COLUMN apple_subject VARCHAR(255) NULL, ADD UNIQUE KEY unique_apple_subject(apple_subject);
CREATE TABLE email_actions (
 account_id CHAR(36) NOT NULL, purpose VARCHAR(12) NOT NULL, token_hash CHAR(64) NOT NULL,
 expires_at TIMESTAMP(6) NOT NULL, sent_at TIMESTAMP(6) NOT NULL,
 PRIMARY KEY(account_id,purpose), UNIQUE KEY unique_action_token(token_hash),
 FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE TABLE apple_challenges (token_hash CHAR(64) PRIMARY KEY, expires_at TIMESTAMP(6) NOT NULL);
