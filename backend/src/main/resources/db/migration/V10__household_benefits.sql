CREATE TABLE household_benefits (
 household_id CHAR(36) PRIMARY KEY,
 storage_limit_bytes BIGINT NOT NULL,
 expires_at TIMESTAMP(6) NULL,
 FOREIGN KEY (household_id) REFERENCES households(id) ON DELETE CASCADE,
 CHECK (storage_limit_bytes > 0)
);
