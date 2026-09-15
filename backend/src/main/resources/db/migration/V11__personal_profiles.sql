ALTER TABLE accounts
 ADD COLUMN birth_date DATE NULL,
 ADD COLUMN phone VARCHAR(25) NULL,
 ADD COLUMN created_at TIMESTAMP(6) NULL;

-- Existing accounts without a recorded creation time remain unknown.
ALTER TABLE accounts MODIFY COLUMN created_at TIMESTAMP(6) NULL DEFAULT CURRENT_TIMESTAMP(6);
