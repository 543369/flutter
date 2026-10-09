CREATE TABLE registration_verifications (
 email VARCHAR(254) PRIMARY KEY,
 token_hash CHAR(64) NULL,
 sent_at TIMESTAMP(6) NULL,
 expires_at TIMESTAMP(6) NULL
);
