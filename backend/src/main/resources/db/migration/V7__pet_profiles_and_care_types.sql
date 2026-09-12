ALTER TABLE pets
 ADD COLUMN biography VARCHAR(1000) NULL,
 ADD COLUMN birth_date DATE NULL,
 ADD COLUMN created_at TIMESTAMP(6) NULL;

-- Older profiles have no reliable creation timestamp. Keep those rows unknown;
-- only new profiles receive a server-generated creation time.
ALTER TABLE pets MODIFY COLUMN created_at TIMESTAMP(6) NULL DEFAULT CURRENT_TIMESTAMP(6);

ALTER TABLE care_tasks ADD COLUMN care_type VARCHAR(16) NOT NULL DEFAULT 'CUSTOM';
ALTER TABLE care_plans ADD COLUMN care_type VARCHAR(16) NOT NULL DEFAULT 'CUSTOM';
